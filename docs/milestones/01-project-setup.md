# Milestone 1: Project Setup & Core Infrastructure

## Overview

**Goal**: Establish the project foundation with a working menu bar application, proper architecture, and core services.

**Prerequisites**: Xcode 15+, macOS 14.0+ SDK

---

## Deliverables

| Deliverable | Description | Priority |
|-------------|-------------|----------|
| Xcode Project | Configured with proper settings and entitlements | P0 |
| App Architecture | AppCoordinator and service layer | P0 |
| Menu Bar Module | Status item with dropdown menu | P0 |
| Permission Manager | Screen recording permission handling | P0 |
| Shortcut Manager | Global keyboard shortcut system | P0 |
| Settings System | Preferences window and persistence | P0 |
| App Delegate | Lifecycle management | P0 |

---

## Implementation Tasks

### 1.1 Create Xcode Project

**Task**: Create new macOS app project

```
Project Configuration:
- Product Name: ScreenPro
- Team: [Developer Team]
- Organization Identifier: com.yourcompany
- Bundle Identifier: com.yourcompany.ScreenPro
- Interface: SwiftUI
- Language: Swift
- Storage: None (we'll add SwiftData later)
```

**Build Settings**:
```
MACOSX_DEPLOYMENT_TARGET = 14.0
SWIFT_VERSION = 5.9
ENABLE_HARDENED_RUNTIME = YES
CODE_SIGN_ENTITLEMENTS = ScreenPro/ScreenPro.entitlements
```

**Info.plist Additions**:
```xml
<key>LSUIElement</key>
<true/>  <!-- Hide from Dock -->

<key>NSScreenCaptureUsageDescription</key>
<string>ScreenPro needs screen recording permission to capture screenshots and record your screen.</string>

<key>NSMicrophoneUsageDescription</key>
<string>ScreenPro needs microphone access to record audio with your screen recordings.</string>
```

**Files to Create**:
```
ScreenPro/
├── ScreenProApp.swift
├── AppDelegate.swift
├── ScreenPro.entitlements
└── Info.plist
```

---

### 1.2 Configure Entitlements

**Task**: Set up app entitlements for required capabilities

**File**: `ScreenPro.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- App Sandbox (required for App Store) -->
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- User-selected files (save screenshots) -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>

    <!-- Downloads folder access -->
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>

    <!-- Pictures folder access -->
    <key>com.apple.security.assets.pictures.read-write</key>
    <true/>

    <!-- Network access (for cloud upload) -->
    <key>com.apple.security.network.client</key>
    <true/>

    <!-- Audio input (microphone) -->
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
```

**Note**: Screen recording permission is handled via TCC (Transparency, Consent, and Control) at runtime, not via entitlements.

---

### 1.3 Implement App Entry Point

**Task**: Set up SwiftUI app with AppDelegate

**File**: `ScreenProApp.swift`

```swift
import SwiftUI

@main
struct ScreenProApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window
        Settings {
            SettingsView()
                .environmentObject(appDelegate.coordinator)
        }

        // Menu bar extra
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appDelegate.coordinator)
        } label: {
            Image(systemName: "camera.viewfinder")
        }
        .menuBarExtraStyle(.menu)
    }
}
```

**File**: `AppDelegate.swift`

```swift
import AppKit
import ScreenCaptureKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize services
        Task {
            await coordinator.initialize()
        }

        // Register global shortcuts
        coordinator.shortcutManager.registerDefaults()

        // Check permissions on launch
        coordinator.permissionManager.checkInitialPermissions()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.cleanup()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Show settings if user clicks dock icon (if visible)
        if !flag {
            coordinator.showSettings()
        }
        return true
    }
}
```

---

### 1.4 Implement AppCoordinator

**Task**: Create central state machine and service container

**File**: `Core/AppCoordinator.swift`

```swift
import SwiftUI
import Combine

@MainActor
final class AppCoordinator: ObservableObject {
    // MARK: - State

    enum State: Equatable {
        case idle
        case requestingPermission
        case selectingArea
        case selectingWindow
        case capturing
        case recording
        case annotating(UUID)  // Capture ID
        case uploading(UUID)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var isReady: Bool = false

    // MARK: - Services

    let permissionManager: PermissionManager
    let shortcutManager: ShortcutManager
    let settingsManager: SettingsManager
    let storageService: StorageService

    // Will be initialized in later milestones
    var captureService: CaptureService?
    var recordingService: RecordingService?

    // MARK: - Windows

    private var settingsWindow: NSWindow?

    // MARK: - Initialization

    init() {
        self.permissionManager = PermissionManager()
        self.shortcutManager = ShortcutManager()
        self.settingsManager = SettingsManager()
        self.storageService = StorageService()
    }

    func initialize() async {
        // Check screen recording permission
        let hasPermission = await permissionManager.checkScreenRecordingPermission()

        if !hasPermission {
            state = .requestingPermission
        } else {
            isReady = true
            state = .idle
        }
    }

    func cleanup() {
        shortcutManager.unregisterAll()
    }

    // MARK: - Actions

    func captureArea() {
        guard isReady else {
            requestPermission()
            return
        }
        state = .selectingArea
        // Implementation in Milestone 2
    }

    func captureWindow() {
        guard isReady else {
            requestPermission()
            return
        }
        state = .selectingWindow
        // Implementation in Milestone 2
    }

    func captureFullscreen() {
        guard isReady else {
            requestPermission()
            return
        }
        state = .capturing
        // Implementation in Milestone 2
    }

    func startRecording() {
        guard isReady else {
            requestPermission()
            return
        }
        state = .recording
        // Implementation in Milestone 5
    }

    func requestPermission() {
        state = .requestingPermission
        permissionManager.requestScreenRecordingPermission()
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "ScreenPro Settings"
            window.contentView = NSHostingView(
                rootView: SettingsView().environmentObject(self)
            )
            window.center()
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

---

### 1.5 Implement Permission Manager

**Task**: Handle screen recording and microphone permissions

**File**: `Core/Services/PermissionManager.swift`

```swift
import ScreenCaptureKit
import AVFoundation
import Combine

@MainActor
final class PermissionManager: ObservableObject {
    // MARK: - State

    enum PermissionStatus {
        case authorized
        case denied
        case notDetermined
    }

    @Published private(set) var screenRecordingStatus: PermissionStatus = .notDetermined
    @Published private(set) var microphoneStatus: PermissionStatus = .notDetermined

    // MARK: - Screen Recording

    func checkScreenRecordingPermission() async -> Bool {
        // ScreenCaptureKit automatically triggers permission dialog
        // when accessing shareable content
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            // If we got content, we have permission
            screenRecordingStatus = .authorized
            return !content.windows.isEmpty || !content.displays.isEmpty
        } catch {
            // Permission denied or error
            if let scError = error as? SCStreamError,
               scError.code == .userDeclined {
                screenRecordingStatus = .denied
            } else {
                screenRecordingStatus = .notDetermined
            }
            return false
        }
    }

    func requestScreenRecordingPermission() {
        // Opening System Preferences is the only way to grant permission
        openScreenRecordingPreferences()
    }

    func openScreenRecordingPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Microphone

    func checkMicrophonePermission() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneStatus = .authorized
            return .authorized
        case .denied, .restricted:
            microphoneStatus = .denied
            return .denied
        case .notDetermined:
            microphoneStatus = .notDetermined
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Task { @MainActor in
                    self.microphoneStatus = granted ? .authorized : .denied
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func openMicrophonePreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Initial Check

    func checkInitialPermissions() {
        Task {
            _ = await checkScreenRecordingPermission()
            _ = checkMicrophonePermission()
        }
    }
}
```

---

### 1.6 Implement Shortcut Manager

**Task**: Register and handle global keyboard shortcuts

**File**: `Core/Services/ShortcutManager.swift`

```swift
import Carbon
import AppKit
import Combine

final class ShortcutManager: ObservableObject {
    // MARK: - Types

    struct Shortcut: Codable, Hashable {
        var keyCode: UInt32
        var modifiers: UInt32

        var displayString: String {
            var parts: [String] = []
            if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
            if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
            if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
            if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
            // Add key character (simplified)
            parts.append(keyCodeToString(keyCode))
            return parts.joined()
        }

        private func keyCodeToString(_ code: UInt32) -> String {
            // Common key codes
            let keyMap: [UInt32: String] = [
                0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5",
                0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9", 0x1D: "0",
                0x23: "5" // Numpad 5, used for All-in-One
            ]
            return keyMap[code] ?? "?"
        }
    }

    enum Action: String, CaseIterable, Codable {
        case captureArea
        case captureWindow
        case captureFullscreen
        case captureScrolling
        case startRecording
        case recordGIF
        case textRecognition
        case allInOne
    }

    // MARK: - Properties

    @Published var shortcuts: [Action: Shortcut] = [:]
    private var hotKeyRefs: [Action: EventHotKeyRef] = [:]
    private var actionHandler: ((Action) -> Void)?

    // MARK: - Default Shortcuts

    static let defaults: [Action: Shortcut] = [
        .captureArea: Shortcut(
            keyCode: 0x15,  // 4
            modifiers: UInt32(cmdKey | shiftKey)
        ),
        .captureFullscreen: Shortcut(
            keyCode: 0x14,  // 3
            modifiers: UInt32(cmdKey | shiftKey)
        ),
        .allInOne: Shortcut(
            keyCode: 0x17,  // 5
            modifiers: UInt32(cmdKey | shiftKey)
        ),
        .startRecording: Shortcut(
            keyCode: 0x16,  // 6
            modifiers: UInt32(cmdKey | shiftKey)
        )
    ]

    // MARK: - Registration

    func registerDefaults() {
        shortcuts = Self.defaults
        registerAll()
    }

    func setActionHandler(_ handler: @escaping (Action) -> Void) {
        actionHandler = handler
    }

    func registerAll() {
        for (action, shortcut) in shortcuts {
            register(shortcut, for: action)
        }
    }

    func register(_ shortcut: Shortcut, for action: Action) {
        // Unregister existing if any
        unregister(action)

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(
            signature: OSType(action.hashValue & 0xFFFFFFFF),
            id: UInt32(action.hashValue & 0xFFFF)
        )

        let status = RegisterEventHotKey(
            hotKeyRef,
            shortcut.modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            hotKeyRefs[action] = ref
        }
    }

    func unregister(_ action: Action) {
        if let ref = hotKeyRefs[action] {
            UnregisterEventHotKey(ref)
            hotKeyRefs[action] = nil
        }
    }

    func unregisterAll() {
        for action in Action.allCases {
            unregister(action)
        }
    }

    // MARK: - Conflict Detection

    func detectConflict(for shortcut: Shortcut) -> String? {
        // Check against system shortcuts
        // This is a simplified check
        let systemShortcuts: [Shortcut: String] = [
            Shortcut(keyCode: 0x14, modifiers: UInt32(cmdKey | shiftKey)): "macOS Screenshot"
        ]

        return systemShortcuts[shortcut]
    }
}
```

**Note**: The Carbon-based hot key API is being used here for simplicity. For a production app, consider using a library like HotKey or implementing modern event tap-based shortcuts.

---

### 1.7 Implement Settings Manager

**Task**: Persist user preferences

**File**: `Core/Services/SettingsManager.swift`

```swift
import Foundation
import Combine

final class SettingsManager: ObservableObject {
    // MARK: - Settings Model

    struct Settings: Codable {
        // General
        var launchAtLogin: Bool = false
        var showMenuBarIcon: Bool = true
        var playCaptureSound: Bool = true

        // Capture
        var defaultSaveLocation: URL = FileManager.default.urls(
            for: .picturesDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("ScreenPro")

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
        var autoDismissDelay: TimeInterval = 0  // 0 = manual dismiss
    }

    enum ImageFormat: String, Codable, CaseIterable {
        case png, jpeg, tiff, heic

        var fileExtension: String { rawValue }
        var utType: String {
            switch self {
            case .png: return "public.png"
            case .jpeg: return "public.jpeg"
            case .tiff: return "public.tiff"
            case .heic: return "public.heic"
            }
        }
    }

    enum VideoFormat: String, Codable, CaseIterable {
        case mp4, mov

        var fileExtension: String { rawValue }
    }

    enum VideoQuality: String, Codable, CaseIterable {
        case low, medium, high, maximum

        var displayName: String {
            switch self {
            case .low: return "Low (480p)"
            case .medium: return "Medium (720p)"
            case .high: return "High (1080p)"
            case .maximum: return "Maximum (4K)"
            }
        }
    }

    enum QuickAccessPosition: String, Codable, CaseIterable {
        case bottomLeft, bottomRight, topLeft, topRight
    }

    // MARK: - Properties

    @Published var settings: Settings {
        didSet {
            save()
        }
    }

    private let userDefaults = UserDefaults.standard
    private let settingsKey = "ScreenProSettings"

    // MARK: - Initialization

    init() {
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(Settings.self, from: data) {
            settings = decoded
        } else {
            settings = Settings()
        }

        // Ensure save directory exists
        createSaveDirectoryIfNeeded()
    }

    // MARK: - Persistence

    func save() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
        }
    }

    func reset() {
        settings = Settings()
    }

    // MARK: - Helpers

    private func createSaveDirectoryIfNeeded() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: settings.defaultSaveLocation.path) {
            try? fm.createDirectory(
                at: settings.defaultSaveLocation,
                withIntermediateDirectories: true
            )
        }
    }

    func generateFilename(for type: CaptureType) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: Date())

        formatter.dateFormat = "HH.mm.ss"
        let time = formatter.string(from: Date())

        var name = settings.fileNamingPattern
        name = name.replacingOccurrences(of: "{date}", with: date)
        name = name.replacingOccurrences(of: "{time}", with: time)

        let ext: String
        switch type {
        case .screenshot:
            ext = settings.defaultImageFormat.fileExtension
        case .video:
            ext = settings.defaultVideoFormat.fileExtension
        case .gif:
            ext = "gif"
        }

        return "\(name).\(ext)"
    }

    enum CaptureType {
        case screenshot, video, gif
    }
}
```

---

### 1.8 Implement Storage Service

**Task**: Handle file operations and history (minimal for M1)

**File**: `Core/Services/StorageService.swift`

```swift
import Foundation
import UniformTypeIdentifiers

final class StorageService {
    // MARK: - Properties

    private let fileManager = FileManager.default

    // MARK: - File Operations

    func save(
        imageData: Data,
        filename: String,
        to directory: URL
    ) throws -> URL {
        // Ensure directory exists
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let fileURL = directory.appendingPathComponent(filename)

        // Handle filename conflicts
        let finalURL = uniqueURL(for: fileURL)

        try imageData.write(to: finalURL)
        return finalURL
    }

    func delete(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    // MARK: - Clipboard

    func copyToClipboard(imageData: Data, type: UTType) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(imageData, forType: NSPasteboard.PasteboardType(type.identifier))
    }

    func copyToClipboard(image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    // MARK: - Helpers

    private func uniqueURL(for url: URL) -> URL {
        var resultURL = url
        var counter = 1

        let directory = url.deletingLastPathComponent()
        let filename = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        while fileManager.fileExists(atPath: resultURL.path) {
            resultURL = directory
                .appendingPathComponent("\(filename) (\(counter))")
                .appendingPathExtension(ext)
            counter += 1
        }

        return resultURL
    }
}
```

---

### 1.9 Implement Menu Bar View

**Task**: Create menu bar dropdown UI

**File**: `Features/MenuBar/MenuBarView.swift`

```swift
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        Group {
            // Capture Section
            Section {
                Button {
                    coordinator.captureArea()
                } label: {
                    Label("Capture Area", systemImage: "rectangle.dashed")
                }
                .keyboardShortcut("4", modifiers: [.command, .shift])

                Button {
                    coordinator.captureWindow()
                } label: {
                    Label("Capture Window", systemImage: "macwindow")
                }

                Button {
                    coordinator.captureFullscreen()
                } label: {
                    Label("Capture Fullscreen", systemImage: "rectangle.fill")
                }
                .keyboardShortcut("3", modifiers: [.command, .shift])
            }

            Divider()

            // Recording Section
            Section {
                Button {
                    coordinator.startRecording()
                } label: {
                    Label("Record Screen", systemImage: "record.circle")
                }
                .keyboardShortcut("6", modifiers: [.command, .shift])

                Button {
                    // GIF recording - Milestone 5
                } label: {
                    Label("Record GIF", systemImage: "photo.stack")
                }
                .disabled(true)
            }

            Divider()

            // Advanced Section
            Section {
                Button {
                    // Scrolling capture - Milestone 6
                } label: {
                    Label("Scrolling Capture", systemImage: "arrow.up.arrow.down.square")
                }
                .disabled(true)

                Button {
                    // Text recognition - Milestone 6
                } label: {
                    Label("Recognize Text", systemImage: "text.viewfinder")
                }
                .disabled(true)
            }

            Divider()

            // App Section
            Section {
                Button {
                    // History - Milestone 7
                } label: {
                    Label("Capture History", systemImage: "clock.arrow.circlepath")
                }
                .disabled(true)

                Button {
                    coordinator.showSettings()
                } label: {
                    Label("Settings...", systemImage: "gear")
                }
                .keyboardShortcut(",", modifiers: .command)

                Divider()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit ScreenPro", systemImage: "power")
                }
                .keyboardShortcut("Q", modifiers: .command)
            }
        }
    }
}
```

---

### 1.10 Implement Settings View

**Task**: Create preferences window UI

**File**: `Features/Settings/SettingsView.swift`

```swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            CaptureSettingsTab()
                .tabItem {
                    Label("Capture", systemImage: "camera")
                }

            RecordingSettingsTab()
                .tabItem {
                    Label("Recording", systemImage: "record.circle")
                }

            ShortcutsSettingsTab()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 500, height: 350)
        .environmentObject(coordinator.settingsManager)
        .environmentObject(coordinator.permissionManager)
    }
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var permissions: PermissionManager

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $settings.settings.launchAtLogin)
                Toggle("Show menu bar icon", isOn: $settings.settings.showMenuBarIcon)
            }

            Section("Feedback") {
                Toggle("Play capture sound", isOn: $settings.settings.playCaptureSound)
            }

            Section("Permissions") {
                PermissionRow(
                    title: "Screen Recording",
                    status: permissions.screenRecordingStatus,
                    action: permissions.openScreenRecordingPreferences
                )

                PermissionRow(
                    title: "Microphone",
                    status: permissions.microphoneStatus,
                    action: permissions.openMicrophonePreferences
                )
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct PermissionRow: View {
    let title: String
    let status: PermissionManager.PermissionStatus
    let action: () -> Void

    var body: some View {
        HStack {
            Text(title)

            Spacer()

            switch status {
            case .authorized:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Granted")
                    .foregroundColor(.secondary)
            case .denied:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Button("Open Settings") {
                    action()
                }
            case .notDetermined:
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.orange)
                Button("Request") {
                    action()
                }
            }
        }
    }
}

// MARK: - Capture Tab

struct CaptureSettingsTab: View {
    @EnvironmentObject var settings: SettingsManager
    @State private var showFolderPicker = false

    var body: some View {
        Form {
            Section("Save Location") {
                HStack {
                    Text(settings.settings.defaultSaveLocation.path)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button("Choose...") {
                        showFolderPicker = true
                    }
                }
            }

            Section("File Naming") {
                TextField("Pattern", text: $settings.settings.fileNamingPattern)
                Text("Use {date} and {time} as placeholders")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Format") {
                Picker("Image Format", selection: $settings.settings.defaultImageFormat) {
                    ForEach(SettingsManager.ImageFormat.allCases, id: \.self) { format in
                        Text(format.rawValue.uppercased()).tag(format)
                    }
                }
            }

            Section("Capture Options") {
                Toggle("Include cursor", isOn: $settings.settings.includeCursor)
                Toggle("Show crosshair", isOn: $settings.settings.showCrosshair)
                Toggle("Show magnifier", isOn: $settings.settings.showMagnifier)
                Toggle("Hide desktop icons", isOn: $settings.settings.hideDesktopIcons)
            }
        }
        .formStyle(.grouped)
        .padding()
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder]
        ) { result in
            if case .success(let url) = result {
                settings.settings.defaultSaveLocation = url
            }
        }
    }
}

// MARK: - Recording Tab

struct RecordingSettingsTab: View {
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        Form {
            Section("Video") {
                Picker("Format", selection: $settings.settings.defaultVideoFormat) {
                    ForEach(SettingsManager.VideoFormat.allCases, id: \.self) { format in
                        Text(format.rawValue.uppercased()).tag(format)
                    }
                }

                Picker("Quality", selection: $settings.settings.videoQuality) {
                    ForEach(SettingsManager.VideoQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }

                Picker("Frame Rate", selection: $settings.settings.videoFPS) {
                    Text("24 fps").tag(24)
                    Text("30 fps").tag(30)
                    Text("60 fps").tag(60)
                }
            }

            Section("Audio") {
                Toggle("Record microphone", isOn: $settings.settings.recordMicrophone)
                Toggle("Record system audio", isOn: $settings.settings.recordSystemAudio)
            }

            Section("Overlays") {
                Toggle("Show mouse clicks", isOn: $settings.settings.showClicks)
                Toggle("Show keystrokes", isOn: $settings.settings.showKeystrokes)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Shortcuts Tab

struct ShortcutsSettingsTab: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        Form {
            Section("Capture") {
                ShortcutRow(
                    title: "Capture Area",
                    action: .captureArea,
                    manager: coordinator.shortcutManager
                )
                ShortcutRow(
                    title: "Capture Fullscreen",
                    action: .captureFullscreen,
                    manager: coordinator.shortcutManager
                )
                ShortcutRow(
                    title: "All-in-One",
                    action: .allInOne,
                    manager: coordinator.shortcutManager
                )
            }

            Section("Recording") {
                ShortcutRow(
                    title: "Record Screen",
                    action: .startRecording,
                    manager: coordinator.shortcutManager
                )
                ShortcutRow(
                    title: "Record GIF",
                    action: .recordGIF,
                    manager: coordinator.shortcutManager
                )
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ShortcutRow: View {
    let title: String
    let action: ShortcutManager.Action
    @ObservedObject var manager: ShortcutManager

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(manager.shortcuts[action]?.displayString ?? "Not set")
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
    }
}
```

---

## File Structure After Milestone 1

```
ScreenPro/
├── ScreenProApp.swift
├── AppDelegate.swift
├── Info.plist
├── ScreenPro.entitlements
│
├── Core/
│   ├── AppCoordinator.swift
│   └── Services/
│       ├── PermissionManager.swift
│       ├── ShortcutManager.swift
│       ├── SettingsManager.swift
│       └── StorageService.swift
│
├── Features/
│   ├── MenuBar/
│   │   └── MenuBarView.swift
│   └── Settings/
│       └── SettingsView.swift
│
└── Resources/
    └── Assets.xcassets/
        └── AppIcon.appiconset/
```

---

## Testing Checklist

### Manual Testing

- [ ] App launches and shows menu bar icon
- [ ] Menu bar dropdown displays all options
- [ ] Disabled features show as disabled
- [ ] Settings window opens
- [ ] Settings tabs are navigable
- [ ] Settings persist after restart
- [ ] Screen recording permission prompt appears
- [ ] "Open Settings" links to correct preference pane
- [ ] Quit menu item closes app
- [ ] App doesn't appear in Dock

### Unit Tests

```swift
// SettingsManagerTests.swift
final class SettingsManagerTests: XCTestCase {
    func testDefaultSettings() {
        let manager = SettingsManager()
        XCTAssertEqual(manager.settings.defaultImageFormat, .png)
        XCTAssertTrue(manager.settings.showQuickAccess)
    }

    func testSettingsPersistence() {
        let manager = SettingsManager()
        manager.settings.playCaptureSound = false
        manager.save()

        let newManager = SettingsManager()
        XCTAssertFalse(newManager.settings.playCaptureSound)
    }

    func testFilenameGeneration() {
        let manager = SettingsManager()
        let filename = manager.generateFilename(for: .screenshot)
        XCTAssertTrue(filename.hasSuffix(".png"))
        XCTAssertTrue(filename.contains("Screenshot"))
    }
}
```

---

## Exit Criteria

| Criterion | Verification |
|-----------|--------------|
| App builds without warnings | Xcode build succeeds |
| Menu bar icon appears | Visual verification |
| Menu dropdown works | Click and verify options |
| Settings window opens | Cmd+, or menu item |
| Settings persist | Change setting, restart, verify |
| Permission dialog appears | Fresh install or reset permissions |
| Permission status displays correctly | Check Settings > Permissions |
| Global shortcuts register | Check with shortcut recorder |

---

## Next Steps

After completing Milestone 1, proceed to [Milestone 2: Basic Screenshot Capture](./02-basic-capture.md) to implement the core capture functionality.
