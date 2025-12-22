# Service Contracts: Project Setup & Core Infrastructure

**Feature**: 001-project-setup
**Date**: 2025-12-22

## Overview

This document defines the internal service contracts for Milestone 1. These are Swift protocols defining the public interface of each service. All services are `@MainActor` for thread safety with UI operations.

---

## 1. AppCoordinator

Central state machine coordinating all application behavior.

```swift
@MainActor
protocol AppCoordinatorProtocol: ObservableObject {
    // MARK: - State
    var state: AppCoordinator.State { get }
    var isReady: Bool { get }

    // MARK: - Services (read-only access)
    var permissionManager: PermissionManagerProtocol { get }
    var shortcutManager: ShortcutManagerProtocol { get }
    var settingsManager: SettingsManagerProtocol { get }
    var storageService: StorageServiceProtocol { get }

    // MARK: - Lifecycle
    func initialize() async
    func cleanup()

    // MARK: - Actions (Milestone 1 - state transitions only)
    func captureArea()       // Transitions to .selectingArea (placeholder)
    func captureWindow()     // Transitions to .selectingWindow (placeholder)
    func captureFullscreen() // Transitions to .capturing (placeholder)
    func startRecording()    // Transitions to .recording (placeholder)
    func requestPermission() // Transitions to .requestingPermission
    func showSettings()      // Opens settings window
}
```

### State Enum

```swift
enum State: Equatable {
    case idle
    case requestingPermission
    case selectingArea
    case selectingWindow
    case capturing
    case recording
    case annotating(UUID)
    case uploading(UUID)
}
```

---

## 2. PermissionManager

Manages screen recording and microphone permissions.

```swift
@MainActor
protocol PermissionManagerProtocol: ObservableObject {
    // MARK: - Status
    var screenRecordingStatus: PermissionStatus { get }
    var microphoneStatus: PermissionStatus { get }

    // MARK: - Screen Recording
    /// Checks screen recording permission by attempting to access shareable content.
    /// - Returns: `true` if permission is granted, `false` otherwise.
    func checkScreenRecordingPermission() async -> Bool

    /// Opens System Preferences to the Screen Recording privacy pane.
    func requestScreenRecordingPermission()

    /// Opens System Preferences directly to Screen Recording settings.
    func openScreenRecordingPreferences()

    // MARK: - Microphone
    /// Checks current microphone authorization status.
    /// - Returns: Current `PermissionStatus` for microphone access.
    func checkMicrophonePermission() -> PermissionStatus

    /// Requests microphone permission from the user.
    /// - Returns: `true` if permission was granted, `false` otherwise.
    func requestMicrophonePermission() async -> Bool

    /// Opens System Preferences to the Microphone privacy pane.
    func openMicrophonePreferences()

    // MARK: - Initial Check
    /// Checks all permissions on app launch. Updates published status properties.
    func checkInitialPermissions()
}

enum PermissionStatus {
    case authorized
    case denied
    case notDetermined
}
```

---

## 3. ShortcutManager

Manages global keyboard shortcut registration.

```swift
protocol ShortcutManagerProtocol: ObservableObject {
    // MARK: - Registered Shortcuts
    var shortcuts: [ShortcutAction: Shortcut] { get }

    // MARK: - Registration
    /// Registers all default shortcuts.
    func registerDefaults()

    /// Sets the callback to invoke when a shortcut is triggered.
    /// - Parameter handler: Closure called with the triggered action.
    func setActionHandler(_ handler: @escaping (ShortcutAction) -> Void)

    /// Registers all configured shortcuts.
    func registerAll()

    /// Registers a single shortcut for a specific action.
    /// - Parameters:
    ///   - shortcut: The keyboard shortcut to register.
    ///   - action: The action to trigger when shortcut is pressed.
    func register(_ shortcut: Shortcut, for action: ShortcutAction)

    /// Unregisters a shortcut for a specific action.
    /// - Parameter action: The action to unregister.
    func unregister(_ action: ShortcutAction)

    /// Unregisters all shortcuts.
    func unregisterAll()

    // MARK: - Conflict Detection
    /// Detects if a shortcut conflicts with system shortcuts.
    /// - Parameter shortcut: The shortcut to check.
    /// - Returns: Name of conflicting app/system feature, or `nil` if no conflict.
    func detectConflict(for shortcut: Shortcut) -> String?
}

enum ShortcutAction: String, CaseIterable, Codable {
    case captureArea
    case captureWindow
    case captureFullscreen
    case captureScrolling
    case startRecording
    case recordGIF
    case textRecognition
    case allInOne
}

struct Shortcut: Codable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32
    var displayString: String { /* computed */ }
}
```

---

## 4. SettingsManager

Manages user preferences persistence.

```swift
protocol SettingsManagerProtocol: ObservableObject {
    // MARK: - Settings Access
    var settings: Settings { get set }

    // MARK: - Persistence
    /// Saves current settings to UserDefaults.
    func save()

    /// Resets all settings to defaults.
    func reset()

    // MARK: - Filename Generation
    /// Generates a filename based on settings pattern and capture type.
    /// - Parameter type: The type of capture (screenshot, video, gif).
    /// - Returns: Generated filename with appropriate extension.
    func generateFilename(for type: CaptureType) -> String
}

enum CaptureType {
    case screenshot
    case video
    case gif
}
```

---

## 5. StorageService

Manages file operations and clipboard.

```swift
protocol StorageServiceProtocol {
    // MARK: - File Operations
    /// Saves image data to disk.
    /// - Parameters:
    ///   - imageData: The image data to save.
    ///   - filename: The desired filename.
    ///   - directory: The target directory.
    /// - Returns: The URL where the file was saved (may differ due to conflict resolution).
    func save(imageData: Data, filename: String, to directory: URL) throws -> URL

    /// Deletes a file at the specified URL.
    /// - Parameter url: The file URL to delete.
    func delete(at url: URL) throws

    // MARK: - Clipboard
    /// Copies image data to the system clipboard.
    /// - Parameters:
    ///   - imageData: The image data to copy.
    ///   - type: The UTType of the image data.
    func copyToClipboard(imageData: Data, type: UTType)

    /// Copies an NSImage to the system clipboard.
    /// - Parameter image: The image to copy.
    func copyToClipboard(image: NSImage)
}
```

---

## 6. Settings Data Contract

Complete settings structure for Milestone 1.

```swift
struct Settings: Codable {
    // General
    var launchAtLogin: Bool = false
    var showMenuBarIcon: Bool = true
    var playCaptureSound: Bool = true

    // Capture
    var defaultSaveLocation: URL = defaultPicturesDirectory
    var fileNamingPattern: String = "Screenshot {date} at {time}"
    var defaultImageFormat: ImageFormat = .png
    var includeCursor: Bool = false
    var showCrosshair: Bool = true
    var showMagnifier: Bool = false
    var hideDesktopIcons: Bool = false

    // Recording
    var defaultVideoFormat: VideoFormat = .mp4
    var videoQuality: VideoQuality = .high
    var videoFPS: Int = 30
    var recordMicrophone: Bool = false
    var recordSystemAudio: Bool = false
    var showClicks: Bool = false
    var showKeystrokes: Bool = false

    // Quick Access
    var showQuickAccess: Bool = true
    var quickAccessPosition: QuickAccessPosition = .bottomLeft
    var autoDismissDelay: TimeInterval = 0
}

enum ImageFormat: String, Codable, CaseIterable {
    case png, jpeg, tiff, heic
}

enum VideoFormat: String, Codable, CaseIterable {
    case mp4, mov
}

enum VideoQuality: String, Codable, CaseIterable {
    case low, medium, high, maximum
}

enum QuickAccessPosition: String, Codable, CaseIterable {
    case bottomLeft, bottomRight, topLeft, topRight
}
```

---

## Error Handling

### StorageError

```swift
enum StorageError: LocalizedError {
    case directoryCreationFailed(URL)
    case writeFailed(URL, Error)
    case deleteFailed(URL, Error)

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let url):
            return "Failed to create directory at \(url.path)"
        case .writeFailed(let url, let error):
            return "Failed to write file to \(url.path): \(error.localizedDescription)"
        case .deleteFailed(let url, let error):
            return "Failed to delete file at \(url.path): \(error.localizedDescription)"
        }
    }
}
```

---

## Thread Safety

All protocols marked `@MainActor` are designed to be called from the main thread. This ensures:
- UI updates happen on main thread
- Published properties update correctly
- No race conditions in state management

Services not requiring UI access (like StorageService) can be called from any thread but should handle their own synchronization if needed.
