import AppKit
import ScreenCaptureKit

// MARK: - Window Picker Overlay Delegate

/// Delegate protocol for window picker events.
@MainActor
protocol WindowPickerOverlayDelegate: AnyObject {
    /// Called when user clicks to select a window.
    func windowPickerOverlay(_ overlay: WindowPickerOverlay, didSelectWindow window: SCWindow)

    /// Called when user cancels window selection (Escape key).
    func windowPickerOverlayDidCancel(_ overlay: WindowPickerOverlay)

    /// Called when mouse moves to find the window under cursor.
    func windowPickerOverlay(_ overlay: WindowPickerOverlay, windowAt point: CGPoint) -> SCWindow?
}

// MARK: - Window Picker Overlay

/// A nearly-transparent overlay window that captures mouse events for window selection.
/// Covers the entire screen and tracks mouse movement to determine which window is under the cursor.
@MainActor
final class WindowPickerOverlay: NSWindow {
    // MARK: - Properties

    weak var pickerDelegate: WindowPickerOverlayDelegate?

    /// The currently hovered window.
    private(set) var hoveredWindow: SCWindow?

    /// Tracking area for mouse movement.
    private var trackingArea: NSTrackingArea?

    // MARK: - Initialization

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        configure()
        setupContentView()
    }

    // MARK: - Configuration

    private func configure() {
        // Window level above everything
        level = .screenSaver

        // Nearly transparent to see through but capture events
        isOpaque = false
        backgroundColor = NSColor.black.withAlphaComponent(0.01)

        // Capture mouse events
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true

        // Behavior settings
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hasShadow = false
        animationBehavior = .none
    }

    private func setupContentView() {
        let view = WindowPickerContentView()
        view.frame = contentRect(forFrameRect: frame)
        view.autoresizingMask = [.width, .height]
        contentView = view

        // Set up tracking for the entire view
        setupTracking(in: view)
    }

    private func setupTracking(in view: NSView) {
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeAlways,
            .inVisibleRect
        ]

        trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: options,
            owner: self,
            userInfo: nil
        )

        view.addTrackingArea(trackingArea!)
    }

    // MARK: - Event Handling

    override func mouseMoved(with event: NSEvent) {
        let screenPoint = NSEvent.mouseLocation
        updateHoveredWindow(at: screenPoint)
    }

    override func mouseDown(with event: NSEvent) {
        // Select the currently hovered window
        if let window = hoveredWindow {
            pickerDelegate?.windowPickerOverlay(self, didSelectWindow: window)
        }
    }

    override func keyDown(with event: NSEvent) {
        // Handle Escape key (T036)
        if event.keyCode == 53 { // Escape
            pickerDelegate?.windowPickerOverlayDidCancel(self)
            return
        }

        super.keyDown(with: event)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // MARK: - Window Detection

    private func updateHoveredWindow(at point: CGPoint) {
        let newWindow = pickerDelegate?.windowPickerOverlay(self, windowAt: point)

        if newWindow !== hoveredWindow {
            hoveredWindow = newWindow
        }
    }

    // MARK: - Public Methods

    /// Shows the overlay and makes it key.
    func showForPicking() {
        makeKeyAndOrderFront(nil)
        makeFirstResponder(contentView)

        // Set initial cursor
        NSCursor.pointingHand.set()
    }

    /// Dismisses the overlay.
    func dismiss() {
        NSCursor.arrow.set()
        orderOut(nil)
        close()
    }
}

// MARK: - Window Picker Content View

/// A simple NSView subclass for the picker overlay content.
private class WindowPickerContentView: NSView {
    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // Nearly transparent background
        NSColor.black.withAlphaComponent(0.01).setFill()
        dirtyRect.fill()
    }
}
