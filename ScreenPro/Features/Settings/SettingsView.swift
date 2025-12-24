import SwiftUI

// MARK: - Settings View (T031 - placeholder for Phase 5)

/// Main settings window with tabbed preferences
struct SettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)

            CaptureSettingsTab()
                .tabItem {
                    Label("Capture", systemImage: "camera")
                }
                .tag(1)

            RecordingSettingsTab()
                .tabItem {
                    Label("Recording", systemImage: "record.circle")
                }
                .tag(2)

            ShortcutsSettingsTab()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag(3)

            AdvancedFeaturesSettingsTab()
                .tabItem {
                    Label("Advanced", systemImage: "sparkles")
                }
                .tag(4)
        }
        .frame(width: 500, height: 500)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppCoordinator())
        .environmentObject(SettingsManager())
        .environmentObject(PermissionManager())
}
