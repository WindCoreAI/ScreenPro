import AppKit
import SwiftUI

// MARK: - ReviewSummaryWindowController (008-review-recording, US4)
//
// Presents the skippable summary between session finish() preparation and
// bundle generation. Window close behaves like Skip: the report is
// generated with the issues as captured (FR-012).

@MainActor
final class ReviewSummaryWindowController: NSWindowController, NSWindowDelegate {
    private var onComplete: (() -> Void)?
    private var completed = false

    init(session: ReviewSessionService, onComplete: @escaping () -> Void) {
        self.onComplete = onComplete

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 460),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Review Summary"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        window.delegate = self
        window.contentView = NSHostingView(rootView: ReviewSummaryView(
            session: session,
            onGenerate: { [weak self] in self?.finish() },
            onSkip: { [weak self] in self?.finish() }
        ))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        guard !completed else { return }
        completed = true
        let completion = onComplete
        onComplete = nil
        close()
        completion?()
    }

    func windowWillClose(_ notification: Notification) {
        // Closing without choosing = Skip (FR-012 scenario 3).
        guard !completed else { return }
        completed = true
        let completion = onComplete
        onComplete = nil
        completion?()
    }
}
