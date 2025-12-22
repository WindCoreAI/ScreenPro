import SwiftUI

// MARK: - Menu Bar View (T014-T017, T059 - accessibility labels added)

/// Menu bar dropdown menu displaying all capture and recording options
struct MenuBarView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        // Capture Section (T015)
        Section("Capture") {
            Button("Capture Area") {
                coordinator.captureArea()
            }
            .keyboardShortcut("4", modifiers: [.command, .shift])
            .disabled(!isReady)
            .accessibilityLabel("Capture Area")
            .accessibilityHint("Select a rectangular area to capture")

            Button("Capture Window") {
                coordinator.captureWindow()
            }
            .disabled(!isReady)
            .accessibilityLabel("Capture Window")
            .accessibilityHint("Select and capture a specific window")

            Button("Capture Fullscreen") {
                coordinator.captureFullscreen()
            }
            .keyboardShortcut("3", modifiers: [.command, .shift])
            .disabled(!isReady)
            .accessibilityLabel("Capture Fullscreen")
            .accessibilityHint("Capture the entire screen")

            Button("Capture Scrolling...") {
                // Will be implemented in later milestone
            }
            .disabled(true)
            .accessibilityLabel("Capture Scrolling")
            .accessibilityHint("Capture a scrolling window, not yet available")
        }

        Divider()

        // Recording Section (T016)
        Section("Record") {
            Button("Record Screen") {
                coordinator.startRecording()
            }
            .keyboardShortcut("6", modifiers: [.command, .shift])
            .disabled(!isReady)
            .accessibilityLabel("Record Screen")
            .accessibilityHint("Start recording the screen as video")

            Button("Record GIF") {
                // Will be implemented in later milestone
            }
            .disabled(true)
            .accessibilityLabel("Record GIF")
            .accessibilityHint("Record screen as animated GIF, not yet available")
        }

        Divider()

        // Tools Section
        Section("Tools") {
            Button("Text Recognition (OCR)") {
                // Will be implemented in later milestone
            }
            .disabled(true)
            .accessibilityLabel("Text Recognition")
            .accessibilityHint("Capture and extract text from screen, not yet available")

            Button("All-in-One") {
                // Will be implemented in later milestone
            }
            .keyboardShortcut("5", modifiers: [.command, .shift])
            .disabled(true)
            .accessibilityLabel("All-in-One")
            .accessibilityHint("Quick access to all capture modes, not yet available")
        }

        Divider()

        // Settings and Quit (T017)
        SettingsLink {
            Text("Settings...")
        }
        .keyboardShortcut(",", modifiers: .command)
        .accessibilityLabel("Settings")
        .accessibilityHint("Open application settings")

        Divider()

        Button("Quit ScreenPro") {
            coordinator.cleanup()
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
        .accessibilityLabel("Quit ScreenPro")
        .accessibilityHint("Exit the application")
    }

    // MARK: - Computed Properties

    private var isReady: Bool {
        coordinator.isReady && coordinator.permissionManager.screenRecordingStatus == .authorized
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppCoordinator())
}
