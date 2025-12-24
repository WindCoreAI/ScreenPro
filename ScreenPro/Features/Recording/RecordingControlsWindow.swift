import AppKit
import SwiftUI

// MARK: - RecordingControlsWindow (T029)

/// Floating window for recording controls with timer, pause/resume, and stop buttons
final class RecordingControlsWindow: NSWindow {
    // MARK: - Properties

    private let recordingService: RecordingService

    // MARK: - Callbacks

    private let onStop: () -> Void
    private let onPause: () -> Void
    private let onResume: () -> Void
    private let onCancel: () -> Void

    // MARK: - Initialization

    init(
        recordingService: RecordingService,
        onStop: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onResume: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.recordingService = recordingService
        self.onStop = onStop
        self.onPause = onPause
        self.onResume = onResume
        self.onCancel = onCancel

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 48),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        configureWindow()
        setupContent()
        centerOnScreen()
        setupAccessibility()
    }

    // MARK: - Window Configuration (T035)

    private func configureWindow() {
        // Window level - floating above other windows
        level = .floating

        // Appearance
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // Behavior (T035 - draggable)
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false

        // Collection behavior - persist across spaces
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Ensure it can receive mouse events
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
    }

    // MARK: - Content Setup

    private func setupContent() {
        let controlsView = RecordingControlsView(
            recordingService: recordingService,
            onStop: onStop,
            onPause: onPause,
            onResume: onResume,
            onCancel: onCancel
        )

        contentView = NSHostingView(rootView: controlsView)
    }

    // MARK: - Positioning

    /// Centers the window at the top of the main screen
    private func centerOnScreen() {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.maxY - frame.height - 20 // 20px from top

        setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Repositions the window to stay within screen bounds
    func constrainToScreen() {
        guard let screen = NSScreen.main else { return }

        var newFrame = frame
        let screenFrame = screen.visibleFrame

        // Constrain horizontally
        if newFrame.minX < screenFrame.minX {
            newFrame.origin.x = screenFrame.minX
        } else if newFrame.maxX > screenFrame.maxX {
            newFrame.origin.x = screenFrame.maxX - newFrame.width
        }

        // Constrain vertically
        if newFrame.minY < screenFrame.minY {
            newFrame.origin.y = screenFrame.minY
        } else if newFrame.maxY > screenFrame.maxY {
            newFrame.origin.y = screenFrame.maxY - newFrame.height
        }

        if newFrame != frame {
            setFrame(newFrame, display: true)
        }
    }

    // MARK: - Mouse Events (T035)

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    // MARK: - Window Closure Handling (T085)

    /// Handles window closure by stopping the recording to prevent orphaned recordings
    override func close() {
        // If recording is still in progress, stop it gracefully
        if recordingService.state == .recording || recordingService.state == .paused {
            onStop()
        }
        super.close()
    }

    // MARK: - Accessibility (T036)

    private func setupAccessibility() {
        setAccessibilityLabel("Recording Controls")
        setAccessibilityRole(.toolbar)
    }
}
