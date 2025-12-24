import SwiftUI
import AppKit

// MARK: - CountdownView (T043, T083)

/// Full-screen countdown overlay view with large number display.
/// Supports Reduce Motion accessibility setting (T083).
struct CountdownView: View {
    @ObservedObject var controller: SelfTimerController
    let onCancel: () -> Void

    /// Observes the system's Reduce Motion accessibility setting
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Large countdown number
                Text("\(controller.state.remainingSeconds)")
                    .font(.system(size: 200, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: controller.state.remainingSeconds)
                    .accessibilityLabel("Countdown: \(controller.state.remainingSeconds) seconds remaining")

                // Progress ring - hidden in Reduce Motion mode, replaced with text
                if reduceMotion {
                    Text("\(Int(controller.state.progress * 100))%")
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .accessibilityLabel("Progress: \(Int(controller.state.progress * 100)) percent")
                } else {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 8)
                            .frame(width: 100, height: 100)

                        Circle()
                            .trim(from: 0, to: controller.state.progress)
                            .stroke(
                                Color.white,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1.0), value: controller.state.progress)
                    }
                    .accessibilityHidden(true)
                }

                // Cancel button
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.bordered)
                .tint(.white)
                .controlSize(.large)
                .accessibilityLabel("Cancel countdown")
                .accessibilityHint("Press to cancel the self-timer capture")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Self-timer countdown overlay")
    }
}

// MARK: - CountdownWindow

/// Window for displaying the countdown overlay.
@MainActor
final class CountdownWindow: NSWindow {
    private let controller: SelfTimerController

    init(controller: SelfTimerController, onCancel: @escaping () -> Void) {
        self.controller = controller

        super.init(
            contentRect: NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Set up SwiftUI content
        let contentView = CountdownView(controller: controller, onCancel: onCancel)
        self.contentView = NSHostingView(rootView: contentView)

        // Make window cover all screens
        if let screen = NSScreen.main {
            setFrame(screen.frame, display: true)
        }
    }

    /// Shows the countdown window.
    func show() {
        makeKeyAndOrderFront(nil)
    }

    /// Hides the countdown window.
    func hide() {
        orderOut(nil)
    }
}

#Preview {
    CountdownView(
        controller: {
            let controller = SelfTimerController()
            return controller
        }(),
        onCancel: {}
    )
}
