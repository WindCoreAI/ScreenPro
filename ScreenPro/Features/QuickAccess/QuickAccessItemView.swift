import SwiftUI
import AppKit

// MARK: - QuickAccessItemView

/// SwiftUI view displaying a single capture in the Quick Access overlay.
/// Shows thumbnail, dimensions, timestamp, and action buttons.
struct QuickAccessItemView: View {
    // MARK: - Properties

    /// The capture item to display.
    let item: CaptureItem

    /// Whether this item is currently selected for keyboard navigation.
    let isSelected: Bool

    /// Closure called when the Copy button is tapped.
    let onCopy: () -> Void

    /// Closure called when the Save button is tapped.
    let onSave: () -> Void

    /// Closure called when the Annotate button is tapped.
    let onAnnotate: () -> Void

    /// Closure called when the Close/Dismiss button is tapped.
    let onDismiss: () -> Void

    // MARK: - Constants

    private let thumbnailWidth: CGFloat = 240
    private let thumbnailHeight: CGFloat = 135
    private let cornerRadius: CGFloat = 8
    private let spacing: CGFloat = 12
    private let buttonSize: CGFloat = 28

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            // Main content row
            HStack(spacing: spacing) {
                // Thumbnail
                thumbnailView

                // Info section
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.dimensionsText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)

                    Text(item.timeAgoText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .frame(height: thumbnailHeight)

                Spacer()
            }

            // Action buttons row
            HStack(spacing: 8) {
                actionButton(
                    icon: "doc.on.clipboard",
                    label: "Copy to Clipboard (⌘C)",
                    action: onCopy
                )

                actionButton(
                    icon: "square.and.arrow.down",
                    label: "Save to Disk (⌘S)",
                    action: onSave
                )

                actionButton(
                    icon: "pencil",
                    label: "Annotate (Return)",
                    action: onAnnotate
                )

                Spacer()

                actionButton(
                    icon: "xmark",
                    label: "Dismiss (Esc)",
                    action: onDismiss
                )
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .background(selectionBackground)
        .cornerRadius(cornerRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Screenshot, \(item.dimensionsText), captured \(item.timeAgoText)")
    }

    // MARK: - Subviews

    /// Thumbnail image view with drag-and-drop support.
    private var thumbnailView: some View {
        let displayImage = item.thumbnail ?? item.nsImage
        let fullImage = item.nsImage

        return DraggableThumbnail(
            image: displayImage,
            fullImage: fullImage
        )
        .frame(width: thumbnailWidth, height: thumbnailHeight)
        .cornerRadius(cornerRadius)
        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
    }

    /// Background for selection highlighting.
    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.accentColor.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                )
        } else {
            Color.clear
        }
    }

    /// Creates an action button with icon and accessibility label.
    /// - Parameters:
    ///   - icon: SF Symbol name for the button icon.
    ///   - label: Accessibility label and tooltip for the button.
    ///   - action: Closure to execute when button is tapped.
    /// - Returns: A styled button view.
    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: buttonSize, height: buttonSize)
                .foregroundColor(.primary)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}
