import Foundation
import AVFoundation
import Speech

// MARK: - Utterance (008-review-recording)

/// One segmented spoken observation.
struct Utterance: Sendable, Equatable {
    /// Recorded time (pause-adjusted) at which the utterance began.
    let start: TimeInterval
    /// Recorded time of the last recognized word.
    let end: TimeInterval
    /// Best transcription, trimmed; never empty.
    let text: String
}

// MARK: - UtteranceSegmenter (pure, unit-testable — research.md R2, R10)

/// Derives utterance boundaries from partial-result events and a clock.
/// Holds no Speech framework types so tests can inject events directly.
///
/// Because the recognition request is restarted after each closed utterance,
/// the cumulative partial text of the current request IS the utterance text.
struct UtteranceSegmenter {
    /// Silence gap that closes an utterance.
    let silenceThreshold: TimeInterval
    /// Discard utterances shorter than this many characters (recognizer noise).
    let minimumLength: Int
    /// Recognition lags real speech; utterance start is pulled back by this
    /// much (clamped ≥ 0) so the paired screenshot shows what was on screen
    /// when the reviewer began speaking.
    let startLatencyCompensation: TimeInterval

    private(set) var currentText: String = ""
    private var utteranceStart: TimeInterval?
    private var lastPartialAt: TimeInterval?

    init(
        silenceThreshold: TimeInterval = 1.2,
        minimumLength: Int = 2,
        startLatencyCompensation: TimeInterval = 0.5
    ) {
        self.silenceThreshold = silenceThreshold
        self.minimumLength = minimumLength
        self.startLatencyCompensation = startLatencyCompensation
    }

    /// Report a partial transcription at a recorded time.
    mutating func partial(text: String, at time: TimeInterval) {
        if utteranceStart == nil {
            utteranceStart = max(0, time - startLatencyCompensation)
        }
        currentText = text
        lastPartialAt = time
    }

    /// Periodic tick; returns a closed utterance when silence has elapsed.
    /// The caller must restart its recognition request after a non-nil return.
    mutating func tick(now: TimeInterval) -> Utterance? {
        guard let last = lastPartialAt, now - last > silenceThreshold else { return nil }
        return close()
    }

    /// Flush at stop; returns the open utterance if non-empty.
    mutating func flush() -> Utterance? {
        guard lastPartialAt != nil else { return nil }
        return close()
    }

    private mutating func close() -> Utterance? {
        defer {
            currentText = ""
            utteranceStart = nil
            lastPartialAt = nil
        }
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumLength,
              let start = utteranceStart,
              let end = lastPartialAt else { return nil }
        return Utterance(start: start, end: end, text: trimmed)
    }
}

// MARK: - Transcription providing seam (tests inject stubs)

@MainActor
protocol TranscriptionProviding: AnyObject {
    var isAvailable: Bool { get }
    func start(locale: String,
               clock: RecordedTimeClock,
               onUtterance: @escaping @MainActor (Utterance) -> Void) throws
    nonisolated func append(_ buffer: AVAudioPCMBuffer)
    func suspend()
    func resume()
    func stop()
}

// MARK: - SpeechTranscriptionService (008-review-recording)
//
// Wraps SFSpeechRecognizer with STRICT on-device recognition (FR-005,
// FR-018): if the locale's on-device model is unavailable, start() throws
// and the session proceeds manual-only — there is never a server fallback.

enum SpeechTranscriptionError: Error {
    case localeNotSupported(String)
    case onDeviceRecognitionUnavailable(String)
    case recognizerUnavailable
}

@MainActor
final class SpeechTranscriptionService: TranscriptionProviding {
    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?
    private var segmenter = UtteranceSegmenter()
    private var tickTimer: Timer?
    private var clock: RecordedTimeClock?
    private var onUtterance: (@MainActor (Utterance) -> Void)?
    private var isSuspended = false
    private var isRunning = false

    /// Active request, written on the main actor, read on the audio tap
    /// thread; SFSpeechAudioBufferRecognitionRequest.append is thread-safe.
    private let requestLock = NSLock()
    private nonisolated(unsafe) var activeRequest: SFSpeechAudioBufferRecognitionRequest?

    var isAvailable: Bool {
        recognizer?.isAvailable ?? false
    }

    func start(locale localeIdentifier: String,
               clock: RecordedTimeClock,
               onUtterance: @escaping @MainActor (Utterance) -> Void) throws {
        let locale = localeIdentifier.isEmpty ? Locale.current : Locale(identifier: localeIdentifier)

        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw SpeechTranscriptionError.localeNotSupported(locale.identifier)
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw SpeechTranscriptionError.onDeviceRecognitionUnavailable(locale.identifier)
        }
        guard recognizer.isAvailable else {
            throw SpeechTranscriptionError.recognizerUnavailable
        }

        self.recognizer = recognizer
        self.clock = clock
        self.onUtterance = onUtterance
        self.segmenter = UtteranceSegmenter()
        self.isSuspended = false
        self.isRunning = true

        beginRecognitionTask()
        startTickTimer()
    }

    nonisolated func append(_ buffer: AVAudioPCMBuffer) {
        requestLock.lock()
        let request = activeRequest
        requestLock.unlock()
        request?.append(buffer)
    }

    func suspend() {
        // Stop feeding the segmenter and drop the live request so paused-time
        // speech can't produce notes (FR-017). A fresh request starts on resume.
        guard isRunning, !isSuspended else { return }
        isSuspended = true
        if let utterance = segmenter.flush() {
            onUtterance?(utterance)
        }
        endRecognitionTask()
    }

    func resume() {
        guard isRunning, isSuspended else { return }
        isSuspended = false
        beginRecognitionTask()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        tickTimer?.invalidate()
        tickTimer = nil
        if let utterance = segmenter.flush() {
            onUtterance?(utterance)
        }
        endRecognitionTask()
        recognizer = nil
        clock = nil
        onUtterance = nil
    }

    // MARK: - Recognition task lifecycle (restart per utterance — R2)

    private func beginRecognitionTask() {
        guard let recognizer, isRunning, !isSuspended else { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true // never server — FR-018
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }

        requestLock.lock()
        activeRequest = request
        requestLock.unlock()

        // Captured locally: the recognition callback runs off the main actor
        // and may only touch Sendable state.
        let clock = self.clock
        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let result else { return }
            // Stamp arrival time off the clock (Sendable) before hopping.
            let arrivalTime = clock?.now ?? 0
            let text = result.bestTranscription.formattedString
            Task { @MainActor [weak self] in
                guard let self, self.isRunning, !self.isSuspended else { return }
                self.segmenter.partial(text: text, at: arrivalTime)
            }
        }
    }

    private func endRecognitionTask() {
        requestLock.lock()
        let request = activeRequest
        activeRequest = nil
        requestLock.unlock()

        request?.endAudio()
        task?.cancel()
        task = nil
    }

    private func startTickTimer() {
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleTick()
            }
        }
    }

    private func handleTick() {
        guard isRunning, !isSuspended, let clock else { return }
        if let utterance = segmenter.tick(now: clock.now) {
            onUtterance?(utterance)
            // Restart so the next utterance gets a clean cumulative transcript
            // and individual tasks stay short (R2).
            endRecognitionTask()
            beginRecognitionTask()
        }
    }
}
