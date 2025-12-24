import Foundation

// MARK: - OverlayShape (T071)

/// Shape of the camera overlay.
enum OverlayShape: String, Codable, CaseIterable, Identifiable {
    case circle
    case roundedRectangle
    case rectangle

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .circle: return "Circle"
        case .roundedRectangle: return "Rounded Rectangle"
        case .rectangle: return "Rectangle"
        }
    }

    var icon: String {
        switch self {
        case .circle: return "circle.fill"
        case .roundedRectangle: return "app.fill"
        case .rectangle: return "rectangle.fill"
        }
    }

    /// Corner radius as a ratio of the smaller dimension.
    var cornerRadiusRatio: CGFloat {
        switch self {
        case .circle: return 0.5 // Full circle
        case .roundedRectangle: return 0.15
        case .rectangle: return 0
        }
    }

    /// Calculates the actual corner radius for a given size.
    /// - Parameter size: The overlay size.
    /// - Returns: The corner radius in points.
    func cornerRadius(for size: CGSize) -> CGFloat {
        let minDimension = min(size.width, size.height)
        return minDimension * cornerRadiusRatio
    }
}
