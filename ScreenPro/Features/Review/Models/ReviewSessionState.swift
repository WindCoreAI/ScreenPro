import Foundation

// MARK: - Review Session State (008-review-recording)

/// Lifecycle phase of a review session. Flags are accepted only while `.active`.
enum ReviewSessionPhase: Equatable, Sendable {
    case inactive
    case active
    case suspended
    case finalizing
}

/// One contiguous spoken observation in the session narration.
struct TranscriptSegment: Codable, Sendable, Equatable {
    /// Recorded time (pause-adjusted) the utterance began.
    let start: TimeInterval
    /// Recorded time of the last recognized word.
    let end: TimeInterval
    let text: String
}

/// Immutable result of a finished session — input to ReviewReportGenerator.
struct ReviewSessionOutput: Sendable {
    /// Chronological issues; screenshots exist on disk in `tempDirectory`.
    let issues: [ReviewIssue]
    let transcript: [TranscriptSegment]
    let tempDirectory: URL

    var isEmpty: Bool { issues.isEmpty && transcript.isEmpty }
}

// MARK: - RecordedTimeClock

/// Pause-adjusted recorded-time source, readable from any thread.
///
/// Mirrors the pause-offset clock the video writer uses for frame timestamps
/// (research.md R5), so issue timestamps always seek correctly in the saved
/// video. Driven by ReviewSessionService from the main actor; read from the
/// stream sample queue (frame stamping) and the audio tap thread (utterance
/// stamping).
final class RecordedTimeClock: @unchecked Sendable {
    private let lock = NSLock()
    private var startDate: Date?
    private var pausedAccumulated: TimeInterval = 0
    private var pauseStartedAt: Date?

    func start() {
        lock.lock(); defer { lock.unlock() }
        startDate = Date()
        pausedAccumulated = 0
        pauseStartedAt = nil
    }

    func pause() {
        lock.lock(); defer { lock.unlock() }
        guard startDate != nil, pauseStartedAt == nil else { return }
        pauseStartedAt = Date()
    }

    func resume() {
        lock.lock(); defer { lock.unlock() }
        if let pausedAt = pauseStartedAt {
            pausedAccumulated += Date().timeIntervalSince(pausedAt)
            pauseStartedAt = nil
        }
    }

    func stop() {
        lock.lock(); defer { lock.unlock() }
        startDate = nil
        pausedAccumulated = 0
        pauseStartedAt = nil
    }

    /// Seconds of recorded (non-paused) time since `start()`. 0 when stopped.
    var now: TimeInterval {
        lock.lock(); defer { lock.unlock() }
        guard let start = startDate else { return 0 }
        var elapsed = Date().timeIntervalSince(start) - pausedAccumulated
        if let pausedAt = pauseStartedAt {
            elapsed -= Date().timeIntervalSince(pausedAt)
        }
        return max(0, elapsed)
    }
}
