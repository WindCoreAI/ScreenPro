import SwiftUI

// MARK: - KeystrokeOverlayView (T078)

/// SwiftUI view that displays recent keystrokes
struct KeystrokeOverlayView: View {
    @ObservedObject var viewModel: KeystrokeOverlayViewModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Spacer()

            // Display recent keystrokes (T080)
            ForEach(viewModel.recentKeyPresses) { keyPress in
                KeyPressBadge(keyPress: keyPress)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .allowsHitTesting(false)
    }
}

// MARK: - KeyPressBadge

/// Badge view for a single key press
struct KeyPressBadge: View {
    let keyPress: KeyPress

    @State private var opacity: Double = 1.0

    var body: some View {
        Text(keyPress.displayString)
            .font(.system(size: 20, weight: .medium, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.75))
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .opacity(opacity)
            .onAppear {
                // Start fade out after delay (T080)
                withAnimation(.easeOut(duration: 0.3).delay(KeyPress.fadeDuration - 0.3)) {
                    opacity = 0.0
                }
            }
            .accessibilityLabel("Key pressed: \(keyPress.displayString)")
    }
}

// MARK: - KeystrokeOverlayViewModel

/// View model for managing keystroke display queue (T080)
@MainActor
final class KeystrokeOverlayViewModel: ObservableObject {
    @Published private(set) var recentKeyPresses: [KeyPress] = []

    /// Adds a new key press to the queue
    func addKeyPress(_ keyPress: KeyPress) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            recentKeyPresses.append(keyPress)

            // Limit queue size (T080)
            if recentKeyPresses.count > KeyPress.maxQueueSize {
                recentKeyPresses.removeFirst()
            }
        }

        // Remove after fade duration
        Task {
            try? await Task.sleep(for: .milliseconds(Int(KeyPress.fadeDuration * 1000)))
            removeKeyPress(keyPress.id)
        }
    }

    /// Removes a specific key press by ID
    private func removeKeyPress(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.2)) {
            recentKeyPresses.removeAll { $0.id == id }
        }
    }

    /// Clears all key presses
    func clearAll() {
        recentKeyPresses.removeAll()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.3)

        KeystrokeOverlayView(viewModel: {
            let vm = KeystrokeOverlayViewModel()
            Task { @MainActor in
                vm.addKeyPress(KeyPress(key: "C", modifiers: [.command]))
                vm.addKeyPress(KeyPress(key: "V", modifiers: [.command]))
                vm.addKeyPress(KeyPress(key: "S", modifiers: [.command, .shift]))
            }
            return vm
        }())
    }
    .frame(width: 400, height: 300)
}
