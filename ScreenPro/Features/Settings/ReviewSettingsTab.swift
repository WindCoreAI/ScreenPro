import SwiftUI
import Speech

// MARK: - ReviewSettingsTab (008-review-recording, US5)

/// Settings for Review Recording: voice notes, transcription language,
/// flag hotkey, and report bundle contents (FR-015).
struct ReviewSettingsTab: View {
    @EnvironmentObject var settingsManager: SettingsManager

    /// Locales offered for transcription, computed once per appearance.
    @State private var availableLocales: [Locale] = []

    var body: some View {
        Form {
            Section {
                Toggle("Create notes from speech while recording", isOn: binding(\.reviewVoiceNotesEnabled))
                    .accessibilityHint("Transcribes your narration on-device and pairs each observation with a screenshot")

                Picker("Transcription language", selection: binding(\.reviewTranscriptionLocale)) {
                    Text("System Language").tag("")
                    ForEach(availableLocales, id: \.identifier) { locale in
                        Text(localeDisplayName(locale)).tag(locale.identifier)
                    }
                }
                .disabled(!settingsManager.settings.reviewVoiceNotesEnabled)

                Text("Transcription runs entirely on this Mac. No audio or text ever leaves your device. Availability depends on the dictation languages installed in System Settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Voice Notes")
            }

            Section {
                LabeledContent("Flag moment shortcut") {
                    Text(flagShortcutDisplay)
                        .font(.system(.body, design: .monospaced))
                }
                Text("Active only during Review Recordings. Change it in the Shortcuts tab.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Flagging")
            }

            Section {
                Toggle("Include the recording video", isOn: binding(\.reviewBundleIncludesVideo))
                Toggle("Include the full narration transcript", isOn: binding(\.reviewBundleIncludesTranscript))
                Toggle("Review issues before generating the report", isOn: binding(\.reviewShowSummaryBeforeExport))
            } header: {
                Text("Review Report")
            } footer: {
                Text("Reports are saved as a folder containing the screenshots, a Markdown report, and a report.json manifest that coding agents can consume directly.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            availableLocales = SFSpeechRecognizer.supportedLocales()
                .sorted { localeDisplayName($0) < localeDisplayName($1) }
        }
    }

    private var flagShortcutDisplay: String {
        let shortcut = settingsManager.settings.shortcuts[.reviewFlag] ?? Shortcut.defaults[.reviewFlag]
        return shortcut?.displayString ?? "—"
    }

    private func localeDisplayName(_ locale: Locale) -> String {
        Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
    }

    private func binding<T>(_ keyPath: WritableKeyPath<Settings, T>) -> Binding<T> {
        Binding(
            get: { settingsManager.settings[keyPath: keyPath] },
            set: { settingsManager.settings[keyPath: keyPath] = $0 }
        )
    }
}

#Preview {
    ReviewSettingsTab()
        .environmentObject(SettingsManager())
}
