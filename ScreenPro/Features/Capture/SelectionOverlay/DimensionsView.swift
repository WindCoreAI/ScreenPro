import SwiftUI

// MARK: - Dimensions View

/// Displays the width and height of the current selection.
/// Positioned near the selection rectangle for easy visibility.
struct DimensionsView: View {
    // MARK: - Properties

    /// Size of the current selection.
    let size: CGSize

    /// Position to display the dimensions badge.
    let position: CGPoint

    /// Offset direction based on selection position.
    let offsetDirection: OffsetDirection

    // MARK: - Types

    enum OffsetDirection {
        case bottomRight
        case bottomLeft
        case topRight
        case topLeft
    }

    // MARK: - Configuration

    private let backgroundColor = Color.black.opacity(0.75)
    private let textColor = Color.white
    private let padding: CGFloat = 6
    private let cornerRadius: CGFloat = 4
    private let fontSize: CGFloat = 12
    private let offset: CGFloat = 8

    // MARK: - Body

    var body: some View {
        Text(dimensionsText)
            .font(.system(size: fontSize, weight: .medium, design: .monospaced))
            .foregroundColor(textColor)
            .padding(.horizontal, padding)
            .padding(.vertical, padding / 2)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
            )
            .position(adjustedPosition)
            .accessibilityLabel("Selection size")
            .accessibilityValue("\(Int(size.width)) by \(Int(size.height)) pixels")
    }

    // MARK: - Computed Properties

    private var dimensionsText: String {
        "\(Int(size.width)) × \(Int(size.height))"
    }

    /// Adjusts position based on offset direction to keep badge visible.
    private var adjustedPosition: CGPoint {
        switch offsetDirection {
        case .bottomRight:
            return CGPoint(x: position.x + offset + 30, y: position.y + offset + 10)
        case .bottomLeft:
            return CGPoint(x: position.x - offset - 30, y: position.y + offset + 10)
        case .topRight:
            return CGPoint(x: position.x + offset + 30, y: position.y - offset - 10)
        case .topLeft:
            return CGPoint(x: position.x - offset - 30, y: position.y - offset - 10)
        }
    }
}

// MARK: - Helper Extension

extension DimensionsView {
    /// Calculates the best offset direction based on selection and view bounds.
    static func offsetDirection(
        for rect: CGRect,
        in viewSize: CGSize
    ) -> OffsetDirection {
        let rightSpace = viewSize.width - rect.maxX
        let bottomSpace = viewSize.height - rect.maxY

        // Prefer bottom-right, but adjust if insufficient space
        if rightSpace > 80 && bottomSpace > 30 {
            return .bottomRight
        } else if rightSpace < 80 && bottomSpace > 30 {
            return .bottomLeft
        } else if rightSpace > 80 {
            return .topRight
        } else {
            return .topLeft
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.3)

        DimensionsView(
            size: CGSize(width: 320, height: 240),
            position: CGPoint(x: 200, y: 150),
            offsetDirection: .bottomRight
        )
    }
    .frame(width: 400, height: 300)
}
