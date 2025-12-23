import SwiftUI

// MARK: - QuickAccessContentView

/// Main container view for the Quick Access overlay.
/// Displays a vertical stack of capture items with actions.
struct QuickAccessContentView: View {
    // MARK: - Properties

    /// The controller managing the Quick Access overlay state.
    @ObservedObject var controller: QuickAccessWindowController

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            ForEach(controller.queue.items) { item in
                QuickAccessItemView(
                    item: item,
                    isSelected: controller.queue.isSelected(item),
                    onCopy: {
                        controller.copyToClipboard(item)
                    },
                    onSave: {
                        try? controller.saveToFile(item)
                    },
                    onAnnotate: {
                        controller.openInAnnotator(item)
                    },
                    onDismiss: {
                        controller.dismiss(item)
                    }
                )
            }
        }
        .padding(12)
        .background(VisualEffectView.hudWindow)
        .cornerRadius(12)
        .onHover { isHovering in
            if isHovering {
                controller.cancelAutoDismiss()
            } else {
                controller.restartAutoDismiss()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quick Access captures")
    }
}
