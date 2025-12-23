import Foundation
import SwiftUI
import Combine
import ScreenCaptureKit
import UserNotifications

// MARK: - AppCoordinator State (T010)

extension AppCoordinator {
    /// Application state machine states
    enum State: Equatable {
        case idle
        case requestingPermission
        case selectingArea
        case selectingWindow
        case capturing
        case recording
        case annotating(UUID)
        case uploading(UUID)

        var isIdle: Bool {
            self == .idle
        }

        var isBusy: Bool {
            switch self {
            case .capturing, .recording, .uploading:
                return true
            default:
                return false
            }
        }
    }
}

// MARK: - AppCoordinator Protocol

@MainActor
protocol AppCoordinatorProtocol: ObservableObject {
    var state: AppCoordinator.State { get }
    var isReady: Bool { get }

    var permissionManager: PermissionManager { get }
    var shortcutManager: ShortcutManager { get }
    var settingsManager: SettingsManager { get }
    var storageService: StorageService { get }

    func initialize() async
    func cleanup()

    func captureArea()
    func captureWindow()
    func captureFullscreen()
    func startRecording()
    func requestPermission()
    func showSettings()
}

// MARK: - AppCoordinator Implementation (T011)

@MainActor
final class AppCoordinator: ObservableObject, AppCoordinatorProtocol {
    // MARK: - Published Properties

    @Published private(set) var state: State = .idle
    @Published private(set) var isReady: Bool = false

    // MARK: - Services

    let permissionManager: PermissionManager
    let shortcutManager: ShortcutManager
    let settingsManager: SettingsManager
    let storageService: StorageService
    private(set) lazy var captureService: CaptureService = {
        CaptureService(
            storageService: storageService,
            settingsManager: settingsManager
        )
    }()
    private(set) lazy var quickAccessController: QuickAccessWindowController = {
        QuickAccessWindowController(
            settingsManager: settingsManager,
            captureService: captureService,
            coordinator: self
        )
    }()

    /// The annotation editor window controller (T017)
    /// Note: Uses NSWindowController type to avoid compile-time dependency on Annotation module.
    /// The actual AnnotationEditorWindowController will be assigned when the Annotation files
    /// are added to the Xcode project build phase.
    var annotationEditorController: NSWindowController?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var selectionWindows: [SelectionWindow] = []
    private var windowPickerController: WindowPickerController?

    // MARK: - Initialization

    init(
        permissionManager: PermissionManager = PermissionManager(),
        shortcutManager: ShortcutManager = ShortcutManager(),
        settingsManager: SettingsManager = SettingsManager(),
        storageService: StorageService = StorageService()
    ) {
        self.permissionManager = permissionManager
        self.shortcutManager = shortcutManager
        self.settingsManager = settingsManager
        self.storageService = storageService

        setupShortcutHandler()
        setupSettingsObserver()
    }

    // MARK: - Lifecycle

    /// Initializes all services and checks permissions
    func initialize() async {
        // Check initial permissions
        permissionManager.checkInitialPermissions()

        // Wait for screen recording permission check
        let hasScreenPermission = await permissionManager.checkScreenRecordingPermission()

        if !hasScreenPermission {
            state = .requestingPermission
        } else {
            state = .idle
        }

        // Register shortcuts
        shortcutManager.registerAll()

        isReady = true
    }

    /// Cleans up resources before app termination
    func cleanup() {
        shortcutManager.unregisterAll()
        settingsManager.save()
        dismissSelectionWindows()
    }

    // MARK: - Actions (T024, T025, T026, T027)

    /// Initiates area capture mode (T026)
    func captureArea() {
        guard canPerformCapture() else { return }
        state = .selectingArea
        beginAreaSelection()
    }

    /// Initiates window capture mode
    func captureWindow() {
        guard canPerformCapture() else { return }
        state = .selectingWindow
        beginWindowSelection()
    }

    /// Captures the entire screen (T042)
    func captureFullscreen() {
        guard canPerformCapture() else { return }
        state = .capturing
        performFullscreenCapture()
    }

    /// Starts screen recording
    func startRecording() {
        guard canPerformCapture() else { return }
        state = .recording
        // Actual recording will be implemented in a later milestone
        print("Recording started (placeholder)")
        // Reset to idle for now
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.state = .idle
        }
    }

    /// Handles permission request state
    func requestPermission() {
        state = .requestingPermission
        permissionManager.requestScreenRecordingPermission()
    }

    /// Opens the settings window (T037)
    func showSettings() {
        // Settings are handled via SwiftUI Settings scene
        // Cmd+, automatically opens the Settings scene via macOS standard behavior
        // This method is called when user selects Settings from menu
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    // MARK: - Area Selection (T026)

    /// Begins area selection by creating overlay windows on all screens.
    private func beginAreaSelection() {
        Task {
            // Refresh available content before capture
            do {
                try await captureService.refreshAvailableContent()
            } catch {
                handleCaptureError(error)
                return
            }

            // Create selection window for each screen
            for screen in NSScreen.screens {
                let window = SelectionWindow(screen: screen)
                window.selectionDelegate = self
                window.showForSelection()
                selectionWindows.append(window)
            }
        }
    }

    /// Dismisses all selection windows and resets state.
    private func dismissSelectionWindows() {
        for window in selectionWindows {
            window.dismiss()
        }
        selectionWindows.removeAll()
    }

    // MARK: - Window Selection (T038)

    /// Begins window selection mode.
    private func beginWindowSelection() {
        Task {
            do {
                // Refresh available content to get current windows
                try await captureService.refreshAvailableContent()
            } catch {
                handleCaptureError(error)
                return
            }

            let windows = captureService.availableWindows

            guard !windows.isEmpty else {
                handleCaptureError(CaptureError.windowNotFound)
                return
            }

            // Create and use the window picker
            let picker = WindowPickerController()
            windowPickerController = picker

            // Wait for user selection
            let selectedWindow = await picker.pickWindow(from: windows)
            windowPickerController = nil

            if let window = selectedWindow {
                // User selected a window - capture it
                state = .capturing
                do {
                    let result = try await captureService.captureWindow(window)
                    handleCaptureResult(result)
                } catch {
                    handleCaptureError(error)
                }
            } else {
                // User cancelled
                state = .idle
            }
        }
    }

    // MARK: - Fullscreen Capture (T042)

    /// Performs fullscreen capture of the current display.
    private func performFullscreenCapture() {
        Task {
            do {
                try await captureService.refreshAvailableContent()
                let result = try await captureService.captureDisplay(nil)
                handleCaptureResult(result)
            } catch {
                handleCaptureError(error)
            }
        }
    }

    // MARK: - Capture Result Handling (T027, T054, T055, T056)

    /// Handles a successful capture result.
    private func handleCaptureResult(_ result: CaptureResult) {
        // Check if Quick Access is enabled
        if settingsManager.settings.showQuickAccess {
            // Route to Quick Access overlay
            quickAccessController.addCapture(result)

            // Play capture sound if enabled
            captureService.playCaptureSound()

            // Reset state
            state = .idle
        } else {
            // Original behavior: direct save
            // Save to file
            do {
                let url = try captureService.save(result)
                print("Screenshot saved to: \(url.path)")
            } catch {
                print("Failed to save screenshot: \(error)")
            }

            // Copy to clipboard if enabled
            if settingsManager.settings.copyToClipboardAfterCapture {
                captureService.copyToClipboard(result)
            }

            // Play capture sound if enabled
            captureService.playCaptureSound()

            // Show notification
            showNotification(for: result)

            // Reset state
            state = .idle
        }
    }

    /// Opens the annotation editor for a capture.
    /// - Parameter result: The capture to annotate.
    /// - Note: Placeholder implementation for T017. Full implementation in AnnotationEditorWindow.swift
    ///         will override this when the Annotation module is added to the build.
    func openAnnotationEditor(for result: CaptureResult) {
        state = .annotating(result.id)
        // Placeholder: save and open in Preview until Annotation module is compiled
        do {
            let url = try captureService.save(result)
            NSWorkspace.shared.open(url)
        } catch {
            print("Failed to save for annotation: \(error)")
        }
        state = .idle
    }

    /// Handles a capture error (T054).
    private func handleCaptureError(_ error: Error) {
        print("Capture error: \(error)")

        // Show user notification for the error
        if let captureError = error as? CaptureError {
            switch captureError {
            case .cancelled:
                // Don't show notification for user cancellation
                break
            case .permissionDenied:
                permissionManager.openScreenRecordingPreferences()
            default:
                showErrorNotification(captureError.localizedDescription)
            }
        } else {
            showErrorNotification(error.localizedDescription)
        }

        state = .idle
    }

    /// Shows a success notification for a capture (T056).
    private func showNotification(for result: CaptureResult) {
        guard settingsManager.settings.showNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = "Screenshot Captured"
        content.body = "Screenshot saved successfully"
        content.sound = nil // We already played the capture sound

        let request = UNNotificationRequest(
            identifier: result.id.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Shows an error notification.
    private func showErrorNotification(_ message: String) {
        guard settingsManager.settings.showNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = "Screenshot Failed"
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Private Methods

    private func canPerformCapture() -> Bool {
        // Check if we're in a valid state for capture
        guard state.isIdle else {
            print("Cannot capture: app is busy (state: \(state))")
            return false
        }

        // Check screen recording permission
        guard permissionManager.screenRecordingStatus == .authorized else {
            state = .requestingPermission
            permissionManager.openScreenRecordingPreferences()
            return false
        }

        return true
    }

    private func setupShortcutHandler() {
        shortcutManager.setActionHandler { [weak self] action in
            guard let self = self else { return }
            Task { @MainActor in
                self.handleShortcutAction(action)
            }
        }
    }

    private func handleShortcutAction(_ action: ShortcutAction) {
        switch action {
        case .captureArea:
            captureArea()
        case .captureWindow:
            captureWindow()
        case .captureFullscreen:
            captureFullscreen()
        case .captureScrolling:
            // Will be implemented in later milestone
            print("Scrolling capture not yet implemented")
        case .startRecording:
            startRecording()
        case .recordGIF:
            // Will be implemented in later milestone
            print("GIF recording not yet implemented")
        case .textRecognition:
            // Will be implemented in later milestone
            print("Text recognition not yet implemented")
        case .allInOne:
            // Will show all-in-one UI in later milestone
            print("All-in-one mode not yet implemented")
        }
    }

    private func setupSettingsObserver() {
        // Observe settings changes and save automatically
        settingsManager.$settings
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.settingsManager.save()
            }
            .store(in: &cancellables)
    }
}

// MARK: - SelectionWindowDelegate

extension AppCoordinator: SelectionWindowDelegate {
    func selectionWindow(_ window: SelectionWindow, didSelectRect rect: CGRect) {
        // Dismiss all selection windows
        dismissSelectionWindows()

        // Transition to capturing state
        state = .capturing

        // Perform the capture
        Task {
            do {
                let result = try await captureService.captureArea(rect)
                handleCaptureResult(result)
            } catch {
                handleCaptureError(error)
            }
        }
    }

    func selectionWindowDidCancel(_ window: SelectionWindow) {
        // Dismiss all selection windows
        dismissSelectionWindows()

        // Reset state
        state = .idle
    }
}
