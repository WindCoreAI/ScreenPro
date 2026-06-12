import SwiftUI

// MARK: - Cloud & History Settings Tab (007-cloud-polish)

/// Preferences for cloud uploads, shareable links, and capture history.
struct CloudSettingsTab: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        Form {
            Section("Cloud Upload") {
                Toggle("Enable Cloud Uploads", isOn: $settingsManager.settings.cloudUploadEnabled)
                    .accessibilityHint("Adds an Upload action to captures and the Quick Access overlay")

                TextField("Server URL", text: $settingsManager.settings.cloudServerURL)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!settingsManager.settings.cloudUploadEnabled)
                    .accessibilityLabel("Cloud server URL")

                SecureField("API Key (optional)", text: $settingsManager.settings.cloudAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!settingsManager.settings.cloudUploadEnabled)
                    .accessibilityLabel("Cloud API key")

                if settingsManager.settings.cloudUploadEnabled && !isServerURLValid {
                    Label("Enter a valid https:// server URL", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Section("Shareable Links") {
                Picker("Links Expire After", selection: $settingsManager.settings.cloudDefaultExpiry) {
                    ForEach(LinkExpiry.allCases, id: \.self) { expiry in
                        Text(expiry.displayName).tag(expiry)
                    }
                }
                .disabled(!settingsManager.settings.cloudUploadEnabled)

                Toggle("Copy Link After Upload", isOn: $settingsManager.settings.copyLinkAfterUpload)
                    .disabled(!settingsManager.settings.cloudUploadEnabled)
            }

            Section("Capture History") {
                Toggle("Keep Capture History", isOn: $settingsManager.settings.captureHistoryEnabled)

                Picker("Retain History For", selection: $settingsManager.settings.historyRetentionDays) {
                    Text("7 Days").tag(7)
                    Text("14 Days").tag(14)
                    Text("30 Days").tag(30)
                    Text("90 Days").tag(90)
                    Text("Forever").tag(0)
                }
                .disabled(!settingsManager.settings.captureHistoryEnabled)

                Button("Open History...") {
                    coordinator.showHistory()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var isServerURLValid: Bool {
        guard let url = URL(string: settingsManager.settings.cloudServerURL),
              let scheme = url.scheme?.lowercased() else {
            return false
        }
        return (scheme == "https" || scheme == "http") && url.host != nil
    }
}

#Preview {
    CloudSettingsTab()
        .environmentObject(SettingsManager())
        .environmentObject(AppCoordinator())
}
