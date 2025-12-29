import Foundation
@preconcurrency import ScreenCaptureKit
import AVFoundation
import AppKit

// MARK: - Permission Status Enum (T009)

/// Status of a system permission
enum PermissionStatus: Equatable {
    case authorized
    case denied
    case notDetermined
}

// MARK: - PermissionManager Protocol

@MainActor
protocol PermissionManagerProtocol: ObservableObject {
    var screenRecordingStatus: PermissionStatus { get }
    var microphoneStatus: PermissionStatus { get }

    func checkScreenRecordingPermission() async -> Bool
    func requestScreenRecordingPermission()
    func openScreenRecordingPreferences()

    func checkMicrophonePermission() -> PermissionStatus
    func requestMicrophonePermission() async -> Bool
    func openMicrophonePreferences()

    func checkInitialPermissions()
}

// MARK: - PermissionManager Implementation (T020-T025, T049-T052 - partial for Phase 2)

@MainActor
final class PermissionManager: ObservableObject, PermissionManagerProtocol {
    // MARK: - Published Properties

    @Published private(set) var screenRecordingStatus: PermissionStatus = .notDetermined
    @Published private(set) var microphoneStatus: PermissionStatus = .notDetermined

    // MARK: - Initialization

    init() {
        // Initial status will be checked via checkInitialPermissions()
    }

    // MARK: - Screen Recording Permission (T020-T023)

    /// Checks screen recording permission by attempting to access shareable content
    func checkScreenRecordingPermission() async -> Bool {
        print("[PermissionManager] Checking screen recording permission...")
        do {
            // Attempt to get shareable content - this triggers permission check
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            print("[PermissionManager] Screen recording permission AUTHORIZED")
            print("[PermissionManager] Available displays: \(content.displays.count), windows: \(content.windows.count)")
            screenRecordingStatus = .authorized
            return true
        } catch {
            // Check error type to determine status
            let nsError = error as NSError
            print("[PermissionManager] Screen recording permission check failed:")
            print("[PermissionManager]   Error: \(error.localizedDescription)")
            print("[PermissionManager]   NSError domain: \(nsError.domain), code: \(nsError.code)")
            if nsError.code == -3801 { // User declined
                print("[PermissionManager]   Status: DENIED (user declined)")
                screenRecordingStatus = .denied
            } else {
                print("[PermissionManager]   Status: NOT_DETERMINED (error code: \(nsError.code))")
                screenRecordingStatus = .notDetermined
            }
            return false
        }
    }

    /// Triggers screen recording permission request by accessing screen content
    func requestScreenRecordingPermission() {
        Task {
            _ = await checkScreenRecordingPermission()
        }
    }

    /// Opens System Preferences to the Screen Recording privacy pane
    func openScreenRecordingPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Microphone Permission (T049-T052)

    /// Checks current microphone authorization status
    func checkMicrophonePermission() -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        let mappedStatus: PermissionStatus
        switch status {
        case .authorized:
            mappedStatus = .authorized
        case .denied, .restricted:
            mappedStatus = .denied
        case .notDetermined:
            mappedStatus = .notDetermined
        @unknown default:
            mappedStatus = .notDetermined
        }
        microphoneStatus = mappedStatus
        return mappedStatus
    }

    /// Requests microphone permission from the user
    func requestMicrophonePermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        microphoneStatus = granted ? .authorized : .denied
        return granted
    }

    /// Opens System Preferences to the Microphone privacy pane
    func openMicrophonePreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Initial Permissions Check (T023)

    /// Checks all permissions on app launch
    func checkInitialPermissions() {
        // Check microphone (synchronous)
        _ = checkMicrophonePermission()

        // Check screen recording (asynchronous)
        Task {
            _ = await checkScreenRecordingPermission()
        }
    }
}
