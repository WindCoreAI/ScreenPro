import Foundation
import CoreGraphics
import CoreMedia

// MARK: - ReviewSessionService (008-review-recording)
//
// Orchestrates one review session attached to one recording: manual flags,
// voice notes, screenshot pairing, and the merge rule that keeps a spoken
// observation from duplicating a manual flag (FR-007). Single active
// session, mirroring RecordingService's single-recording invariant.
//
// Session artifacts live in a temp directory until ReviewReportGenerator
// finalizes the bundle, so cancel leaves no trace (FR-016) and failures
// never leave half a bundle in the user's save folder.

@MainActor
final class ReviewSessionService: ObservableObject {
    // MARK: - Published State

    @Published private(set) var phase: ReviewSessionPhase = .inactive
    @Published private(set) var issues: [ReviewIssue] = []
    @Published private(set) var voiceNotesActive: Bool = false

    // MARK: - Configuration

    /// A spoken observation whose span falls within this window of a manual
    /// flag is merged into that flag instead of creating a duplicate issue.
    static let mergeWindow: TimeInterval = 2.0

    // MARK: - Dependencies

    private let permissionManager: PermissionManager
    private let microphoneAudioHub: MicrophoneAudioHub
    private let makeTranscription: @MainActor () -> TranscriptionProviding

    /// Notified once (not repeatedly) when voice notes can't run (FR-014).
    var onVoiceNotesUnavailable: ((String) -> Void)?

    // MARK: - Session State

    let clock = RecordedTimeClock()
    private var frameProvider: ReviewFrameProviding?
    private var ownedFrameBuffer: ReviewFrameBuffer?
    private var transcription: TranscriptionProviding?
    private var transcript: [TranscriptSegment] = []
    private var tempDirectory: URL?
    private var micConsumerToken: UUID?
    private var pendingScreenshotWrites: [UUID: Task<Void, Never>] = [:]

    init(
        permissionManager: PermissionManager,
        microphoneAudioHub: MicrophoneAudioHub,
        makeTranscription: @escaping @MainActor () -> TranscriptionProviding = { SpeechTranscriptionService() }
    ) {
        self.permissionManager = permissionManager
        self.microphoneAudioHub = microphoneAudioHub
        self.makeTranscription = makeTranscription
    }

    // MARK: - Lifecycle

    /// Starts a session. Call immediately after RecordingService.startRecording
    /// succeeds. Pass an injected frame provider only in tests; production
    /// uses the internally owned ReviewFrameBuffer exposed via `frameTap()`.
    func start(
        voiceNotesEnabled: Bool,
        transcriptionLocale: String,
        frameProvider: ReviewFrameProviding? = nil
    ) async {
        guard phase == .inactive else { return }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReviewSession-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempDirectory = tempDir

        issues = []
        transcript = []
        pendingScreenshotWrites = [:]

        clock.start()

        if let frameProvider {
            self.frameProvider = frameProvider
            self.ownedFrameBuffer = nil
        } else {
            let buffer = ReviewFrameBuffer(clock: clock)
            self.ownedFrameBuffer = buffer
            self.frameProvider = buffer
        }

        phase = .active

        if voiceNotesEnabled {
            await startVoiceNotes(locale: transcriptionLocale)
        } else {
            voiceNotesActive = false
        }
    }

    /// The closure RecordingService.videoFrameTap should be set to, feeding
    /// the internally owned frame ring. Nil when a provider was injected.
    func frameTap() -> ((CMSampleBuffer) -> Void)? {
        guard let buffer = ownedFrameBuffer else { return nil }
        return { [weak buffer] sampleBuffer in
            buffer?.ingest(sampleBuffer)
        }
    }

    /// Suspends flagging and transcription while the recording is paused (FR-017).
    func suspend() {
        guard phase == .active else { return }
        phase = .suspended
        clock.pause()
        transcription?.suspend()
    }

    func resume() {
        guard phase == .suspended else { return }
        clock.resume()
        transcription?.resume()
        phase = .active
    }

    /// Ends the session. Screenshot writes are awaited so a flag pressed just
    /// before stop still lands in the bundle (edge case in spec.md).
    func finish() async -> ReviewSessionOutput {
        guard phase == .active || phase == .suspended else {
            return ReviewSessionOutput(issues: [], transcript: [], tempDirectory: tempDirectory ?? FileManager.default.temporaryDirectory)
        }

        phase = .finalizing
        stopVoiceNotes()

        for task in pendingScreenshotWrites.values {
            await task.value
        }
        pendingScreenshotWrites = [:]

        clock.stop()
        ownedFrameBuffer?.clear()
        phase = .inactive
        return currentOutput()
    }

    /// Snapshot of the session's issues and transcript. Called again after
    /// the summary step, which may have edited or deleted issues (FR-012).
    func currentOutput() -> ReviewSessionOutput {
        ReviewSessionOutput(
            issues: issues.sorted { $0.timestamp < $1.timestamp },
            transcript: transcript.sorted { $0.start < $1.start },
            tempDirectory: tempDirectory ?? FileManager.default.temporaryDirectory
        )
    }

    /// Discards the session and all its artifacts (FR-016).
    func cancel() {
        guard phase != .inactive else { return }

        stopVoiceNotes()
        for task in pendingScreenshotWrites.values {
            task.cancel()
        }
        pendingScreenshotWrites = [:]

        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
        issues = []
        transcript = []
        clock.stop()
        ownedFrameBuffer?.clear()
        frameProvider = nil
        ownedFrameBuffer = nil
        voiceNotesActive = false
        phase = .inactive
    }

    /// Deletes the temp directory after the bundle was generated.
    func cleanupAfterExport() {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
        frameProvider = nil
        ownedFrameBuffer = nil
        issues = []
        transcript = []
        voiceNotesActive = false
    }

    // MARK: - Flags (US1)

    /// Captures a manual flag at the current recorded time (FR-002, FR-003).
    /// Returns nil while not `.active` or before the first frame arrived.
    @discardableResult
    func flagCurrentMoment() -> ReviewIssue? {
        guard phase == .active,
              let frameProvider,
              let tempDirectory,
              let image = frameProvider.latestFrame() else { return nil }

        let timestamp = clock.now

        // Absorb a just-closed utterance overlapping this moment so the
        // spoken context rides on the flag instead of duplicating (FR-007).
        var absorbedTranscript: String?
        if let voiceIndex = issues.lastIndex(where: { issue in
            issue.source == .voice && abs(issue.timestamp - timestamp) <= Self.mergeWindow
        }) {
            absorbedTranscript = issues[voiceIndex].transcript
            issues.remove(at: voiceIndex)
        }

        let issue = ReviewIssue(
            timestamp: timestamp,
            source: .manual,
            transcript: absorbedTranscript,
            screenshotFilename: writeScreenshot(image)
        )
        issues.append(issue)
        return issue
    }

    func setNote(_ text: String, for issueID: UUID) {
        guard let index = issues.firstIndex(where: { $0.id == issueID }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        issues[index].note = trimmed.isEmpty ? nil : trimmed
    }

    func setTranscript(_ text: String, for issueID: UUID) {
        guard let index = issues.firstIndex(where: { $0.id == issueID }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        issues[index].transcript = trimmed.isEmpty ? nil : trimmed
    }

    func deleteIssue(_ issueID: UUID) {
        issues.removeAll { $0.id == issueID }
    }

    /// Temp-directory URL of an issue's screenshot (summary thumbnails).
    func screenshotURL(for issue: ReviewIssue) -> URL? {
        tempDirectory?.appendingPathComponent(issue.screenshotFilename)
    }

    // MARK: - Voice Notes (US3)

    private func startVoiceNotes(locale: String) async {
        // Speech recognition is a separate grant from microphone (FR-014),
        // requested lazily here — never at launch (Constitution VII).
        var speechStatus = permissionManager.checkSpeechRecognitionPermission()
        if speechStatus == .notDetermined {
            speechStatus = await permissionManager.requestSpeechRecognitionPermission() ? .authorized : .denied
        }
        guard speechStatus == .authorized else {
            voiceNotesActive = false
            onVoiceNotesUnavailable?("Speech recognition permission was not granted. Flag moments with the hotkey instead.")
            return
        }

        var micStatus = permissionManager.checkMicrophonePermission()
        if micStatus == .notDetermined {
            micStatus = await permissionManager.requestMicrophonePermission() ? .authorized : .denied
        }
        guard micStatus == .authorized else {
            voiceNotesActive = false
            onVoiceNotesUnavailable?("Microphone permission was not granted. Flag moments with the hotkey instead.")
            return
        }

        let transcription = makeTranscription()
        do {
            try transcription.start(locale: locale, clock: clock) { [weak self] utterance in
                self?.ingestUtterance(utterance)
            }
            // Narration is transcribed even when "record microphone" is off:
            // the hub feeds the recognizer without touching the video's
            // audio tracks (research.md R4).
            micConsumerToken = try microphoneAudioHub.addConsumer { buffer, _ in
                transcription.append(buffer)
            }
            self.transcription = transcription
            voiceNotesActive = true
        } catch {
            transcription.stop()
            voiceNotesActive = false
            onVoiceNotesUnavailable?("On-device transcription is unavailable for the selected language. Flag moments with the hotkey instead.")
        }
    }

    private func stopVoiceNotes() {
        if let token = micConsumerToken {
            microphoneAudioHub.removeConsumer(token)
        }
        micConsumerToken = nil
        transcription?.stop()
        transcription = nil
        voiceNotesActive = false
    }

    /// Internal (not private) so tests can drive the voice-note path without
    /// a live recognizer (research.md R10).
    func ingestUtterance(_ utterance: Utterance) {
        guard phase == .active || phase == .finalizing else { return }

        transcript.append(TranscriptSegment(start: utterance.start, end: utterance.end, text: utterance.text))

        // Merge into an overlapping manual flag instead of duplicating (FR-007).
        if let manualIndex = issues.lastIndex(where: { issue in
            issue.source == .manual
                && issue.transcript == nil
                && issue.timestamp >= utterance.start - Self.mergeWindow
                && issue.timestamp <= utterance.end + Self.mergeWindow
        }) {
            issues[manualIndex].transcript = utterance.text
            return
        }

        guard let frameProvider, tempDirectory != nil,
              let image = frameProvider.frame(nearest: utterance.start) else { return }

        let issue = ReviewIssue(
            timestamp: utterance.start,
            source: .voice,
            transcript: utterance.text,
            screenshotFilename: writeScreenshot(image)
        )
        issues.append(issue)
    }

    // MARK: - Screenshots

    /// Schedules a background PNG write and returns the temp filename.
    private func writeScreenshot(_ image: CGImage) -> String {
        let filename = "\(UUID().uuidString).png"
        guard let tempDirectory else { return filename }
        let url = tempDirectory.appendingPathComponent(filename)
        let taskID = UUID()

        let task = Task.detached(priority: .utility) {
            do {
                try ReviewFrameBuffer.writePNG(image, to: url)
            } catch {
                print("[ReviewSessionService] Screenshot write failed: \(error)")
            }
        }
        pendingScreenshotWrites[taskID] = task

        Task { [weak self] in
            await task.value
            self?.pendingScreenshotWrites[taskID] = nil
        }
        return filename
    }
}
