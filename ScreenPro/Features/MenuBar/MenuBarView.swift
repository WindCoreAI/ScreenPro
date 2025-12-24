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

        // Recording Section (T013, T016, T047)
        Section("Record") {
            Button("Record Fullscreen") {
                coordinator.startRecording()
            }
            .keyboardShortcut("6", modifiers: [.command, .shift])
            .disabled(!isReady || isRecording)
            .accessibilityLabel("Record Fullscreen")
            .accessibilityHint("Start recording the entire screen as video")

            Button("Record Window...") {
                coordinator.startRecordingWindow()
            }
            .disabled(!isReady || isRecording)
            .accessibilityLabel("Record Window")
            .accessibilityHint("Select and record a specific window")

            Button("Record Area...") {
                coordinator.startRecordingArea()
            }
            .disabled(!isReady || isRecording)
            .accessibilityLabel("Record Area")
            .accessibilityHint("Select a rectangular area to record")

            Divider()

            // GIF Recording Menu (T047)
            Menu("Record GIF") {
                Button("GIF Fullscreen") {
                    coordinator.startGIFRecording()
                }
                .disabled(!isReady || isRecording)
                .accessibilityLabel("Record GIF Fullscreen")
                .accessibilityHint("Start recording the entire screen as animated GIF")

                Button("GIF Window...") {
                    coordinator.startGIFRecordingWindow()
                }
                .disabled(!isReady || isRecording)
                .accessibilityLabel("Record GIF Window")
                .accessibilityHint("Select and record a window as animated GIF")

                Button("GIF Area...") {
                    coordinator.startGIFRecordingArea()
                }
                .disabled(!isReady || isRecording)
                .accessibilityLabel("Record GIF Area")
                .accessibilityHint("Select an area to record as animated GIF")
            }
            .disabled(!isReady || isRecording)
            .accessibilityLabel("Record GIF")
            .accessibilityHint("Record screen as animated GIF")

            // Show stop recording option if currently recording
            if isRecording {
                Divider()

                Button("Stop Recording") {
                    coordinator.stopRecording()
                }
                .keyboardShortcut("6", modifiers: [.command, .shift])
                .accessibilityLabel("Stop Recording")
                .accessibilityHint("Stop the current recording and save")
            }
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

    private var isRecording: Bool {
        coordinator.state == .recording
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppCoordinator())
}
