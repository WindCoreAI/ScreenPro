import AppKit
import SwiftUI

// MARK: - QuickAccessWindow

/// Floating overlay window for displaying captured screenshots.
/// Configured as a borderless, floating window that persists across Spaces.
@MainActor
final class QuickAccessWindow: NSWindow {
    // MARK: - Properties

    /// Reference to the controller managing this window.
    weak var controller: QuickAccessWindowController?

    // MARK: - Initialization

    /// Creates a new Quick Access overlay window.
    /// - Parameter controller: The controller managing this window.
    init(controller: QuickAccessWindowController) {
        self.controller = controller

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        configure()
    }

    // MARK: - Configuration

    private func configure() {
        // Window level - float above regular windows but below menus
        level = .floating

        // Transparency and appearance
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // Allow dragging by window background
        isMovableByWindowBackground = true

        // Persist across Spaces (virtual desktops)
        collectionBehavior = [.canJoinAllSpaces, .stationary]

        // Event handling
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true

        // No resize or minimize
        animationBehavior = .none
    }

    // MARK: - NSWindow Overrides

    /// Allow window to become key to receive keyboard events.
    override var canBecomeKey: Bool {
        true
    }

    /// Allow window to become main when appropriate.
    override var canBecomeMain: Bool {
        true
    }

    // MARK: - Keyboard Event Handling

    override func keyDown(with event: NSEvent) {
        // Handle key events for navigation and actions
        switch event.keyCode {
        case 53: // Escape
            controller?.performActionOnSelected(.dismiss)

        case 36: // Return/Enter
            controller?.performActionOnSelected(.annotate)

        case 125: // Down arrow
            controller?.queue.selectNext()

        case 126: // Up arrow
            controller?.queue.selectPrevious()

        default:
            // Check for command key combinations
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers {
                case "c":
                    controller?.performActionOnSelected(.copy)
                case "s":
                    controller?.performActionOnSelected(.save)
                case "a":
                    controller?.performActionOnSelected(.annotate)
                default:
                    super.keyDown(with: event)
                }
            } else {
                super.keyDown(with: event)
            }
        }
    }
}

// MARK: - QuickAccessAction

/// Actions available in the Quick Access overlay.
enum QuickAccessAction {
    /// Copy image to clipboard (Cmd+C).
    case copy

    /// Save image to default location (Cmd+S).
    case save

    /// Open image in annotation editor (Return/Enter or Cmd+A).
    case annotate

    /// Dismiss without saving (Escape or Close button).
    case dismiss
}
