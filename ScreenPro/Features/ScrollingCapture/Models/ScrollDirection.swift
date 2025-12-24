import Foundation

// MARK: - ScrollDirection (T021)

/// Represents the direction(s) to capture during scrolling capture.
enum ScrollDirection: String, Codable, CaseIterable {
    /// Capture vertical scrolling content (most common).
    case vertical
    /// Capture horizontal scrolling content.
    case horizontal
    /// Capture in both directions.
    case both

    var displayName: String {
        switch self {
        case .vertical: return "Vertical"
        case .horizontal: return "Horizontal"
        case .both: return "Both"
        }
    }
}
