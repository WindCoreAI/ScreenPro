import AppKit
import SwiftUI

// MARK: - ReviewNotePanel (008-review-recording, FR-004)
//
// Transient quick-note field shown right after a flag. Non-blocking by
// design: ignoring it costs nothing — it auto-dismisses and the flag is
// kept. Return commits, Escape dismisses. Non-activating so the product
// under review keeps focus until the reviewer actually clicks/types.

final class ReviewNotePanel: NSPanel {
    private static let autoDismissDelay: TimeInterval = 6.0

    private var dismissTimer: Timer?
    private let onCommit: (String) -> Void

    init(issue: ReviewIssue, anchor: NSRect?, onCommit: @escaping (String) -> Void) {
        self.onCommit = onCommit

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = ReviewNoteFieldView(
            timecode: issue.timecode,
            onCommit: { [weak self] text in
                self?.commit(text)
            },
            onCancel: { [weak self] in
                self?.dismiss()
            },
            onTyping: { [weak self] in
                self?.restartDismissTimer()
            }
        )
        contentView = NSHostingView(rootView: view)

        position(near: anchor)
    }

    override var canBecomeKey: Bool { true }

    func show() {
        makeKeyAndOrderFront(nil)
        restartDismissTimer()
    }

    private func position(near anchor: NSRect?) {
        guard let screen = NSScreen.main else { return }
        let size = frame.size
        if let anchor {
            // Just below the recording controls.
            setFrameOrigin(NSPoint(
                x: anchor.midX - size.width / 2,
                y: anchor.minY - size.height - 8
            ))
        } else {
            setFrameOrigin(NSPoint(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.maxY - size.height - 60
            ))
        }
    }

    private func restartDismissTimer() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: Self.autoDismissDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss()
            }
        }
    }

    private func commit(_ text: String) {
        onCommit(text)
        dismiss()
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        orderOut(nil)
        close()
    }
}

// MARK: - Field View

private struct ReviewNoteFieldView: View {
    let timecode: String
    let onCommit: (String) -> Void
    let onCancel: () -> Void
    let onTyping: () -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flag.fill")
                .font(.system(size: 11))
                .foregroundColor(.orange)
                .accessibilityHidden(true)

            Text(timecode)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))

            TextField("Add a note… (optional)", text: $text)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .focused($isFocused)
                .onChange(of: text) { _, _ in onTyping() }
                .onSubmit {
                    onCommit(text)
                }
                .onExitCommand {
                    onCancel()
                }
                .accessibilityLabel("Note for flagged moment at \(timecode)")
                .accessibilityHint("Type an optional note and press Return, or ignore to keep the flag without a note")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .onAppear {
            isFocused = true
        }
    }
}
