import Foundation

// MARK: - ReviewManifest (008-review-recording)
//
// Codable mirror of report.json — the integration contract for agentic
// coding tools (specs/008-review-recording/contracts/review-manifest.schema.json).
// All file paths are relative to the bundle folder containing the manifest.

struct ReviewManifest: Codable, Sendable {
    let schemaVersion: Int
    let generator: String
    let session: Session
    let issues: [Issue]
    let fullTranscript: [Segment]?

    static let currentSchemaVersion = 1

    struct Session: Codable, Sendable {
        let recordedAt: Date
        let duration: TimeInterval
        let target: String
        /// Bundle-relative video path; nil when the user excluded the video.
        let videoFile: String?
    }

    struct Issue: Codable, Sendable {
        let id: UUID
        /// 1-based chronological position.
        let index: Int
        /// Seconds into the video.
        let timestamp: TimeInterval
        /// "MM:SS" convenience timecode.
        let timecode: String
        let source: ReviewIssueSource
        let note: String?
        let transcript: String?
        /// Bundle-relative path, always under "screenshots/".
        let screenshot: String
    }

    struct Segment: Codable, Sendable {
        let start: TimeInterval
        let end: TimeInterval
        let text: String
    }
}
