import Foundation
import CoreGraphics

// MARK: - MagnifierState (T054)

/// State of the magnifier during area selection.
struct MagnifierState: Equatable {
    /// Whether the magnifier is currently visible.
    let isVisible: Bool

    /// Current cursor position in screen coordinates.
    let cursorPosition: CGPoint

    /// Magnification level (default 8x).
    let magnification: CGFloat

    /// Size of the magnifier view.
    let viewSize: CGSize

    /// Creates a magnifier state.
    /// - Parameters:
    ///   - isVisible: Whether magnifier is visible.
    ///   - cursorPosition: Cursor position in screen coordinates.
    ///   - magnification: Magnification level (default 8x).
    ///   - viewSize: Size of the magnifier view.
    init(
        isVisible: Bool = false,
        cursorPosition: CGPoint = .zero,
        magnification: CGFloat = 8.0,
        viewSize: CGSize = CGSize(width: 150, height: 150)
    ) {
        self.isVisible = isVisible
        self.cursorPosition = cursorPosition
        self.magnification = max(1, min(16, magnification))
        self.viewSize = viewSize
    }

    /// Default hidden state.
    static var hidden: MagnifierState {
        MagnifierState(isVisible: false)
    }

    /// Creates a visible state at the specified position.
    /// - Parameter position: The cursor position.
    /// - Returns: A visible magnifier state.
    static func visible(at position: CGPoint) -> MagnifierState {
        MagnifierState(isVisible: true, cursorPosition: position)
    }

    /// The ideal position for the magnifier view (offset from cursor).
    /// - Parameter screenBounds: The screen bounds to stay within.
    /// - Returns: The recommended position for the magnifier.
    func idealPosition(in screenBounds: CGRect) -> CGPoint {
        // Default offset: below and to the right of cursor
        let offset: CGFloat = 30
        var position = CGPoint(
            x: cursorPosition.x + offset,
            y: cursorPosition.y - offset - viewSize.height
        )

        // Keep within screen bounds - flip to other side if needed
        if position.x + viewSize.width > screenBounds.maxX {
            position.x = cursorPosition.x - offset - viewSize.width
        }

        if position.y < screenBounds.minY {
            position.y = cursorPosition.y + offset
        }

        // Clamp to screen bounds
        position.x = max(screenBounds.minX, min(screenBounds.maxX - viewSize.width, position.x))
        position.y = max(screenBounds.minY, min(screenBounds.maxY - viewSize.height, position.y))

        return position
    }

    /// The source rectangle to capture for magnification.
    var sourceRect: CGRect {
        let sourceSize = CGSize(
            width: viewSize.width / magnification,
            height: viewSize.height / magnification
        )
        return CGRect(
            x: cursorPosition.x - sourceSize.width / 2,
            y: cursorPosition.y - sourceSize.height / 2,
            width: sourceSize.width,
            height: sourceSize.height
        )
    }
}
