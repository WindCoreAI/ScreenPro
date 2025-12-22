import AppKit
import ScreenCaptureKit

// MARK: - Window Picker Controller

/// Manages the window picking process, including overlay display, window detection,
/// and highlight updates.
@MainActor
final class WindowPickerController: NSObject {
    // MARK: - Properties

    /// Available windows for selection.
    private var availableWindows: [SCWindow] = []

    /// Overlay windows (one per screen).
    private var overlayWindows: [WindowPickerOverlay] = []

    /// Highlight window for showing selection.
    private var highlightWindow: WindowHighlightWindow?

    /// Continuation for async/await pattern.
    private var continuation: CheckedContinuation<SCWindow?, Never>?

    /// Currently highlighted window.
    private var currentHighlightedWindow: SCWindow?

    // MARK: - Public Methods

    /// Starts window picking and returns the selected window.
    /// Returns nil if user cancels.
    func pickWindow(from windows: [SCWindow]) async -> SCWindow? {
        self.availableWindows = windows

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            showPickerOverlays()
        }
    }

    // MARK: - Private Methods

    private func showPickerOverlays() {
        // Create highlight window
        highlightWindow = WindowHighlightWindow()

        // Create overlay for each screen
        for screen in NSScreen.screens {
            let overlay = WindowPickerOverlay(screen: screen)
            overlay.pickerDelegate = self
            overlay.showForPicking()
            overlayWindows.append(overlay)
        }
    }

    private func dismissAll() {
        // Dismiss overlays
        for overlay in overlayWindows {
            overlay.dismiss()
        }
        overlayWindows.removeAll()

        // Hide highlight
        highlightWindow?.hide()
        highlightWindow = nil

        // Clear state
        currentHighlightedWindow = nil
        availableWindows = []
    }

    private func completeSelection(with window: SCWindow?) {
        dismissAll()
        continuation?.resume(returning: window)
        continuation = nil
    }

    // MARK: - Window Detection

    /// Finds the topmost window at the given screen point.
    private func findWindow(at point: CGPoint) -> SCWindow? {
        // Sort windows by layer (on-screen order) - higher layer = more on top
        // We need to find windows that contain the point
        var matchingWindows: [(window: SCWindow, layer: Int)] = []

        for window in availableWindows {
            let frame = window.frame

            // Check if point is within window frame
            // Note: Screen coordinates have origin at bottom-left
            if frame.contains(point) {
                matchingWindows.append((window, window.windowLayer))
            }
        }

        // Return the window with highest layer (topmost)
        return matchingWindows.max(by: { $0.layer < $1.layer })?.window
    }

    /// Updates the highlight to show around the specified window.
    private func updateHighlight(for window: SCWindow?) {
        guard window !== currentHighlightedWindow else { return }

        currentHighlightedWindow = window

        if let window = window {
            highlightWindow?.show(around: window.frame)
        } else {
            highlightWindow?.hide()
        }
    }
}

// MARK: - WindowPickerOverlayDelegate

extension WindowPickerController: WindowPickerOverlayDelegate {
    func windowPickerOverlay(_ overlay: WindowPickerOverlay, didSelectWindow window: SCWindow) {
        completeSelection(with: window)
    }

    func windowPickerOverlayDidCancel(_ overlay: WindowPickerOverlay) {
        completeSelection(with: nil)
    }

    func windowPickerOverlay(_ overlay: WindowPickerOverlay, windowAt point: CGPoint) -> SCWindow? {
        let window = findWindow(at: point)
        updateHighlight(for: window)
        return window
    }
}
