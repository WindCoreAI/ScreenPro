import SwiftUI

// MARK: - Shortcuts Settings Tab (T043 - placeholder for Phase 6)

/// Shortcuts preferences tab displaying configured keyboard shortcuts
struct ShortcutsSettingsTab: View {
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        Form {
            Section("Capture Shortcuts") {
                ShortcutRow(
                    action: .captureArea,
                    shortcut: settingsManager.settings.shortcuts[.captureArea]
                )
                ShortcutRow(
                    action: .captureWindow,
                    shortcut: settingsManager.settings.shortcuts[.captureWindow]
                )
                ShortcutRow(
                    action: .captureFullscreen,
                    shortcut: settingsManager.settings.shortcuts[.captureFullscreen]
                )
                ShortcutRow(
                    action: .captureScrolling,
                    shortcut: settingsManager.settings.shortcuts[.captureScrolling]
                )
            }

            Section("Recording Shortcuts") {
                ShortcutRow(
                    action: .startRecording,
                    shortcut: settingsManager.settings.shortcuts[.startRecording]
                )
                ShortcutRow(
                    action: .recordGIF,
                    shortcut: settingsManager.settings.shortcuts[.recordGIF]
                )
            }

            Section("Other Shortcuts") {
                ShortcutRow(
                    action: .textRecognition,
                    shortcut: settingsManager.settings.shortcuts[.textRecognition]
                )
                ShortcutRow(
                    action: .allInOne,
                    shortcut: settingsManager.settings.shortcuts[.allInOne]
                )
            }

            Section {
                Text("Note: Shortcut editing will be available in a future update.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Shortcut Row Component (T044)

/// Displays a single shortcut with its action name and key combination
struct ShortcutRow: View {
    let action: ShortcutAction
    let shortcut: Shortcut?

    var body: some View {
        HStack {
            Text(action.displayName)
            Spacer()

            if let shortcut = shortcut {
                Text(shortcut.displayString)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            } else {
                Text("Not Set")
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    ShortcutsSettingsTab()
        .environmentObject(SettingsManager())
}
