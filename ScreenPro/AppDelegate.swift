import AppKit
import SwiftUI

// MARK: - App Delegate (T013)

final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    private var coordinator: AppCoordinator?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Get the coordinator from the SwiftUI environment
        // Note: In the full implementation, we'd coordinate between AppDelegate and SwiftUI app
        print("ScreenPro launched")

        // Ensure app doesn't show in Dock (backup for LSUIElement)
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup will be handled by AppCoordinator
        print("ScreenPro terminating")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When user clicks dock icon (if visible) or uses Spotlight to open app
        // Show the menu bar menu or settings
        return true
    }

    // MARK: - App Coordinator Integration (T045, T046)

    func setCoordinator(_ coordinator: AppCoordinator) {
        self.coordinator = coordinator

        // Initialize the coordinator
        Task { @MainActor in
            await coordinator.initialize()
        }
    }
}
