import AppKit
import SwiftUI

// MARK: - OnboardingWindowController (007-cloud-polish)

/// Centered window hosting the first-run onboarding flow.
@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let onComplete: () -> Void

    init(permissionManager: PermissionManager, onComplete: @escaping () -> Void) {
        self.onComplete = onComplete

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to ScreenPro"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: OnboardingView(
                permissionManager: permissionManager,
                onComplete: onComplete
            )
        )
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Brings the onboarding window to the front, activating the app.
    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - NSWindowDelegate

    /// Closing the window counts as completing onboarding so it isn't shown again.
    func windowWillClose(_ notification: Notification) {
        onComplete()
    }
}
