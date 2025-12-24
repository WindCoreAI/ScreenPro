import Foundation

// MARK: - Camera Overlay Error (T016)

/// Errors that can occur during camera overlay operations
enum CameraOverlayError: LocalizedError {
    /// Camera permission was not granted
    case permissionDenied
    /// No camera device was found
    case deviceNotFound
    /// The camera capture session failed to start
    case captureSessionFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera permission is required for the camera overlay feature."
        case .deviceNotFound:
            return "No camera device was found."
        case .captureSessionFailed:
            return "Failed to start the camera capture session."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Please grant camera permission in System Settings > Privacy & Security > Camera."
        case .deviceNotFound:
            return "Connect a camera device and try again."
        case .captureSessionFailed:
            return "Try again. If the issue persists, ensure no other application is using the camera."
        }
    }
}
