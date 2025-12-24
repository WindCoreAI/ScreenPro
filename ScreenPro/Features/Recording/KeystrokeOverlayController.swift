import AppKit
import SwiftUI
import Carbon.HIToolbox

// MARK: - KeystrokeOverlayController (T076)

/// Controller for the keystroke visualization overlay window
@MainActor
final class KeystrokeOverlayController {
    // MARK: - Properties

    private var overlayWindow: NSWindow?
    private let viewModel: KeystrokeOverlayViewModel
    private var eventMonitor: Any?
    private var isRunning = false

    // MARK: - Initialization

    init() {
        self.viewModel = KeystrokeOverlayViewModel()
    }

    // MARK: - Public Methods

    /// Starts keystroke monitoring and overlay display (T081)
    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Create overlay window on main screen
        createOverlayWindow()

        // Start global keyboard monitoring (T077)
        startKeyboardMonitoring()
    }

    /// Stops keystroke monitoring and closes overlay window
    func stop() {
        guard isRunning else { return }
        isRunning = false

        // Stop monitoring
        stopKeyboardMonitoring()

        // Clear and close
        viewModel.clearAll()
        closeOverlayWindow()
    }

    // MARK: - Window Management

    private func createOverlayWindow() {
        guard let screen = NSScreen.main else { return }

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Window configuration
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Set content view
        let overlayView = KeystrokeOverlayView(viewModel: viewModel)
        window.contentView = NSHostingView(rootView: overlayView)

        // Position and show
        window.setFrame(screen.frame, display: true)
        window.orderFront(nil)

        overlayWindow = window
    }

    private func closeOverlayWindow() {
        overlayWindow?.orderOut(nil)
        overlayWindow?.close()
        overlayWindow = nil
    }

    // MARK: - Keyboard Monitoring (T077)

    private func startKeyboardMonitoring() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyEvent(event)
            }
        }
    }

    private func stopKeyboardMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // Get the key character
        guard let characters = event.charactersIgnoringModifiers,
              !characters.isEmpty else { return }

        // Build modifier set
        var modifiers: Set<KeyPress.Modifier> = []

        if event.modifierFlags.contains(.command) {
            modifiers.insert(.command)
        }
        if event.modifierFlags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if event.modifierFlags.contains(.option) {
            modifiers.insert(.option)
        }
        if event.modifierFlags.contains(.control) {
            modifiers.insert(.control)
        }

        // For regular keys without modifiers, skip (too noisy)
        // Only show keys with modifiers OR special keys
        let isSpecialKey = event.keyCode == kVK_Return ||
                          event.keyCode == kVK_Tab ||
                          event.keyCode == kVK_Escape ||
                          event.keyCode == kVK_Delete ||
                          event.keyCode == kVK_Space ||
                          event.keyCode == kVK_UpArrow ||
                          event.keyCode == kVK_DownArrow ||
                          event.keyCode == kVK_LeftArrow ||
                          event.keyCode == kVK_RightArrow

        guard !modifiers.isEmpty || isSpecialKey else { return }

        // Create key press
        let keyPress = KeyPress(key: characters.uppercased(), modifiers: modifiers)
        viewModel.addKeyPress(keyPress)
    }
}
