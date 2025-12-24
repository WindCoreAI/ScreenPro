import SwiftUI

// MARK: - ClickRipple (T070)

/// Animated expanding ring for click visualization
struct ClickRipple: View {
    let clickEffect: ClickEffect

    @State private var scale: CGFloat = 0.0
    @State private var opacity: Double = 1.0

    var body: some View {
        Circle()
            .stroke(clickEffect.clickType.color, lineWidth: ClickEffect.ringStrokeWidth)
            .frame(
                width: ClickEffect.maxRingRadius * 2,
                height: ClickEffect.maxRingRadius * 2
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .position(clickEffect.position)
            .onAppear {
                withAnimation(.easeOut(duration: ClickEffect.animationDuration)) {
                    scale = 1.0
                    opacity = 0.0
                }
            }
            .accessibilityLabel(clickEffect.clickType.displayName)
            .accessibilityHidden(true)
    }
}

// MARK: - ClickOverlayView (T069)

/// SwiftUI view that displays click effects as expanding rings
struct ClickOverlayView: View {
    @ObservedObject var viewModel: ClickOverlayViewModel

    var body: some View {
        ZStack {
            // Transparent background to capture mouse events
            Color.clear

            // Active click effects
            ForEach(viewModel.activeEffects) { effect in
                ClickRipple(clickEffect: effect)
            }
        }
        .allowsHitTesting(false) // Don't block mouse events
    }
}

// MARK: - ClickOverlayViewModel

/// View model for managing active click effects
@MainActor
final class ClickOverlayViewModel: ObservableObject {
    @Published private(set) var activeEffects: [ClickEffect] = []

    /// Adds a new click effect to be displayed
    func addClick(at position: CGPoint, type: ClickEffect.ClickType) {
        let effect = ClickEffect(position: position, clickType: type)
        activeEffects.append(effect)

        // Remove effect after animation completes
        Task {
            try? await Task.sleep(for: .milliseconds(Int(ClickEffect.animationDuration * 1000) + 100))
            removeEffect(effect.id)
        }
    }

    /// Removes a specific effect by ID
    private func removeEffect(_ id: UUID) {
        activeEffects.removeAll { $0.id == id }
    }

    /// Clears all active effects
    func clearAll() {
        activeEffects.removeAll()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.3)

        ClickOverlayView(viewModel: {
            let vm = ClickOverlayViewModel()
            // Add sample clicks for preview
            Task { @MainActor in
                vm.addClick(at: CGPoint(x: 100, y: 100), type: .left)
                vm.addClick(at: CGPoint(x: 200, y: 150), type: .right)
                vm.addClick(at: CGPoint(x: 150, y: 200), type: .middle)
            }
            return vm
        }())
    }
    .frame(width: 400, height: 300)
}
