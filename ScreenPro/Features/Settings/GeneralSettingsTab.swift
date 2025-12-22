import SwiftUI

// MARK: - General Settings Tab (T032 - placeholder for Phase 5)

/// General preferences tab with launch, menu bar, and sound settings
struct GeneralSettingsTab: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var permissionManager: PermissionManager

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: $settingsManager.settings.launchAtLogin)
                Toggle("Show Menu Bar Icon", isOn: $settingsManager.settings.showMenuBarIcon)
            }

            Section("Sounds") {
                Toggle("Play Capture Sound", isOn: $settingsManager.settings.playCaptureSound)
            }

            Section("Permissions") {
                PermissionRow(
                    title: "Screen Recording",
                    status: permissionManager.screenRecordingStatus,
                    onRequest: {
                        permissionManager.requestScreenRecordingPermission()
                    },
                    onOpenSettings: {
                        permissionManager.openScreenRecordingPreferences()
                    }
                )

                PermissionRow(
                    title: "Microphone",
                    status: permissionManager.microphoneStatus,
                    onRequest: {
                        Task {
                            _ = await permissionManager.requestMicrophonePermission()
                        }
                    },
                    onOpenSettings: {
                        permissionManager.openMicrophonePreferences()
                    }
                )
            }

            Section {
                Button("Reset to Defaults") {
                    settingsManager.reset()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Permission Row Component (T035)

/// Displays permission status with request/open settings actions
struct PermissionRow: View {
    let title: String
    let status: PermissionStatus
    let onRequest: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack {
            Text(title)
            Spacer()

            switch status {
            case .authorized:
                Label("Authorized", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .denied:
                HStack {
                    Label("Denied", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Button("Open Settings") {
                        onOpenSettings()
                    }
                    .buttonStyle(.link)
                }
            case .notDetermined:
                Button("Request") {
                    onRequest()
                }
            }
        }
    }
}

#Preview {
    GeneralSettingsTab()
        .environmentObject(SettingsManager())
        .environmentObject(PermissionManager())
}
