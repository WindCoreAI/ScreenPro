import SwiftUI
import AppKit

// MARK: - RecordingControlsView (T028)

/// SwiftUI view for recording controls with timer, pause/resume, and stop buttons
struct RecordingControlsView: View {
    @ObservedObject var recordingService: RecordingService

    let onStop: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void

    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 12) {
                // Recording indicator with pulsing animation (T030)
                recordingIndicator

                // Duration timer
                durationLabel

                // GIF frame count indicator (if recording GIF)
                if recordingService.gifFrameCount > 0 {
                    gifFrameIndicator
                }

                Divider()
                    .frame(height: 20)

                // Control buttons
                controlButtons
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Memory warning for long GIF recordings (T048)
            if recordingService.isGIFMemoryWarningShown {
                memoryWarningView
            }
        }
        .background(backgroundView)
        .onAppear {
            startPulsingAnimation()
        }
    }

    // MARK: - GIF Frame Indicator

    private var gifFrameIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "photo.stack")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))
            Text("\(recordingService.gifFrameCount)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
        .accessibilityLabel("\(recordingService.gifFrameCount) frames captured")
    }

    // MARK: - Memory Warning (T048)

    private var memoryWarningView: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(.yellow)
            Text("Long GIF - Consider stopping soon")
                .font(.system(size: 10))
                .foregroundColor(.yellow)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .accessibilityLabel("Memory warning: GIF recording is getting long")
    }

    // MARK: - Recording Indicator (T030)

    private var recordingIndicator: some View {
        Circle()
            .fill(recordingService.state == .paused ? Color.yellow : Color.red)
            .frame(width: 12, height: 12)
            .opacity(isPulsing && recordingService.state == .recording ? 0.5 : 1.0)
            .animation(
                recordingService.state == .recording
                    ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
            .accessibilityLabel(recordingService.state == .paused ? "Recording paused" : "Recording in progress")
    }

    // MARK: - Duration Label

    private var durationLabel: some View {
        Text(formattedDuration)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.white)
            .frame(minWidth: 70, alignment: .leading)
            .accessibilityLabel("Recording duration: \(formattedDuration)")
    }

    private var formattedDuration: String {
        let totalSeconds = Int(recordingService.duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let tenths = Int((recordingService.duration - Double(totalSeconds)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, tenths)
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 8) {
            // Pause/Resume button (T036)
            if recordingService.state == .paused {
                Button(action: onResume) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(ControlButtonStyle())
                .accessibilityLabel("Resume recording")
                .accessibilityHint("Continues the paused recording")
            } else {
                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(ControlButtonStyle())
                .accessibilityLabel("Pause recording")
                .accessibilityHint("Temporarily pauses the recording")
                .disabled(recordingService.state != .recording)
            }

            // Stop button (T036)
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .buttonStyle(ControlButtonStyle(isDestructive: false))
            .accessibilityLabel("Stop recording")
            .accessibilityHint("Stops and saves the recording")
            .disabled(recordingService.state != .recording && recordingService.state != .paused)

            // Cancel button (T036)
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(ControlButtonStyle(isSmall: true))
            .accessibilityLabel("Cancel recording")
            .accessibilityHint("Cancels and discards the recording")
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundView: some View {
        if recordingService.isGIFMemoryWarningShown {
            // Use rounded rectangle when showing warning
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        } else {
            Capsule()
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Animation

    private func startPulsingAnimation() {
        isPulsing = true
    }
}

// MARK: - ControlButtonStyle

struct ControlButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    var isSmall: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: isSmall ? 24 : 32, height: isSmall ? 24 : 32)
            .background(
                Circle()
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isDestructive {
            return isPressed ? Color.red.opacity(0.6) : Color.red.opacity(0.4)
        }
        return isPressed ? Color.white.opacity(0.3) : Color.white.opacity(0.2)
    }
}

// MARK: - Preview

#Preview {
    RecordingControlsView(
        recordingService: {
            let service = RecordingService(
                storageService: StorageService(),
                settingsManager: SettingsManager(),
                permissionManager: PermissionManager()
            )
            return service
        }(),
        onStop: {},
        onPause: {},
        onResume: {},
        onCancel: {}
    )
    .frame(width: 280, height: 50)
    .background(Color.gray)
}
