import Foundation
import SwiftUI
import Combine

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

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

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
    }

    // MARK: - Actions (T024, T025)

    /// Initiates area capture mode
    func captureArea() {
        guard canPerformCapture() else { return }
        state = .selectingArea
        // Actual capture will be implemented in Milestone 2
        print("Area capture initiated (placeholder)")
        // Reset to idle for now
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.state = .idle
        }
    }

    /// Initiates window capture mode
    func captureWindow() {
        guard canPerformCapture() else { return }
        state = .selectingWindow
        // Actual capture will be implemented in Milestone 2
        print("Window capture initiated (placeholder)")
        // Reset to idle for now
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.state = .idle
        }
    }

    /// Captures the entire screen
    func captureFullscreen() {
        guard canPerformCapture() else { return }
        state = .capturing
        // Actual capture will be implemented in Milestone 2
        print("Fullscreen capture initiated (placeholder)")
        // Reset to idle for now
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.state = .idle
        }
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
