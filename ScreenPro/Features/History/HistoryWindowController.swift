import AppKit
import SwiftUI

// MARK: - HistoryWindowController (007-cloud-polish)

/// Standard titled window hosting the capture history browser.
@MainActor
final class HistoryWindowController: NSWindowController, NSWindowDelegate {
    private let store: CaptureHistoryStore

    init(store: CaptureHistoryStore) {
        self.store = store

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Capture History"
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("ScreenProHistoryWindow")
        window.contentView = NSHostingView(rootView: HistoryView(store: store))
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Brings the history window to the front, activating the app if needed.
    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
