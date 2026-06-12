import Foundation
import CoreMedia

// MARK: - Review Session Service Contract (008-review-recording)
//
// Orchestrates one review session attached to one recording. Single active
// session, mirroring RecordingService's single-recording invariant.

@MainActor
protocol ReviewSessionServiceProtocol: AnyObject, ObservableObject {
    /// Current lifecycle phase. Flags are accepted only while `.active`.
    var phase: ReviewSessionPhase { get }

    /// Issues captured so far (chronological). Published for controls UI badge
    /// and the summary window.
    var issues: [ReviewIssue] { get }

    /// Whether voice notes are running for this session (false when speech
    /// permission was denied or the on-device model is unavailable — FR-014).
    var voiceNotesActive: Bool { get }

    /// Starts a session. Called by AppCoordinator immediately after
    /// RecordingService.startRecording succeeds. Requests speech permission
    /// lazily when `voiceNotesEnabled` and not yet determined.
    /// - Parameters:
    ///   - recordedClock: closure returning the pause-adjusted recorded time
    ///     (RecordingService.recordedElapsedTime).
    ///   - voiceNotesEnabled: settings.reviewVoiceNotesEnabled at start time.
    func start(recordedClock: @escaping @Sendable () -> TimeInterval,
               voiceNotesEnabled: Bool) async

    /// Captures a manual flag at the current recorded time (FR-002, FR-003).
    /// No-op (with haptic/sound feedback suppressed) unless `.active`.
    /// Returns the new issue so UI can offer the quick-note field (FR-004).
    @discardableResult
    func flagCurrentMoment() -> ReviewIssue?

    /// Attaches typed text to an existing issue (quick-note field, FR-004;
    /// summary edits, FR-012).
    func setNote(_ text: String, for issueID: UUID)

    /// Removes an issue (summary, FR-012).
    func deleteIssue(_ issueID: UUID)

    /// Suspends flagging + transcription while the recording is paused (FR-017).
    func suspend()
    /// Resumes after recording resume.
    func resume()

    /// Ends the session and returns everything the report generator needs.
    /// Screenshots are finalized (PNG encode complete) before return.
    func finish() async -> ReviewSessionOutput

    /// Discards the session: deletes temp screenshots and transcript (FR-016).
    func cancel()
}

enum ReviewSessionPhase: Equatable, Sendable {
    case inactive, active, suspended, finalizing
}

/// Immutable result of a finished session, input to ReviewReportGenerator.
struct ReviewSessionOutput: Sendable {
    let issues: [ReviewIssue]                 // chronological, screenshots on disk in tempDirectory
    let transcript: [TranscriptSegment]
    let tempDirectory: URL
}
