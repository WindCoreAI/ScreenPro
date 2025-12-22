import SwiftUI

// MARK: - Recording Settings Tab (T034 - placeholder for Phase 5)

/// Recording preferences tab with video format, quality, and audio options
struct RecordingSettingsTab: View {
    @EnvironmentObject var settingsManager: SettingsManager

    private let fpsOptions = [24, 30, 60]

    var body: some View {
        Form {
            Section("Video") {
                Picker("Format", selection: $settingsManager.settings.defaultVideoFormat) {
                    ForEach(VideoFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }

                Picker("Quality", selection: $settingsManager.settings.videoQuality) {
                    ForEach(VideoQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }

                Picker("Frame Rate", selection: $settingsManager.settings.videoFPS) {
                    ForEach(fpsOptions, id: \.self) { fps in
                        Text("\(fps) FPS").tag(fps)
                    }
                }
            }

            Section("Audio") {
                Toggle("Record Microphone", isOn: $settingsManager.settings.recordMicrophone)
                Toggle("Record System Audio", isOn: $settingsManager.settings.recordSystemAudio)
            }

            Section("Overlays") {
                Toggle("Show Mouse Clicks", isOn: $settingsManager.settings.showClicks)
                Toggle("Show Keystrokes", isOn: $settingsManager.settings.showKeystrokes)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    RecordingSettingsTab()
        .environmentObject(SettingsManager())
}
