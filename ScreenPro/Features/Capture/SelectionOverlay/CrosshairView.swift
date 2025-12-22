import SwiftUI

// MARK: - Crosshair View

/// Displays crosshair lines that follow the mouse cursor.
/// Used during area selection before the user starts dragging.
struct CrosshairView: View {
    // MARK: - Properties

    /// Current mouse position in view coordinates.
    let position: CGPoint

    /// Size of the containing view.
    let viewSize: CGSize

    /// Whether to show the crosshair.
    let isVisible: Bool

    // MARK: - Configuration

    private let lineWidth: CGFloat = 1
    private let lineColor = Color.white.opacity(0.8)
    private let dashPattern: [CGFloat] = [5, 5]

    // MARK: - Body

    var body: some View {
        if isVisible {
            ZStack {
                // Vertical line
                Path { path in
                    path.move(to: CGPoint(x: position.x, y: 0))
                    path.addLine(to: CGPoint(x: position.x, y: viewSize.height))
                }
                .stroke(style: StrokeStyle(
                    lineWidth: lineWidth,
                    dash: dashPattern
                ))
                .foregroundColor(lineColor)

                // Horizontal line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: position.y))
                    path.addLine(to: CGPoint(x: viewSize.width, y: position.y))
                }
                .stroke(style: StrokeStyle(
                    lineWidth: lineWidth,
                    dash: dashPattern
                ))
                .foregroundColor(lineColor)
            }
            .accessibilityLabel("Crosshair")
            .accessibilityHint("Shows current cursor position during area selection")
        }
    }
}

// MARK: - Preview

#Preview {
    CrosshairView(
        position: CGPoint(x: 200, y: 150),
        viewSize: CGSize(width: 400, height: 300),
        isVisible: true
    )
    .frame(width: 400, height: 300)
    .background(Color.black.opacity(0.3))
}
