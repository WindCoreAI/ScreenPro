import Foundation
import SwiftUI

// MARK: - ClickEffect (T066)

/// Represents a mouse click event for visualization during recording
struct ClickEffect: Identifiable, Equatable {
    /// Unique identifier for the click effect
    let id: UUID

    /// Screen position of the click
    let position: CGPoint

    /// Type of click (left, right, middle)
    let clickType: ClickType

    /// Timestamp when the click occurred
    let timestamp: Date

    /// Initialize a new click effect
    init(
        id: UUID = UUID(),
        position: CGPoint,
        clickType: ClickType,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.position = position
        self.clickType = clickType
        self.timestamp = timestamp
    }

    // MARK: - Animation Constants

    /// Duration of the ripple animation in seconds
    static let animationDuration: TimeInterval = 0.5

    /// Maximum radius of the expanding ring
    static let maxRingRadius: CGFloat = 30.0

    /// Thickness of the ring stroke
    static let ringStrokeWidth: CGFloat = 3.0
}

// MARK: - ClickType

extension ClickEffect {
    /// Types of mouse clicks
    enum ClickType: String, CaseIterable, Sendable {
        case left
        case right
        case middle

        /// Color for the click visualization (T071)
        var color: Color {
            switch self {
            case .left:
                return .blue
            case .right:
                return .green
            case .middle:
                return .orange
            }
        }

        /// Display name for accessibility
        var displayName: String {
            switch self {
            case .left:
                return "Left click"
            case .right:
                return "Right click"
            case .middle:
                return "Middle click"
            }
        }
    }
}

// MARK: - Sendable

extension ClickEffect: Sendable {}
