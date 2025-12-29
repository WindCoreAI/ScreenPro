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
            // Use a custom view for the label that triggers initialization
            MenuBarLabel(coordinator: coordinator)
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

// MARK: - Menu Bar Label

/// Custom label view that triggers coordinator initialization when it appears
private struct MenuBarLabel: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        Label("ScreenPro", systemImage: "camera.viewfinder")
            .task {
                // Initialize coordinator when menu bar icon appears
                if !coordinator.isReady {
                    print("[ScreenProApp] Initializing coordinator from menu bar label...")
                    await coordinator.initialize()
                    print("[ScreenProApp] Coordinator initialized: isReady=\(coordinator.isReady), permission=\(coordinator.permissionManager.screenRecordingStatus)")
                }
            }
    }
}
