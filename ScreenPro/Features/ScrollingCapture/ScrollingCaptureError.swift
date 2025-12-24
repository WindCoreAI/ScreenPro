import Foundation

// MARK: - Scrolling Capture Error (T013)

/// Errors that can occur during scrolling capture operations
enum ScrollingCaptureError: LocalizedError {
    /// Screen recording permission was not granted
    case permissionDenied
    /// The specified capture region is invalid (empty or off-screen)
    case invalidRegion
    /// No frames were captured during the scrolling session
    case noFrames
    /// Image stitching failed during composition
    case stitchingFailed
    /// Maximum frame limit was reached
    case maxFramesReached

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission is required for scrolling capture."
        case .invalidRegion:
            return "The selected capture region is invalid."
        case .noFrames:
            return "No frames were captured during the scrolling session."
        case .stitchingFailed:
            return "Failed to stitch captured frames into a single image."
        case .maxFramesReached:
            return "Maximum number of frames reached. The capture has been automatically completed."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Please grant screen recording permission in System Settings > Privacy & Security > Screen Recording."
        case .invalidRegion:
            return "Please select a valid region within the screen bounds."
        case .noFrames:
            return "Try scrolling more slowly or ensure content is visible in the selected region."
        case .stitchingFailed:
            return "Try capturing again with a smaller region or fewer frames."
        case .maxFramesReached:
            return "The maximum frame limit protects against memory issues. You can adjust this in Settings."
        }
    }
}
