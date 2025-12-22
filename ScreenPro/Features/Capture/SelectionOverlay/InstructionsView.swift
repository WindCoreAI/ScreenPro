import SwiftUI

// MARK: - Instructions View

/// Displays help text during area selection.
/// Shows different instructions based on selection state.
struct InstructionsView: View {
    // MARK: - Properties

    /// Whether the user is currently dragging.
    let isDragging: Bool

    /// Position of the mouse cursor for following.
    let mousePosition: CGPoint

    /// Size of the containing view.
    let viewSize: CGSize

    // MARK: - Configuration

    private let backgroundColor = Color.black.opacity(0.75)
    private let textColor = Color.white
    private let secondaryTextColor = Color.white.opacity(0.7)
    private let padding: CGFloat = 12
    private let cornerRadius: CGFloat = 8
    private let fontSize: CGFloat = 13
    private let offsetFromCursor: CGFloat = 40

    // MARK: - Body

    var body: some View {
        if !isDragging {
            instructionsBadge
                .position(badgePosition)
                .animation(.easeOut(duration: 0.1), value: mousePosition)
        }
    }

    // MARK: - Components

    private var instructionsBadge: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Click and drag to select area")
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(textColor)

            Text("Press Escape to cancel")
                .font(.system(size: fontSize - 1))
                .foregroundColor(secondaryTextColor)
        }
        .padding(.horizontal, padding)
        .padding(.vertical, padding - 2)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
        .accessibilityLabel("Instructions")
        .accessibilityHint("Click and drag to select an area, press Escape to cancel")
    }

    // MARK: - Computed Properties

    /// Position for the instructions badge, avoiding edges.
    private var badgePosition: CGPoint {
        let badgeWidth: CGFloat = 200
        let badgeHeight: CGFloat = 50

        // Calculate preferred position below and to the right of cursor
        var x = mousePosition.x + offsetFromCursor
        var y = mousePosition.y + offsetFromCursor

        // Clamp to view bounds with margin
        let margin: CGFloat = 20
        x = min(max(x, margin + badgeWidth / 2), viewSize.width - badgeWidth / 2 - margin)
        y = min(max(y, margin + badgeHeight / 2), viewSize.height - badgeHeight / 2 - margin)

        // If cursor is in bottom-right quadrant, flip to top-left
        if mousePosition.x > viewSize.width - 250 && mousePosition.y > viewSize.height - 100 {
            x = mousePosition.x - offsetFromCursor - badgeWidth / 2
            y = mousePosition.y - offsetFromCursor - badgeHeight / 2
        }

        return CGPoint(x: x, y: y)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.3)

        InstructionsView(
            isDragging: false,
            mousePosition: CGPoint(x: 200, y: 150),
            viewSize: CGSize(width: 800, height: 600)
        )
    }
    .frame(width: 800, height: 600)
}
