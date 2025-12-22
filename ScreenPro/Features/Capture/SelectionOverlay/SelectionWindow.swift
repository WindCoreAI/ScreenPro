import AppKit
import SwiftUI

// MARK: - Selection Window Delegate Protocol

/// Protocol for handling selection window events.
@MainActor
protocol SelectionWindowDelegate: AnyObject {
    /// Called when user completes a selection.
    func selectionWindow(_ window: SelectionWindow, didSelectRect rect: CGRect)

    /// Called when user cancels selection (Escape key or click without drag).
    func selectionWindowDidCancel(_ window: SelectionWindow)
}

// MARK: - Selection Window

/// A borderless, fullscreen overlay window for area selection.
/// Sits above all content and captures mouse events for selection.
@MainActor
final class SelectionWindow: NSWindow {
    // MARK: - Properties

    weak var selectionDelegate: SelectionWindowDelegate?

    /// The overlay view controller managing the selection UI.
    private var overlayViewController: NSHostingController<SelectionOverlayView>?

    /// Observable state for the SwiftUI view.
    private let viewModel: SelectionOverlayViewModel

    // MARK: - Initialization

    /// Creates a selection window covering the specified screen.
    init(screen: NSScreen) {
        self.viewModel = SelectionOverlayViewModel(screenFrame: screen.frame)

        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        configure()
        setupOverlayView()
    }

    // MARK: - Configuration

    private func configure() {
        // Window level above all content
        level = .screenSaver

        // Allow transparent background
        isOpaque = false
        backgroundColor = .clear

        // Capture mouse events
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true

        // Behavior for multi-space and fullscreen apps
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // No shadow
        hasShadow = false

        // Prevent from appearing in mission control
        animationBehavior = .none
    }

    private func setupOverlayView() {
        let overlayView = SelectionOverlayView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: overlayView)

        hostingController.view.frame = contentRect(forFrameRect: frame)
        hostingController.view.autoresizingMask = [.width, .height]

        // Set up callbacks
        viewModel.onSelectionComplete = { [weak self] rect in
            guard let self = self else { return }
            self.selectionDelegate?.selectionWindow(self, didSelectRect: rect)
        }

        viewModel.onCancel = { [weak self] in
            guard let self = self else { return }
            self.selectionDelegate?.selectionWindowDidCancel(self)
        }

        contentView = hostingController.view
        overlayViewController = hostingController
    }

    // MARK: - Event Handling

    override func keyDown(with event: NSEvent) {
        // Handle Escape key for cancellation (T023)
        if event.keyCode == 53 { // Escape key
            selectionDelegate?.selectionWindowDidCancel(self)
            return
        }

        super.keyDown(with: event)
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    // MARK: - Public Methods

    /// Shows the selection window and makes it key.
    func showForSelection() {
        makeKeyAndOrderFront(nil)
        makeFirstResponder(contentView)
    }

    /// Dismisses the selection window.
    func dismiss() {
        orderOut(nil)
        close()
    }
}

// MARK: - Selection Overlay View Model

/// Observable state for the selection overlay.
@MainActor
final class SelectionOverlayViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var startPoint: CGPoint?
    @Published var currentPoint: CGPoint?
    @Published var isDragging: Bool = false
    @Published var mousePosition: CGPoint = .zero

    // MARK: - Properties

    let screenFrame: CGRect

    /// Callback when selection is completed.
    var onSelectionComplete: ((CGRect) -> Void)?

    /// Callback when selection is cancelled.
    var onCancel: (() -> Void)?

    // MARK: - Computed Properties

    /// The current selection rectangle, normalized to positive dimensions.
    var selectionRect: CGRect? {
        guard let start = startPoint, let current = currentPoint else {
            return nil
        }

        let minX = min(start.x, current.x)
        let minY = min(start.y, current.y)
        let maxX = max(start.x, current.x)
        let maxY = max(start.y, current.y)

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Dimensions of the current selection.
    var selectionSize: CGSize? {
        selectionRect?.size
    }

    /// Whether the current selection is valid (>= 5x5 pixels).
    var isValidSelection: Bool {
        guard let rect = selectionRect else { return false }
        return rect.width >= 5 && rect.height >= 5
    }

    // MARK: - Initialization

    init(screenFrame: CGRect) {
        self.screenFrame = screenFrame
    }

    // MARK: - Methods

    /// Starts a new selection at the given point.
    func startSelection(at point: CGPoint) {
        startPoint = point
        currentPoint = point
        isDragging = true
    }

    /// Updates the current selection endpoint.
    func updateSelection(to point: CGPoint) {
        currentPoint = point
    }

    /// Completes the current selection.
    func completeSelection() {
        isDragging = false

        guard let rect = selectionRect, isValidSelection else {
            // Selection too small or no selection, cancel
            onCancel?()
            return
        }

        // Convert to screen coordinates for capture
        let screenRect = convertToScreenCoordinates(rect)
        onSelectionComplete?(screenRect)
    }

    /// Cancels the current selection.
    func cancelSelection() {
        startPoint = nil
        currentPoint = nil
        isDragging = false
        onCancel?()
    }

    /// Updates the mouse position for crosshair display.
    func updateMousePosition(_ point: CGPoint) {
        mousePosition = point
    }

    // MARK: - Coordinate Conversion

    /// Converts view coordinates to screen coordinates.
    /// SwiftUI views use top-left origin; screen coordinates use bottom-left.
    private func convertToScreenCoordinates(_ rect: CGRect) -> CGRect {
        // View Y increases downward, screen Y increases upward
        let screenY = screenFrame.height - rect.maxY + screenFrame.origin.y

        return CGRect(
            x: rect.origin.x + screenFrame.origin.x,
            y: screenY,
            width: rect.width,
            height: rect.height
        )
    }
}
