import Foundation

// MARK: - Capture Error

/// Errors that can occur during capture operations.
enum CaptureError: LocalizedError, Sendable {
    /// No display found for the specified capture area.
    case noDisplayFound

    /// Failed to crop the captured image to the selection.
    case cropFailed

    /// Screen recording permission was not granted.
    case permissionDenied

    /// Selection is too small (< 5x5 pixels).
    case invalidSelection

    /// User cancelled the capture operation.
    case cancelled

    /// Failed to capture the screen content.
    case captureFailed(String)

    /// Failed to save the captured image.
    case saveFailed(String)

    /// Window no longer available for capture.
    case windowNotFound

    var errorDescription: String? {
        switch self {
        case .noDisplayFound:
            return "No display found for capture area"
        case .cropFailed:
            return "Failed to crop captured image"
        case .permissionDenied:
            return "Screen recording permission denied"
        case .invalidSelection:
            return "Selection too small (minimum 5x5 pixels)"
        case .cancelled:
            return "Capture cancelled"
        case .captureFailed(let reason):
            return "Failed to capture: \(reason)"
        case .saveFailed(let reason):
            return "Failed to save: \(reason)"
        case .windowNotFound:
            return "Window no longer available"
        }
    }
}
