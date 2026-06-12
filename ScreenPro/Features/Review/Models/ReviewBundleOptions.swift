import Foundation

// MARK: - Review Bundle Options & Metadata (008-review-recording)

/// What the Review Report bundle includes. Snapshotted from Settings at stop
/// time so mid-session settings changes don't tear the bundle.
struct ReviewBundleOptions: Sendable {
    let includeVideo: Bool
    let includeFullTranscript: Bool

    @MainActor
    static func from(_ settings: Settings) -> ReviewBundleOptions {
        ReviewBundleOptions(
            includeVideo: settings.reviewBundleIncludesVideo,
            includeFullTranscript: settings.reviewBundleIncludesTranscript
        )
    }
}

/// Session metadata recorded in the manifest.
struct ReviewSessionMeta: Sendable {
    let recordedAt: Date
    let duration: TimeInterval
    /// Human descriptor of the recorded target, e.g. "display (2560×1440)",
    /// "window: Safari", "area 800×600".
    let target: String
}

/// Errors from Review Report bundle generation. On any failure the video
/// survives at its original location.
enum ReviewReportError: Error, Equatable, LocalizedError {
    case destinationUnwritable(URL)
    case screenshotMissing(issueID: UUID)
    case encodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .destinationUnwritable(let url):
            return "Cannot write the review report to \(url.path). The recording was kept at its original location."
        case .screenshotMissing:
            return "A flagged screenshot is missing; the review report could not be generated. The recording was kept."
        case .encodingFailed(let reason):
            return "Failed to generate the review report (\(reason)). The recording was kept."
        }
    }
}
