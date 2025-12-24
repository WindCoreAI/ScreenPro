import SwiftUI
import AppKit

// MARK: - MagnifierView (T055, T056, T082)

/// A magnified view showing pixels around the cursor with coordinate display.
/// Includes VoiceOver accessibility labels (T082).
struct MagnifierView: View {
    let state: MagnifierState
    let displayImage: NSImage?

    var body: some View {
        VStack(spacing: 4) {
            // Magnified content
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)

                // Magnified image
                if let image = displayImage {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.none) // Pixelated for pixel-perfect view
                        .aspectRatio(contentMode: .fill)
                        .frame(width: state.viewSize.width, height: state.viewSize.height)
                        .clipped()
                }

                // Grid overlay for pixel visibility
                MagnifierGridOverlay(state: state)
                    .accessibilityHidden(true)

                // Crosshair
                MagnifierCrosshairView()
                    .accessibilityHidden(true)
            }
            .frame(width: state.viewSize.width, height: state.viewSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.8), lineWidth: 2)
            )
            .accessibilityLabel("Magnified pixel view at \(Int(state.magnification))x zoom")

            // Coordinate display
            HStack(spacing: 8) {
                Text("X: \(Int(state.cursorPosition.x))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                Text("Y: \(Int(state.cursorPosition.y))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.7))
            .cornerRadius(4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Cursor position: X \(Int(state.cursorPosition.x)), Y \(Int(state.cursorPosition.y))")
        }
        .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Magnifier tool showing \(Int(state.magnification))x zoom")
    }
}

// MARK: - MagnifierGridOverlay

/// Grid overlay for the magnifier to show pixel boundaries.
struct MagnifierGridOverlay: View {
    let state: MagnifierState

    var body: some View {
        GeometryReader { geometry in
            let pixelSize = state.magnification
            let gridColor = Color.white.opacity(0.2)

            Path { path in
                // Vertical lines
                var x: CGFloat = 0
                while x <= geometry.size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    x += pixelSize
                }

                // Horizontal lines
                var y: CGFloat = 0
                while y <= geometry.size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    y += pixelSize
                }
            }
            .stroke(gridColor, lineWidth: 0.5)
        }
    }
}

// MARK: - MagnifierCrosshairView

/// Crosshair overlay for the magnifier center.
struct MagnifierCrosshairView: View {
    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2

            Path { path in
                // Horizontal line
                path.move(to: CGPoint(x: 0, y: centerY))
                path.addLine(to: CGPoint(x: geometry.size.width, y: centerY))

                // Vertical line
                path.move(to: CGPoint(x: centerX, y: 0))
                path.addLine(to: CGPoint(x: centerX, y: geometry.size.height))
            }
            .stroke(Color.red.opacity(0.8), lineWidth: 1)

            // Center dot
            Circle()
                .fill(Color.red)
                .frame(width: 4, height: 4)
                .position(x: centerX, y: centerY)
        }
    }
}

// MARK: - MagnifierController

/// Controller for managing the magnifier window.
@MainActor
final class MagnifierController: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var state: MagnifierState = .hidden

    // MARK: - Properties

    /// The magnifier window.
    private var window: NSWindow?

    /// Mouse tracking event monitor.
    private var trackingMonitor: Any?

    /// Current display image for magnification.
    private var displayImage: NSImage?

    /// Whether magnifier is enabled in settings.
    var isEnabled: Bool = true

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Shows the magnifier.
    func show() {
        guard isEnabled else { return }

        if window == nil {
            createWindow()
        }

        startTracking()
        window?.orderFront(nil)
        state = .visible(at: NSEvent.mouseLocation)
    }

    /// Hides the magnifier.
    func hide() {
        stopTracking()
        window?.orderOut(nil)
        state = .hidden
    }

    /// Updates the display image for magnification.
    func updateDisplayImage(_ image: NSImage) {
        displayImage = image
        updateContent()
    }

    // MARK: - Private Methods

    private func createWindow() {
        let contentRect = NSRect(
            x: 0,
            y: 0,
            width: state.viewSize.width + 20,
            height: state.viewSize.height + 40
        )

        let newWindow = NSWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        newWindow.level = .floating
        newWindow.isOpaque = false
        newWindow.backgroundColor = .clear
        newWindow.hasShadow = false
        newWindow.ignoresMouseEvents = true
        newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        window = newWindow
        updateContent()
    }

    private func updateContent() {
        let contentView = MagnifierView(
            state: state,
            displayImage: displayImage
        )
        window?.contentView = NSHostingView(rootView: contentView)
    }

    private func startTracking() {
        stopTracking()

        trackingMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.updatePosition()
            }
            return event
        }
    }

    private func stopTracking() {
        if let monitor = trackingMonitor {
            NSEvent.removeMonitor(monitor)
            trackingMonitor = nil
        }
    }

    private func updatePosition() {
        let mouseLocation = NSEvent.mouseLocation

        // Update state
        state = MagnifierState(
            isVisible: true,
            cursorPosition: mouseLocation,
            magnification: state.magnification,
            viewSize: state.viewSize
        )

        // Get screen bounds
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) else {
            return
        }

        // Calculate ideal position
        let idealPosition = state.idealPosition(in: screen.frame)

        // Update window position
        window?.setFrameOrigin(idealPosition)

        // Update content
        updateContent()
    }
}

#Preview {
    MagnifierView(
        state: MagnifierState.visible(at: CGPoint(x: 500, y: 500)),
        displayImage: nil
    )
}
