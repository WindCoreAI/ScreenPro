import SwiftUI

// MARK: - App Entry Point (T012)

@main
struct ScreenProApp: App {
    // MARK: - App Delegate

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - State

    @StateObject private var coordinator = AppCoordinator()

    // MARK: - Body

    var body: some Scene {
        // Menu Bar Extra (T018)
        MenuBarExtra {
            MenuBarView()
                .environmentObject(coordinator)
        } label: {
            Label("ScreenPro", systemImage: "camera.viewfinder")
        }
        .menuBarExtraStyle(.menu)

        // Settings Scene (T036)
        SwiftUI.Settings {
            SettingsView()
                .environmentObject(coordinator)
                .environmentObject(coordinator.settingsManager)
                .environmentObject(coordinator.permissionManager)
        }
    }
}
