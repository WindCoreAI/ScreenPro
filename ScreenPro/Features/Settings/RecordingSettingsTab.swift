import SwiftUI

// MARK: - Recording Settings Tab (T034, T059-T064)

/// Recording preferences tab with video format, quality, resolution, and audio options
struct RecordingSettingsTab: View {
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        Form {
            // Video Settings Section (T059-T062)
            Section {
                Picker("Format", selection: $settingsManager.settings.defaultVideoFormat) {
                    ForEach(VideoFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .accessibilityLabel("Video Format")
                .accessibilityHint("Select the output video format")

                // Quality Picker (T061)
                Picker("Quality", selection: $settingsManager.settings.videoQuality) {
                    ForEach(VideoQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .accessibilityLabel("Video Quality")
                .accessibilityHint("Select the recording quality level")

                // Frame Rate Picker (T062)
                Picker("Frame Rate", selection: $settingsManager.settings.videoFPS) {
                    ForEach(VideoConfig.validFrameRates, id: \.self) { fps in
                        Text("\(fps) FPS").tag(fps)
                    }
                }
                .accessibilityLabel("Frame Rate")
                .accessibilityHint("Select frames per second for recording")

            } header: {
                Text("Video")
            } footer: {
                Text("Higher quality and frame rate result in larger file sizes.")
            }

            // Audio Settings Section (T058)
            Section {
                Toggle("Record System Audio", isOn: $settingsManager.settings.recordSystemAudio)
                    .accessibilityLabel("Record System Audio")
                    .accessibilityHint("Include sounds playing on your computer in the recording")

                Toggle("Record Microphone", isOn: $settingsManager.settings.recordMicrophone)
                    .accessibilityLabel("Record Microphone")
                    .accessibilityHint("Include microphone audio in the recording")
            } header: {
                Text("Audio")
            } footer: {
                if settingsManager.settings.recordMicrophone {
                    Text("Microphone access requires permission in System Settings > Privacy & Security.")
                }
            }

            // Overlay Settings Section (T083)
            Section("Overlays") {
                Toggle("Show Cursor", isOn: $settingsManager.settings.includeCursor)
                    .accessibilityLabel("Show Cursor")
                    .accessibilityHint("Show or hide the mouse cursor in recordings")

                Toggle("Show Mouse Clicks", isOn: $settingsManager.settings.showClicks)
                    .accessibilityLabel("Show Mouse Clicks")
                    .accessibilityHint("Display visual indicators when you click during recording")

                Toggle("Show Keystrokes", isOn: $settingsManager.settings.showKeystrokes)
                    .accessibilityLabel("Show Keystrokes")
                    .accessibilityHint("Display keyboard input during recording")
            }

            // GIF Settings Section
            Section {
                gifFrameRatePicker
                gifQualityInfo
            } header: {
                Text("GIF Recording")
            } footer: {
                Text("GIF recordings use 15 FPS by default for optimal file size.")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - GIF Settings Views

    private var gifFrameRatePicker: some View {
        HStack {
            Text("GIF Frame Rate")
            Spacer()
            Text("15 FPS")
                .foregroundColor(.secondary)
        }
        .accessibilityLabel("GIF Frame Rate: 15 FPS")
    }

    private var gifQualityInfo: some View {
        HStack {
            Text("Color Palette")
            Spacer()
            Text("256 colors")
                .foregroundColor(.secondary)
        }
        .accessibilityLabel("GIF Color Palette: 256 colors")
    }
}

#Preview {
    RecordingSettingsTab()
        .environmentObject(SettingsManager())
}
