import Foundation

// MARK: - OverlayPosition (T070)

/// Position of the camera overlay on screen.
enum OverlayPosition: String, Codable, CaseIterable, Identifiable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        case .custom: return "Custom"
        }
    }

    /// Returns the offset from screen edges for this position.
    /// - Parameter padding: Edge padding value.
    /// - Returns: Offset from origin (bottom-left in screen coordinates).
    func offset(for screenSize: CGSize, overlaySize: CGSize, padding: CGFloat = 20) -> CGPoint {
        switch self {
        case .topLeft:
            return CGPoint(
                x: padding,
                y: screenSize.height - overlaySize.height - padding
            )
        case .topRight:
            return CGPoint(
                x: screenSize.width - overlaySize.width - padding,
                y: screenSize.height - overlaySize.height - padding
            )
        case .bottomLeft:
            return CGPoint(
                x: padding,
                y: padding
            )
        case .bottomRight:
            return CGPoint(
                x: screenSize.width - overlaySize.width - padding,
                y: padding
            )
        case .custom:
            return .zero
        }
    }
}
