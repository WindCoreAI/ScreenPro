import AppKit
import SwiftUI

// MARK: - Window Highlight Window

/// An overlay window that draws a highlight border around the target window.
/// This window is positioned at the target window's frame and ignores mouse events.
@MainActor
final class WindowHighlightWindow: NSWindow {
    // MARK: - Configuration

    private let borderWidth: CGFloat = 3
    private let borderColor = NSColor.systemBlue
    private let fillColor = NSColor.systemBlue.withAlphaComponent(0.1)
    private let cornerRadius: CGFloat = 8

    // MARK: - Initialization

    init() {
        super.init(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        configure()
    }

    // MARK: - Configuration

    private func configure() {
        // Window level just below the picker overlay
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 1)

        // Transparent background
        isOpaque = false
        backgroundColor = .clear

        // Don't receive mouse events
        ignoresMouseEvents = true

        // Behavior settings
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hasShadow = false
        animationBehavior = .none
    }

    // MARK: - Public Methods

    /// Shows the highlight around the specified window frame.
    func show(around frame: CGRect) {
        // Add padding for the border
        let highlightFrame = frame.insetBy(dx: -borderWidth, dy: -borderWidth)

        setFrame(highlightFrame, display: true)

        // Create the highlight view
        let highlightView = WindowHighlightContentView(
            borderWidth: borderWidth,
            borderColor: borderColor,
            fillColor: fillColor,
            cornerRadius: cornerRadius
        )

        let hostingView = NSHostingView(rootView: highlightView)
        hostingView.frame = NSRect(origin: .zero, size: highlightFrame.size)
        contentView = hostingView

        orderFront(nil)
    }

    /// Hides the highlight window.
    func hide() {
        orderOut(nil)
    }
}

// MARK: - Window Highlight Content View

/// SwiftUI view that draws the highlight border and fill.
struct WindowHighlightContentView: View {
    let borderWidth: CGFloat
    let borderColor: NSColor
    let fillColor: NSColor
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(fillColor))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color(borderColor), lineWidth: borderWidth)
                )
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview {
    WindowHighlightContentView(
        borderWidth: 3,
        borderColor: .systemBlue,
        fillColor: .systemBlue.withAlphaComponent(0.1),
        cornerRadius: 8
    )
    .frame(width: 300, height: 200)
}
