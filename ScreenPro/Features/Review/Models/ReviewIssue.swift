import Foundation

// MARK: - ReviewIssue (008-review-recording)

/// How a review issue was created.
enum ReviewIssueSource: String, Codable, Sendable {
    case manual
    case voice
}

/// One observation captured during a review session: a moment in the
/// recording paired with a screenshot and the reviewer's note/transcript.
struct ReviewIssue: Identifiable, Codable, Sendable, Equatable {
    let id: UUID

    /// Seconds into the recording (pause-adjusted), seekable in the saved video.
    let timestamp: TimeInterval

    let source: ReviewIssueSource

    /// Text typed by the reviewer (quick-note field or summary edit).
    var note: String?

    /// What the reviewer said at this moment (voice issues, or speech merged
    /// into a manual flag per FR-007).
    var transcript: String?

    /// Screenshot filename within the session temp directory; renamed to
    /// `issue-NN.png` by ReviewReportGenerator at bundle finalization.
    let screenshotFilename: String

    init(
        id: UUID = UUID(),
        timestamp: TimeInterval,
        source: ReviewIssueSource,
        note: String? = nil,
        transcript: String? = nil,
        screenshotFilename: String
    ) {
        self.id = id
        self.timestamp = max(0, timestamp)
        self.source = source
        self.note = note
        self.transcript = transcript
        self.screenshotFilename = screenshotFilename
    }

    /// "MM:SS" timecode (hours roll into minutes, matching video seek UIs).
    var timecode: String {
        Self.timecode(for: timestamp)
    }

    static func timecode(for seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
