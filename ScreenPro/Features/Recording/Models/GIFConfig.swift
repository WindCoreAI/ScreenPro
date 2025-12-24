import Foundation
import CoreGraphics

/// Configuration for GIF recording
struct GIFConfig: Codable, Equatable, Sendable {
    /// Capture frame rate (lower = smaller file)
    var frameRate: Int = 15

    /// Maximum colors in palette (GIF max is 256)
    var maxColors: Int = 256

    /// Number of times to loop (0 = infinite)
    var loopCount: Int = 0

    /// Scale factor for output size (1.0 = original, 0.5 = half)
    var scale: CGFloat = 1.0

    // MARK: - Validation

    /// Valid frame rate range for GIF recording
    static let validFrameRateRange = 5...30

    /// Valid color count range
    static let validColorRange = 2...256

    /// Valid scale range
    static let validScaleRange: ClosedRange<CGFloat> = 0.25...1.0

    /// Check if the configuration is valid
    var isValid: Bool {
        Self.validFrameRateRange.contains(frameRate) &&
        Self.validColorRange.contains(maxColors) &&
        loopCount >= 0 &&
        Self.validScaleRange.contains(scale)
    }

    /// Frame delay in seconds for GIF encoding
    var frameDelay: Double {
        1.0 / Double(frameRate)
    }
}
