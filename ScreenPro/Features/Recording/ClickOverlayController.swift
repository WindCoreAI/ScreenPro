import AppKit
import SwiftUI

// MARK: - ClickOverlayController (T067)

/// Controller for the click visualization overlay window
@MainActor
final class ClickOverlayController {
    // MARK: - Properties

    private var overlayWindows: [NSWindow] = []
    private let viewModel: ClickOverlayViewModel
    private var eventMonitor: Any?
    private var isRunning = false

    // MARK: - Initialization

    init() {
        self.viewModel = ClickOverlayViewModel()
    }

    // MARK: - Public Methods

    /// Starts click monitoring and overlay display (T072)
    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Create overlay windows for each screen
        createOverlayWindows()

        // Start global mouse monitoring (T068)
        startMouseMonitoring()
    }

    /// Stops click monitoring and closes overlay windows
    func stop() {
        guard isRunning else { return }
        isRunning = false

        // Stop monitoring
        stopMouseMonitoring()

        // Clear effects and close windows
        viewModel.clearAll()
        closeOverlayWindows()
    }

    // MARK: - Window Management

    private func createOverlayWindows() {
        for screen in NSScreen.screens {
            let window = createOverlayWindow(for: screen)
            overlayWindows.append(window)
        }
    }

    private func createOverlayWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Window configuration
        window.level = .screenSaver // High level to appear over all content
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true // Don't block clicks
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Set content view
        let overlayView = ClickOverlayView(viewModel: viewModel)
        window.contentView = NSHostingView(rootView: overlayView)

        // Position window
        window.setFrame(screen.frame, display: true)
        window.orderFront(nil)

        return window
    }

    private func closeOverlayWindows() {
        for window in overlayWindows {
            window.orderOut(nil)
            window.close()
        }
        overlayWindows.removeAll()
    }

    // MARK: - Mouse Monitoring (T068)

    private func startMouseMonitoring() {
        // Monitor global mouse events
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseEvent(event)
            }
        }
    }

    private func stopMouseMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleMouseEvent(_ event: NSEvent) {
        // Get the screen position of the click
        let screenPosition = NSEvent.mouseLocation

        // Determine click type (T071)
        let clickType: ClickEffect.ClickType
        switch event.type {
        case .leftMouseDown:
            clickType = .left
        case .rightMouseDown:
            clickType = .right
        case .otherMouseDown:
            clickType = .middle
        default:
            return
        }

        // Add the click effect
        viewModel.addClick(at: screenPosition, type: clickType)
    }
}
