import Foundation

// MARK: - Screen Freeze Error (T015)

/// Errors that can occur during screen freeze operations
enum ScreenFreezeError: LocalizedError {
    /// Screen recording permission was not granted
    case permissionDenied
    /// The specified display was not found
    case displayNotFound
    /// The capture operation timed out
    case captureTimeout

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission is required for screen freeze."
        case .displayNotFound:
            return "The specified display could not be found."
        case .captureTimeout:
            return "Screen capture timed out while attempting to freeze the display."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Please grant screen recording permission in System Settings > Privacy & Security > Screen Recording."
        case .displayNotFound:
            return "Ensure the display is connected and try again."
        case .captureTimeout:
            return "Try again. If the issue persists, restart the application."
        }
    }
}
