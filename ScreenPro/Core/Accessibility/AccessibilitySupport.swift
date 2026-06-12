import SwiftUI
import AppKit

// MARK: - Accessibility Support (007-cloud-polish)

// MARK: - Accessibility Labels

extension View {
    /// Applies a standard label/hint/trait combination for capture action buttons.
    func captureAccessibility(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - VoiceOver Announcements

/// Posts VoiceOver announcements for app events that have no visible focus change
/// (capture completed, recording started/stopped, upload finished).
@MainActor
final class AccessibilityAnnouncer {
    static let shared = AccessibilityAnnouncer()

    private init() {}

    func announce(_ message: String, priority: NSAccessibilityPriorityLevel = .medium) {
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: priority.rawValue
            ]
        )
    }

    func announceCaptureComplete(type: String) {
        announce("\(type) captured successfully")
    }

    func announceRecordingStarted() {
        announce("Recording started")
    }

    func announceRecordingStopped(duration: TimeInterval) {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        announce("Recording stopped. Duration: \(minutes) minutes \(seconds) seconds")
    }

    func announceUploadComplete() {
        announce("Upload complete. Shareable link copied to clipboard", priority: .high)
    }
}

// MARK: - Keyboard Navigation

/// Adds Escape/Return handling to any view for keyboard-driven workflows.
struct KeyboardNavigable: ViewModifier {
    let onEscape: (() -> Void)?
    let onEnter: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .onKeyPress(.escape) {
                guard let onEscape else { return .ignored }
                onEscape()
                return .handled
            }
            .onKeyPress(.return) {
                guard let onEnter else { return .ignored }
                onEnter()
                return .handled
            }
    }
}

extension View {
    func keyboardNavigable(
        onEscape: (() -> Void)? = nil,
        onEnter: (() -> Void)? = nil
    ) -> some View {
        modifier(KeyboardNavigable(onEscape: onEscape, onEnter: onEnter))
    }
}

// MARK: - Reduce Motion Support

extension View {
    /// Disables implicit animations when the user has Reduce Motion enabled.
    func respectsReduceMotion() -> some View {
        self.transaction { transaction in
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                transaction.animation = nil
            }
        }
    }
}
