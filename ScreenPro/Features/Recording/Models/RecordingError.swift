import Foundation

/// Errors that can occur during recording
enum RecordingError: LocalizedError, Sendable {
    /// No recording is currently in progress
    case notRecording

    /// A recording is already in progress
    case alreadyRecording

    /// Failed to create output file
    case cannotCreateFile(URL)

    /// Screen capture permission not granted
    case screenCaptureNotAuthorized

    /// Microphone permission not granted (when mic enabled)
    case microphoneNotAuthorized

    /// Encoding failed
    case encodingFailed(underlying: String?)

    /// Disk space insufficient
    case insufficientDiskSpace

    /// GIF has no frames to encode
    case noFramesToEncode

    /// Stream configuration failed
    case streamConfigurationFailed

    /// Asset writer setup failed
    case assetWriterSetupFailed(underlying: String?)

    /// Unknown or unexpected error
    case unknown(underlying: String?)

    var errorDescription: String? {
        switch self {
        case .notRecording:
            return "No recording in progress"
        case .alreadyRecording:
            return "A recording is already in progress"
        case .cannotCreateFile(let url):
            return "Cannot create file at \(url.path)"
        case .screenCaptureNotAuthorized:
            return "Screen recording permission required"
        case .microphoneNotAuthorized:
            return "Microphone permission required"
        case .encodingFailed(let underlying):
            if let underlying {
                return "Failed to encode recording: \(underlying)"
            }
            return "Failed to encode recording"
        case .insufficientDiskSpace:
            return "Insufficient disk space"
        case .noFramesToEncode:
            return "No frames captured for GIF"
        case .streamConfigurationFailed:
            return "Failed to configure screen capture stream"
        case .assetWriterSetupFailed(let underlying):
            if let underlying {
                return "Failed to setup video writer: \(underlying)"
            }
            return "Failed to setup video writer"
        case .unknown(let underlying):
            if let underlying {
                return "An error occurred: \(underlying)"
            }
            return "An unknown error occurred"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .screenCaptureNotAuthorized:
            return "Open System Settings > Privacy & Security > Screen Recording and enable ScreenPro"
        case .microphoneNotAuthorized:
            return "Open System Settings > Privacy & Security > Microphone and enable ScreenPro"
        case .insufficientDiskSpace:
            return "Free up disk space and try again"
        case .cannotCreateFile:
            return "Check that the save location is writable"
        default:
            return nil
        }
    }
}
