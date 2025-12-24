import Foundation
import CoreGraphics

// MARK: - OverlayConfig (T072)

/// Configuration for the camera overlay.
struct OverlayConfig: Equatable {
    /// Whether the overlay is enabled.
    var isEnabled: Bool

    /// Position preset.
    var position: OverlayPosition

    /// Custom position (used when position == .custom).
    var customPosition: CGPoint

    /// Overlay shape.
    var shape: OverlayShape

    /// Size of the overlay.
    var size: CGSize

    /// Whether to mirror the camera horizontally.
    var isMirrored: Bool

    /// Border width around the overlay.
    var borderWidth: CGFloat

    /// Creates an overlay configuration.
    init(
        isEnabled: Bool = false,
        position: OverlayPosition = .bottomRight,
        customPosition: CGPoint = .zero,
        shape: OverlayShape = .circle,
        size: CGSize = CGSize(width: 200, height: 200),
        isMirrored: Bool = true,
        borderWidth: CGFloat = 3
    ) {
        self.isEnabled = isEnabled
        self.position = position
        self.customPosition = customPosition
        self.shape = shape
        self.size = size
        self.isMirrored = isMirrored
        self.borderWidth = max(0, min(10, borderWidth))
    }

    /// Default configuration.
    static var `default`: OverlayConfig {
        OverlayConfig()
    }

    /// Preset size options.
    static var sizePresets: [CGSize] {
        [
            CGSize(width: 150, height: 150),
            CGSize(width: 200, height: 200),
            CGSize(width: 250, height: 250),
            CGSize(width: 300, height: 300)
        ]
    }
}
