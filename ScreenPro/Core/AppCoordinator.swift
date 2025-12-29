import Foundation
import SwiftUI
import Combine
import ScreenCaptureKit
import UserNotifications
import AVFoundation

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

    /// The recording service for screen recording (T012)
    private(set) lazy var recordingService: RecordingService = {
        RecordingService(
            storageService: storageService,
            settingsManager: settingsManager,
            permissionManager: permissionManager
        )
    }()

    /// The recording controls window (T037)
    private var recordingControlsWindow: RecordingControlsWindow?

    /// The annotation editor window controller (T017)
    /// Note: Uses NSWindowController type to avoid compile-time dependency on Annotation module.
    /// The actual AnnotationEditorWindowController will be assigned when the Annotation files
    /// are added to the Xcode project build phase.
    var annotationEditorController: NSWindowController?

    /// The scrolling capture service (T027)
    private(set) lazy var scrollingCaptureService: ScrollingCaptureService = {
        ScrollingCaptureService()
    }()

    /// The scrolling capture preview window (T027)
    private var scrollingCaptureWindow: ScrollingCaptureWindow?

    /// The text recognition service (T036)
    private(set) lazy var textRecognitionService: TextRecognitionService = {
        let settings = settingsManager.settings
        return TextRecognitionService(
            languages: settings.ocrLanguages,
            autoCopy: settings.ocrCopyToClipboardAutomatically
        )
    }()

    /// The OCR result window (T036)
    private var ocrResultWindow: OCRResultWindow?

    /// The self-timer controller (T044)
    private(set) lazy var selfTimerController: SelfTimerController = {
        SelfTimerController()
    }()

    /// The countdown overlay window (T044)
    private var countdownWindow: CountdownWindow?

    /// The screen freeze controller (T049)
    private(set) lazy var screenFreezeController: ScreenFreezeController = {
        ScreenFreezeController()
    }()

    /// The background tool window (T068)
    private var backgroundToolWindow: BackgroundToolWindow?

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
        print("[AppCoordinator] Initializing...")

        // Check initial permissions
        permissionManager.checkInitialPermissions()

        // Wait for screen recording permission check
        let hasScreenPermission = await permissionManager.checkScreenRecordingPermission()
        print("[AppCoordinator] Screen permission check result: \(hasScreenPermission)")

        if !hasScreenPermission {
            state = .requestingPermission
            print("[AppCoordinator] State set to: requestingPermission")
        } else {
            state = .idle
            print("[AppCoordinator] State set to: idle")
        }

        // Register shortcuts
        shortcutManager.registerAll()

        isReady = true
        print("[AppCoordinator] Initialization complete. isReady=\(isReady), state=\(state)")
    }

    /// Re-checks permissions (call after user grants permission in System Preferences)
    func recheckPermissions() async {
        print("[AppCoordinator] Re-checking permissions...")
        let hasScreenPermission = await permissionManager.checkScreenRecordingPermission()
        print("[AppCoordinator] Re-check result: \(hasScreenPermission), status: \(permissionManager.screenRecordingStatus)")

        if hasScreenPermission && state == .requestingPermission {
            state = .idle
            print("[AppCoordinator] State updated to: idle")
        }
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
        beginFullscreenRecording()
    }

    /// Starts screen recording for a specific region (T024)
    func startRecording(region: RecordingRegion, format: RecordingFormat? = nil) {
        guard canPerformCapture() else { return }
        state = .recording
        performRecording(region: region, format: format)
    }

    /// Starts recording a specific window (T013, T023)
    func startRecordingWindow() {
        guard canPerformCapture() else { return }
        beginWindowRecordingSelection()
    }

    /// Starts recording a selected area (T013, T023)
    func startRecordingArea() {
        guard canPerformCapture() else { return }
        state = .selectingArea
        beginAreaRecordingSelection()
    }

    /// Stops the current recording (T024)
    func stopRecording() {
        guard state == .recording else { return }
        Task {
            do {
                let result = try await recordingService.stopRecording()
                handleRecordingResult(result)
            } catch {
                handleRecordingError(error)
            }
        }
    }

    /// Pauses the current recording
    func pauseRecording() {
        guard state == .recording else { return }
        do {
            try recordingService.pauseRecording()
        } catch {
            handleRecordingError(error)
        }
    }

    /// Resumes a paused recording
    func resumeRecording() {
        guard recordingService.state == .paused else { return }
        do {
            try recordingService.resumeRecording()
        } catch {
            handleRecordingError(error)
        }
    }

    /// Cancels the current recording
    func cancelRecording() {
        Task {
            do {
                try await recordingService.cancelRecording()
                hideRecordingControls()
                state = .idle
            } catch {
                handleRecordingError(error)
            }
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
        // If we're in requestingPermission state but now have permission, transition to idle
        if state == .requestingPermission && permissionManager.screenRecordingStatus == .authorized {
            print("[AppCoordinator] Permission now authorized, transitioning from requestingPermission to idle")
            state = .idle
        }

        // Check if we're in a valid state for capture
        guard state.isIdle else {
            print("[AppCoordinator] Cannot capture: app is busy (state: \(state))")
            return false
        }

        // Check screen recording permission
        guard permissionManager.screenRecordingStatus == .authorized else {
            print("[AppCoordinator] Cannot capture: permission not authorized (\(permissionManager.screenRecordingStatus))")
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
            startScrollingCapture()
        case .startRecording:
            startRecording()
        case .recordGIF:
            // Will be implemented in later milestone
            print("GIF recording not yet implemented")
        case .textRecognition:
            startOCRCapture()
        case .selfTimer:
            startTimedCapture(seconds: settingsManager.settings.selfTimerDefaultDuration)
        case .screenFreeze:
            toggleScreenFreeze()
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

    // MARK: - Scrolling Capture Methods (T027)

    /// Flag indicating if area selection is for scrolling capture
    private var isScrollingCaptureAreaSelection = false

    /// Starts scrolling capture mode (T027)
    func startScrollingCapture() {
        guard canPerformCapture() else { return }
        state = .selectingArea
        isScrollingCaptureAreaSelection = true
        beginAreaSelection()
    }

    /// Begins scrolling capture after area selection (T027)
    private func beginScrollingCapture(region: CGRect, display: SCDisplay) {
        let config = StitchConfig.from(settings: settingsManager.settings)

        Task {
            do {
                try await scrollingCaptureService.startCapture(region: region, display: display, config: config)
                showScrollingCapturePreview()
            } catch {
                handleScrollingCaptureError(error)
            }
        }
    }

    /// Shows the scrolling capture preview window (T027)
    private func showScrollingCapturePreview() {
        let window = ScrollingCaptureWindow(
            captureService: scrollingCaptureService,
            onFinish: { [weak self] in
                self?.finishScrollingCapture()
            },
            onCancel: { [weak self] in
                self?.cancelScrollingCapture()
            }
        )
        window.orderFront(nil)
        scrollingCaptureWindow = window
    }

    /// Hides the scrolling capture preview window (T027)
    private func hideScrollingCapturePreview() {
        scrollingCaptureWindow?.close()
        scrollingCaptureWindow = nil
    }

    /// Finishes scrolling capture and creates the final image (T027)
    private func finishScrollingCapture() {
        Task {
            do {
                let stitchedImage = try await scrollingCaptureService.finishCapture()
                hideScrollingCapturePreview()

                // Create a capture result from the stitched image
                guard let display = captureService.availableDisplays.first else {
                    handleScrollingCaptureError(ScrollingCaptureError.stitchingFailed)
                    return
                }

                let result = CaptureResult(
                    image: stitchedImage,
                    mode: .display(display),
                    sourceRect: CGRect(x: 0, y: 0, width: stitchedImage.width, height: stitchedImage.height),
                    scaleFactor: 2.0
                )

                handleCaptureResult(result)
            } catch {
                handleScrollingCaptureError(error)
            }
        }
    }

    /// Cancels the current scrolling capture (T027)
    private func cancelScrollingCapture() {
        scrollingCaptureService.cancelCapture()
        hideScrollingCapturePreview()
        state = .idle
    }

    /// Handles scrolling capture errors (T027)
    private func handleScrollingCaptureError(_ error: Error) {
        print("Scrolling capture error: \(error)")
        hideScrollingCapturePreview()

        if let scrollingError = error as? ScrollingCaptureError {
            switch scrollingError {
            case .permissionDenied:
                permissionManager.openScreenRecordingPreferences()
            case .maxFramesReached:
                // This is informational, still complete the capture
                finishScrollingCapture()
                return
            default:
                showErrorNotification(scrollingError.localizedDescription)
            }
        } else {
            showErrorNotification(error.localizedDescription)
        }

        state = .idle
    }

    // MARK: - OCR Capture Methods (T036)

    /// Flag indicating if area selection is for OCR capture
    private var isOCRCaptureAreaSelection = false

    /// Starts OCR capture mode (T036)
    func startOCRCapture() {
        guard canPerformCapture() else { return }
        state = .selectingArea
        isOCRCaptureAreaSelection = true
        beginAreaSelection()
    }

    /// Performs OCR on a captured image (T036)
    func performOCR(on image: CGImage) {
        Task {
            do {
                let result = try await textRecognitionService.recognizeText(in: image)

                if result.hasText {
                    showOCRResult(result, image: image)
                } else {
                    showErrorNotification("No text found in the selected region.")
                    state = .idle
                }
            } catch {
                handleOCRError(error)
            }
        }
    }

    /// Shows the OCR result window (T036)
    private func showOCRResult(_ result: RecognitionResult, image: CGImage) {
        let window = OCRResultWindow(
            result: result,
            onCopy: { [weak self] in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result.fullText, forType: .string)

                // Play sound feedback
                NSSound(named: "Pop")?.play()
            },
            onDismiss: { [weak self] in
                self?.hideOCRResult()
            }
        )
        window.orderFront(nil)
        ocrResultWindow = window

        // Also show in Quick Access with the original image
        if settingsManager.settings.showQuickAccess {
            guard let display = captureService.availableDisplays.first else { return }

            let captureResult = CaptureResult(
                image: image,
                mode: .display(display),
                sourceRect: CGRect(x: 0, y: 0, width: image.width, height: image.height),
                scaleFactor: 2.0
            )
            quickAccessController.addCapture(captureResult)
        }

        state = .idle
    }

    /// Hides the OCR result window (T036)
    private func hideOCRResult() {
        ocrResultWindow?.close()
        ocrResultWindow = nil
    }

    /// Handles OCR errors (T036)
    private func handleOCRError(_ error: Error) {
        print("OCR error: \(error)")
        hideOCRResult()

        if let ocrError = error as? TextRecognitionError {
            showErrorNotification(ocrError.localizedDescription)
        } else {
            showErrorNotification(error.localizedDescription)
        }

        state = .idle
    }

    // MARK: - Screen Freeze Methods (T049)

    /// Toggles screen freeze mode (T049)
    func toggleScreenFreeze() {
        Task {
            do {
                try await screenFreezeController.toggle()
            } catch {
                handleScreenFreezeError(error)
            }
        }
    }

    /// Freezes the current screen (T049)
    func freezeScreen() {
        Task {
            do {
                try await screenFreezeController.freeze()
            } catch {
                handleScreenFreezeError(error)
            }
        }
    }

    /// Unfreezes the screen (T049)
    func unfreezeScreen() {
        screenFreezeController.unfreeze()
    }

    /// Captures from the frozen screen (T049)
    func captureFromFrozenScreen() {
        guard screenFreezeController.isFrozen else {
            captureFullscreen()
            return
        }

        state = .capturing

        // Get the frozen image
        if let displayID = screenFreezeController.state.displayID,
           let frozenImage = screenFreezeController.getFrozenImage(for: displayID) {

            // Unfreeze screen
            screenFreezeController.unfreeze()

            // Create capture result
            Task {
                guard let display = captureService.availableDisplays.first else {
                    handleCaptureError(CaptureError.noDisplayFound)
                    return
                }

                let result = CaptureResult(
                    image: frozenImage,
                    mode: .display(display),
                    sourceRect: CGRect(x: 0, y: 0, width: frozenImage.width, height: frozenImage.height),
                    scaleFactor: 2.0
                )

                handleCaptureResult(result)
            }
        } else {
            state = .idle
        }
    }

    /// Handles screen freeze errors (T049)
    private func handleScreenFreezeError(_ error: Error) {
        print("Screen freeze error: \(error)")

        if let freezeError = error as? ScreenFreezeError {
            showErrorNotification(freezeError.localizedDescription)
        } else {
            showErrorNotification(error.localizedDescription)
        }
    }

    // MARK: - Background Tool Methods (T068)

    /// Opens the background tool for a capture result (T068)
    func openBackgroundTool(for result: CaptureResult) {
        let sourceImage = result.nsImage

        let window = BackgroundToolWindow(
            sourceImage: sourceImage,
            onExport: { [weak self] exportedImage in
                self?.handleBackgroundToolExport(exportedImage)
            },
            onDismiss: { [weak self] in
                self?.hideBackgroundTool()
            }
        )
        window.makeKeyAndOrderFront(nil)
        backgroundToolWindow = window
    }

    /// Opens the background tool for an existing image (T068)
    func openBackgroundTool(for image: NSImage) {
        let window = BackgroundToolWindow(
            sourceImage: image,
            onExport: { [weak self] exportedImage in
                self?.handleBackgroundToolExport(exportedImage)
            },
            onDismiss: { [weak self] in
                self?.hideBackgroundTool()
            }
        )
        window.makeKeyAndOrderFront(nil)
        backgroundToolWindow = window
    }

    /// Hides the background tool window (T068)
    private func hideBackgroundTool() {
        backgroundToolWindow?.close()
        backgroundToolWindow = nil
    }

    /// Handles export from the background tool (T068)
    private func handleBackgroundToolExport(_ image: NSImage) {
        hideBackgroundTool()

        // Save the exported image
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let display = captureService.availableDisplays.first else {
            return
        }

        let result = CaptureResult(
            image: cgImage,
            mode: .display(display),
            sourceRect: CGRect(origin: .zero, size: image.size),
            scaleFactor: 1.0
        )

        // Save and show notification
        do {
            let url = try captureService.save(result)
            print("Background image saved to: \(url.path)")

            // Show in Quick Access if enabled
            if settingsManager.settings.showQuickAccess {
                quickAccessController.addCapture(result)
            }
        } catch {
            showErrorNotification("Failed to save image: \(error.localizedDescription)")
        }
    }

    // MARK: - Self-Timer Capture Methods (T044)

    /// The capture mode to use after timer completes
    private var timedCaptureMode: CaptureMode?
    private var timedCaptureRect: CGRect?

    /// Starts a timed capture for fullscreen (T044)
    func startTimedCapture(seconds: Int) {
        guard canPerformCapture() else { return }

        let config = TimerConfig(seconds: seconds)
        timedCaptureMode = nil // Will capture fullscreen

        showCountdownWindow()

        selfTimerController.start(config: config) { [weak self] in
            self?.performTimedFullscreenCapture()
        } onCancel: { [weak self] in
            self?.hideCountdownWindow()
        }
    }

    /// Starts a timed area capture (T044)
    func startTimedAreaCapture(seconds: Int, rect: CGRect) {
        guard canPerformCapture() else { return }

        let config = TimerConfig(seconds: seconds)
        timedCaptureRect = rect

        showCountdownWindow()

        selfTimerController.start(config: config) { [weak self] in
            self?.performTimedAreaCapture()
        } onCancel: { [weak self] in
            self?.hideCountdownWindow()
        }
    }

    /// Cancels the current timed capture (T044)
    func cancelTimedCapture() {
        selfTimerController.cancel()
        hideCountdownWindow()
        timedCaptureMode = nil
        timedCaptureRect = nil
    }

    /// Shows the countdown overlay window (T044)
    private func showCountdownWindow() {
        let window = CountdownWindow(controller: selfTimerController) { [weak self] in
            self?.cancelTimedCapture()
        }
        window.show()
        countdownWindow = window
    }

    /// Hides the countdown overlay window (T044)
    private func hideCountdownWindow() {
        countdownWindow?.hide()
        countdownWindow = nil
    }

    /// Performs a timed fullscreen capture (T044)
    private func performTimedFullscreenCapture() {
        hideCountdownWindow()
        state = .capturing
        performFullscreenCapture()
    }

    /// Performs a timed area capture (T044)
    private func performTimedAreaCapture() {
        guard let rect = timedCaptureRect else {
            hideCountdownWindow()
            state = .idle
            return
        }

        hideCountdownWindow()
        state = .capturing
        timedCaptureRect = nil

        Task {
            do {
                let result = try await captureService.captureArea(rect)
                handleCaptureResult(result)
            } catch {
                handleCaptureError(error)
            }
        }
    }

    // MARK: - Recording Methods (T024, T047)

    /// Recording mode flag - determines if area selection is for capture or recording
    private var isRecordingAreaSelection = false
    private var isRecordingWindowSelection = false

    /// GIF recording mode flag (T047)
    private var isGIFRecording = false

    /// Begins window selection for recording (T023)
    private func beginWindowRecordingSelection() {
        isRecordingWindowSelection = true
        state = .selectingWindow
        Task {
            do {
                try await captureService.refreshAvailableContent()
            } catch {
                handleRecordingError(error)
                isRecordingWindowSelection = false
                return
            }

            let windows = captureService.availableWindows

            guard !windows.isEmpty else {
                handleRecordingError(RecordingError.streamConfigurationFailed)
                isRecordingWindowSelection = false
                return
            }

            let picker = WindowPickerController()
            windowPickerController = picker

            let selectedWindow = await picker.pickWindow(from: windows)
            windowPickerController = nil
            isRecordingWindowSelection = false

            if let window = selectedWindow {
                state = .recording
                let region = RecordingRegion.window(window)
                performRecording(region: region, format: nil)
            } else {
                state = .idle
            }
        }
    }

    /// Begins area selection for recording (T023)
    private func beginAreaRecordingSelection() {
        isRecordingAreaSelection = true
        Task {
            do {
                try await captureService.refreshAvailableContent()
            } catch {
                handleCaptureError(error)
                isRecordingAreaSelection = false
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

    /// Begins fullscreen recording on the main display
    private func beginFullscreenRecording() {
        Task {
            do {
                try await captureService.refreshAvailableContent()
                guard let display = captureService.availableDisplays.first else {
                    handleRecordingError(RecordingError.streamConfigurationFailed)
                    return
                }

                let region = RecordingRegion.display(display)
                let format = createDefaultVideoFormat()

                try await recordingService.startRecording(region: region, format: format)
                showRecordingControls()
            } catch {
                handleRecordingError(error)
            }
        }
    }

    /// Performs recording with a specific region (T024)
    private func performRecording(region: RecordingRegion, format: RecordingFormat?) {
        Task {
            do {
                let recordingFormat = format ?? createDefaultVideoFormat()
                try await recordingService.startRecording(region: region, format: recordingFormat)
                showRecordingControls()
            } catch {
                handleRecordingError(error)
            }
        }
    }

    /// Creates the default video format from settings
    private func createDefaultVideoFormat() -> RecordingFormat {
        let settings = settingsManager.settings

        // Map VideoQuality to VideoConfig.Resolution
        let resolution: VideoConfig.Resolution
        switch settings.videoQuality {
        case .low:     resolution = .r480p
        case .medium:  resolution = .r720p
        case .high:    resolution = .r1080p
        case .maximum: resolution = .r4k
        }

        // Map VideoQuality to VideoConfig.Quality
        let quality: VideoConfig.Quality
        switch settings.videoQuality {
        case .low:     quality = .low
        case .medium:  quality = .medium
        case .high:    quality = .high
        case .maximum: quality = .maximum
        }

        let config = VideoConfig(
            resolution: resolution,
            frameRate: settings.videoFPS,
            quality: quality,
            includeSystemAudio: settings.recordSystemAudio,
            includeMicrophone: settings.recordMicrophone,
            showClicks: settings.showClicks,
            showKeystrokes: settings.showKeystrokes,
            showCursor: settings.includeCursor
        )

        return .video(config)
    }

    /// Creates the default GIF format (T047)
    private func createDefaultGIFFormat() -> RecordingFormat {
        let config = GIFConfig(
            frameRate: 15,
            maxColors: 256,
            loopCount: 0,
            scale: 1.0
        )
        return .gif(config)
    }

    // MARK: - GIF Recording Methods (T047)

    /// Starts GIF recording fullscreen
    func startGIFRecording() {
        guard canPerformCapture() else { return }
        state = .recording
        isGIFRecording = true
        beginFullscreenGIFRecording()
    }

    /// Starts GIF recording for a window
    func startGIFRecordingWindow() {
        guard canPerformCapture() else { return }
        isGIFRecording = true
        beginWindowGIFRecordingSelection()
    }

    /// Starts GIF recording for a selected area
    func startGIFRecordingArea() {
        guard canPerformCapture() else { return }
        state = .selectingArea
        isGIFRecording = true
        isRecordingAreaSelection = true
        beginAreaRecordingSelection()
    }

    /// Begins fullscreen GIF recording on the main display
    private func beginFullscreenGIFRecording() {
        Task {
            do {
                try await captureService.refreshAvailableContent()
                guard let display = captureService.availableDisplays.first else {
                    handleRecordingError(RecordingError.streamConfigurationFailed)
                    return
                }

                let region = RecordingRegion.display(display)
                let format = createDefaultGIFFormat()

                try await recordingService.startRecording(region: region, format: format)
                showRecordingControls()
            } catch {
                handleRecordingError(error)
            }
        }
    }

    /// Begins window selection for GIF recording
    private func beginWindowGIFRecordingSelection() {
        isRecordingWindowSelection = true
        state = .selectingWindow
        Task {
            do {
                try await captureService.refreshAvailableContent()
            } catch {
                handleRecordingError(error)
                isRecordingWindowSelection = false
                isGIFRecording = false
                return
            }

            let windows = captureService.availableWindows

            guard !windows.isEmpty else {
                handleRecordingError(RecordingError.streamConfigurationFailed)
                isRecordingWindowSelection = false
                isGIFRecording = false
                return
            }

            let picker = WindowPickerController()
            windowPickerController = picker

            let selectedWindow = await picker.pickWindow(from: windows)
            windowPickerController = nil
            isRecordingWindowSelection = false

            if let window = selectedWindow {
                state = .recording
                let region = RecordingRegion.window(window)
                let format = createDefaultGIFFormat()
                performRecording(region: region, format: format)
            } else {
                isGIFRecording = false
                state = .idle
            }
        }
    }

    /// Handles a successful recording result (T087)
    private func handleRecordingResult(_ result: RecordingResult) {
        hideRecordingControls()
        isGIFRecording = false

        // Show in Quick Access if enabled
        if settingsManager.settings.showQuickAccess {
            // Generate thumbnail from recording and show in Quick Access
            Task {
                if let thumbnail = await generateThumbnailFromRecording(result),
                   let display = captureService.availableDisplays.first {
                    let captureResult = CaptureResult(
                        id: result.id,
                        image: thumbnail,
                        mode: .display(display), // Recording mode - used for display purposes
                        timestamp: result.timestamp,
                        sourceRect: .zero,
                        scaleFactor: 1.0
                    )
                    quickAccessController.addCapture(captureResult)
                } else {
                    // Fallback to notification if thumbnail generation fails
                    showRecordingNotification(for: result)
                }
            }
        } else {
            showRecordingNotification(for: result)
        }

        state = .idle
    }

    /// Generates a thumbnail from a recording file (T087)
    private func generateThumbnailFromRecording(_ result: RecordingResult) async -> CGImage? {
        let asset = AVAsset(url: result.url)

        // For GIF files, try to load the first frame directly
        if result.url.pathExtension.lowercased() == "gif" {
            return loadGIFFirstFrame(from: result.url)
        }

        // For video files, use AVAssetImageGenerator
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 320, height: 240)

        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            return cgImage
        } catch {
            print("Failed to generate recording thumbnail: \(error)")
            return nil
        }
    }

    /// Loads the first frame from a GIF file
    private func loadGIFFirstFrame(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// Handles a recording error
    private func handleRecordingError(_ error: Error) {
        print("Recording error: \(error)")
        hideRecordingControls()

        if let recordingError = error as? RecordingError {
            switch recordingError {
            case .screenCaptureNotAuthorized:
                permissionManager.openScreenRecordingPreferences()
            case .microphoneNotAuthorized:
                permissionManager.openMicrophonePreferences()
            default:
                showErrorNotification(recordingError.localizedDescription)
            }
        } else {
            showErrorNotification(error.localizedDescription)
        }

        state = .idle
    }

    /// Shows a notification for a completed recording
    private func showRecordingNotification(for result: RecordingResult) {
        guard settingsManager.settings.showNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = "Recording Saved"
        content.body = "Recording saved: \(result.formattedDuration)"
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: result.id.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Recording Controls Window (T037)

    /// Shows the recording controls window
    private func showRecordingControls() {
        let controlsWindow = RecordingControlsWindow(
            recordingService: recordingService,
            onStop: { [weak self] in
                self?.stopRecording()
            },
            onPause: { [weak self] in
                self?.pauseRecording()
            },
            onResume: { [weak self] in
                self?.resumeRecording()
            },
            onCancel: { [weak self] in
                self?.cancelRecording()
            }
        )
        controlsWindow.orderFront(nil)
        recordingControlsWindow = controlsWindow
    }

    /// Hides the recording controls window
    private func hideRecordingControls() {
        recordingControlsWindow?.close()
        recordingControlsWindow = nil
    }
}

// MARK: - SelectionWindowDelegate

extension AppCoordinator: SelectionWindowDelegate {
    func selectionWindow(_ window: SelectionWindow, didSelectRect rect: CGRect) {
        // Dismiss all selection windows
        dismissSelectionWindows()

        // Check if this is for scrolling capture (T027)
        if isScrollingCaptureAreaSelection {
            isScrollingCaptureAreaSelection = false
            state = .capturing

            Task {
                guard let display = captureService.availableDisplays.first else {
                    handleScrollingCaptureError(ScrollingCaptureError.invalidRegion)
                    return
                }

                beginScrollingCapture(region: rect, display: display)
            }
            return
        }

        // Check if this is for OCR capture (T036)
        if isOCRCaptureAreaSelection {
            isOCRCaptureAreaSelection = false
            state = .capturing

            Task {
                do {
                    let result = try await captureService.captureArea(rect)
                    performOCR(on: result.image)
                } catch {
                    handleCaptureError(error)
                }
            }
            return
        }

        // Check if this is for recording or capture (T023, T047)
        if isRecordingAreaSelection {
            isRecordingAreaSelection = false
            state = .recording

            // Get the display for the selection window's screen
            Task {
                guard let display = captureService.availableDisplays.first else {
                    handleRecordingError(RecordingError.streamConfigurationFailed)
                    return
                }

                let region = RecordingRegion.area(rect, display)

                // Use GIF format if in GIF recording mode (T047)
                if isGIFRecording {
                    isGIFRecording = false
                    let format = createDefaultGIFFormat()
                    performRecording(region: region, format: format)
                } else {
                    performRecording(region: region, format: nil)
                }
            }
        } else {
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
    }

    func selectionWindowDidCancel(_ window: SelectionWindow) {
        // Dismiss all selection windows
        dismissSelectionWindows()

        // Reset recording, scrolling capture, and OCR flags if applicable
        isRecordingAreaSelection = false
        isGIFRecording = false
        isScrollingCaptureAreaSelection = false
        isOCRCaptureAreaSelection = false

        // Reset state
        state = .idle
    }
}
