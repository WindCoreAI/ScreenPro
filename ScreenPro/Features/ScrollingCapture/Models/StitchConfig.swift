import Foundation

// MARK: - StitchConfig (T023)

/// Configuration for the scrolling capture behavior.
struct StitchConfig: Equatable {
    /// Scroll direction to capture.
    let direction: ScrollDirection

    /// Seconds between frame captures.
    let captureInterval: TimeInterval

    /// Expected overlap between frames (0.1-0.5).
    let overlapRatio: CGFloat

    /// Maximum frames to capture.
    let maxFrames: Int

    /// Creates a stitch configuration with the specified parameters.
    /// - Parameters:
    ///   - direction: Scroll direction to capture.
    ///   - captureInterval: Seconds between frame captures (default 0.15).
    ///   - overlapRatio: Expected overlap between frames (default 0.2).
    ///   - maxFrames: Maximum frames to capture (default 50).
    init(
        direction: ScrollDirection = .vertical,
        captureInterval: TimeInterval = 0.15,
        overlapRatio: CGFloat = 0.2,
        maxFrames: Int = 50
    ) {
        // Validate and clamp values
        self.direction = direction
        self.captureInterval = max(0.05, min(0.5, captureInterval))
        self.overlapRatio = max(0.1, min(0.5, overlapRatio))
        self.maxFrames = max(5, min(100, maxFrames))
    }

    /// Creates a configuration from settings.
    /// - Parameter settings: The user settings.
    /// - Returns: A StitchConfig with values from settings.
    static func from(settings: Settings) -> StitchConfig {
        StitchConfig(
            direction: .vertical,
            captureInterval: 0.15,
            overlapRatio: CGFloat(settings.scrollingCaptureOverlapRatio),
            maxFrames: settings.scrollingCaptureMaxFrames
        )
    }

    /// Default configuration for scrolling capture.
    static var `default`: StitchConfig {
        StitchConfig()
    }
}
