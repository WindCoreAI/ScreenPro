import Foundation

// MARK: - Review Report Generator Contract (008-review-recording)
//
// Pure file producer: session output in, bundle folder out (FR-008..FR-011).
// No UI, no @MainActor — runs off the main actor; safe to test with temp dirs.

protocol ReviewReportGeneratorProtocol: Sendable {
    /// Assembles the Review Report bundle.
    ///
    /// Layout (research.md R7):
    ///   <saveLocation>/Review {date} at {time}/
    ///     recording.mp4            (moved from videoURL when options.includeVideo)
    ///     screenshots/issue-NN.png (renamed from temp, dense chronological numbering)
    ///     report.md
    ///     report.json              (schema: review-manifest.schema.json, v1)
    ///
    /// - Parameters:
    ///   - output: finished session (issues reference temp screenshot files).
    ///   - videoURL: finalized recording from RecordingService.
    ///   - sessionMeta: recordedAt / duration / target descriptor.
    ///   - options: bundle content options snapshot.
    ///   - saveLocation: settings.defaultSaveLocation.
    /// - Returns: URL of the created bundle folder.
    /// - Throws: ReviewReportError. On failure the video MUST survive at its
    ///   original location (edge case: unwritable destination).
    func generate(output: ReviewSessionOutput,
                  videoURL: URL,
                  sessionMeta: ReviewSessionMeta,
                  options: ReviewBundleOptions,
                  saveLocation: URL) async throws -> URL
}

struct ReviewSessionMeta: Sendable {
    let recordedAt: Date
    let duration: TimeInterval
    /// Human descriptor of the recorded target, e.g. "display 1 (2560×1440)",
    /// "window: Safari — Dashboard", "area 800×600".
    let target: String
}

struct ReviewBundleOptions: Sendable {
    let includeVideo: Bool
    let includeFullTranscript: Bool
}

enum ReviewReportError: Error, Equatable {
    case destinationUnwritable(URL)
    case screenshotMissing(issueID: UUID)
    case encodingFailed(String)
}
