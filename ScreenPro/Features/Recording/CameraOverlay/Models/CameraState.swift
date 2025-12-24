import Foundation
import AVFoundation

// MARK: - CameraState (T073)

/// State of the camera for overlay.
struct CameraState: Equatable {
    /// Whether the camera session is running.
    let isRunning: Bool

    /// Whether a camera device is available.
    let isAvailable: Bool

    /// The current camera device.
    let deviceName: String?

    /// Any error that occurred.
    let error: CameraError?

    /// Creates a camera state.
    init(
        isRunning: Bool = false,
        isAvailable: Bool = true,
        deviceName: String? = nil,
        error: CameraError? = nil
    ) {
        self.isRunning = isRunning
        self.isAvailable = isAvailable
        self.deviceName = deviceName
        self.error = error
    }

    /// Default idle state.
    static var idle: CameraState {
        CameraState()
    }

    /// Running state with a device.
    static func running(device: String) -> CameraState {
        CameraState(isRunning: true, isAvailable: true, deviceName: device)
    }

    /// Error state.
    static func failed(_ error: CameraError) -> CameraState {
        CameraState(isRunning: false, isAvailable: false, error: error)
    }

    static func == (lhs: CameraState, rhs: CameraState) -> Bool {
        lhs.isRunning == rhs.isRunning &&
        lhs.isAvailable == rhs.isAvailable &&
        lhs.deviceName == rhs.deviceName &&
        lhs.error?.localizedDescription == rhs.error?.localizedDescription
    }
}

// MARK: - CameraError

/// Errors that can occur with camera operations.
enum CameraError: LocalizedError {
    case permissionDenied
    case deviceNotFound
    case sessionConfigurationFailed
    case captureInProgress

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera access was denied."
        case .deviceNotFound:
            return "No camera device found."
        case .sessionConfigurationFailed:
            return "Failed to configure camera session."
        case .captureInProgress:
            return "Camera is already in use."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Please grant camera access in System Settings > Privacy & Security > Camera."
        case .deviceNotFound:
            return "Connect a camera and try again."
        case .sessionConfigurationFailed:
            return "Try restarting the application."
        case .captureInProgress:
            return "Wait for the current capture to complete."
        }
    }
}
