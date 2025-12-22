import SwiftUI

// MARK: - Capture Settings Tab (T033 - placeholder for Phase 5)

/// Capture preferences tab with save location, naming, and format options
struct CaptureSettingsTab: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showFolderPicker = false

    var body: some View {
        Form {
            Section("Save Location") {
                HStack {
                    Text(settingsManager.settings.defaultSaveLocation.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Choose...") {
                        showFolderPicker = true
                    }
                }

                TextField("File Naming Pattern", text: $settingsManager.settings.fileNamingPattern)
                    .textFieldStyle(.roundedBorder)

                Text("Available placeholders: {date}, {time}")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Format") {
                Picker("Image Format", selection: $settingsManager.settings.defaultImageFormat) {
                    ForEach(ImageFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
            }

            Section("Capture Options") {
                Toggle("Include Cursor", isOn: $settingsManager.settings.includeCursor)
                Toggle("Show Crosshair", isOn: $settingsManager.settings.showCrosshair)
                Toggle("Show Magnifier", isOn: $settingsManager.settings.showMagnifier)
                Toggle("Hide Desktop Icons", isOn: $settingsManager.settings.hideDesktopIcons)
            }
        }
        .formStyle(.grouped)
        .padding()
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    settingsManager.settings.defaultSaveLocation = url
                }
            case .failure(let error):
                print("Failed to select folder: \(error)")
            }
        }
    }
}

#Preview {
    CaptureSettingsTab()
        .environmentObject(SettingsManager())
}
