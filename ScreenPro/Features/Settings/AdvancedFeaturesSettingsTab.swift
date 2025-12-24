import SwiftUI

// MARK: - Advanced Features Settings Tab (T017)

/// Settings tab for configuring advanced capture features
struct AdvancedFeaturesSettingsTab: View {
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        Form {
            // MARK: - Scrolling Capture Section
            Section {
                Stepper(
                    "Maximum Frames: \(settingsManager.settings.scrollingCaptureMaxFrames)",
                    value: $settingsManager.settings.scrollingCaptureMaxFrames,
                    in: 5...100,
                    step: 5
                )
                .help("Maximum number of frames to capture during scrolling capture (5-100)")

                HStack {
                    Text("Overlap Ratio:")
                    Slider(
                        value: $settingsManager.settings.scrollingCaptureOverlapRatio,
                        in: 0.1...0.5,
                        step: 0.05
                    )
                    Text(String(format: "%.0f%%", settingsManager.settings.scrollingCaptureOverlapRatio * 100))
                        .frame(width: 40)
                }
                .help("Expected overlap between frames for accurate stitching")
            } header: {
                Label("Scrolling Capture", systemImage: "scroll")
            }

            // MARK: - OCR Section
            Section {
                Toggle(
                    "Copy text to clipboard automatically",
                    isOn: $settingsManager.settings.ocrCopyToClipboardAutomatically
                )
                .help("Automatically copy recognized text to clipboard after OCR capture")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Recognition Languages:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(settingsManager.settings.ocrLanguages.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } header: {
                Label("Text Recognition (OCR)", systemImage: "text.viewfinder")
            }

            // MARK: - Self-Timer Section
            Section {
                Picker("Default Duration:", selection: $settingsManager.settings.selfTimerDefaultDuration) {
                    Text("3 seconds").tag(3)
                    Text("5 seconds").tag(5)
                    Text("10 seconds").tag(10)
                }
                .pickerStyle(.segmented)
                .help("Default countdown duration for self-timer captures")
            } header: {
                Label("Self-Timer", systemImage: "timer")
            }

            // MARK: - Magnifier Section
            Section {
                Toggle(
                    "Show magnifier during selection",
                    isOn: $settingsManager.settings.magnifierEnabled
                )
                .help("Display a magnified view near the cursor for pixel-precise selection")

                if settingsManager.settings.magnifierEnabled {
                    Stepper(
                        "Zoom Level: \(settingsManager.settings.magnifierZoomLevel)x",
                        value: $settingsManager.settings.magnifierZoomLevel,
                        in: 2...16,
                        step: 2
                    )
                    .help("Magnification level (2x-16x)")
                }
            } header: {
                Label("Magnifier", systemImage: "magnifyingglass")
            }

            // MARK: - Background Tool Section
            Section {
                Picker("Default Style:", selection: $settingsManager.settings.defaultBackgroundStyle) {
                    ForEach(BackgroundStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .help("Default background style for the background tool")

                HStack {
                    Text("Default Padding:")
                    Slider(
                        value: $settingsManager.settings.defaultBackgroundPadding,
                        in: 0...200,
                        step: 10
                    )
                    Text("\(Int(settingsManager.settings.defaultBackgroundPadding))pt")
                        .frame(width: 45)
                }
                .help("Default padding around the image in the background tool")
            } header: {
                Label("Background Tool", systemImage: "photo.artframe")
            }

            // MARK: - Camera Overlay Section
            Section {
                Toggle(
                    "Enable camera overlay for recordings",
                    isOn: $settingsManager.settings.cameraOverlayEnabled
                )
                .help("Show webcam picture-in-picture overlay during screen recordings")

                if settingsManager.settings.cameraOverlayEnabled {
                    Picker("Position:", selection: $settingsManager.settings.cameraOverlayPosition) {
                        ForEach(OverlayPosition.allCases.filter { $0 != .custom }, id: \.self) { position in
                            Text(position.displayName).tag(position)
                        }
                    }
                    .help("Corner position for the camera overlay")

                    Picker("Shape:", selection: $settingsManager.settings.cameraOverlayShape) {
                        ForEach(OverlayShape.allCases, id: \.self) { shape in
                            Text(shape.displayName).tag(shape)
                        }
                    }
                    .help("Shape of the camera overlay")

                    HStack {
                        Text("Size:")
                        Slider(
                            value: $settingsManager.settings.cameraOverlaySize,
                            in: 50...400,
                            step: 10
                        )
                        Text("\(Int(settingsManager.settings.cameraOverlaySize))pt")
                            .frame(width: 45)
                    }
                    .help("Size of the camera overlay (50-400 points)")
                }
            } header: {
                Label("Camera Overlay", systemImage: "camera.badge.ellipsis")
            }
        }
        .formStyle(.grouped)
        .onChange(of: settingsManager.settings) { _, _ in
            settingsManager.save()
        }
    }
}

#Preview {
    AdvancedFeaturesSettingsTab()
        .environmentObject(SettingsManager())
        .frame(width: 500, height: 600)
}
