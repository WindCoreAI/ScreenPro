import Foundation
import CoreGraphics

// MARK: - CapturedFrame (T022)

/// Represents a single captured frame during scrolling capture.
struct CapturedFrame: Identifiable {
    /// Unique identifier for this frame.
    let id: UUID

    /// The captured frame image data.
    let image: CGImage

    /// Scroll position when captured (relative to first frame).
    let scrollOffset: CGFloat

    /// When the frame was captured.
    let timestamp: Date

    /// Creates a new captured frame.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID).
    ///   - image: The captured CGImage.
    ///   - scrollOffset: Scroll position relative to first frame.
    ///   - timestamp: Capture timestamp (defaults to now).
    init(
        id: UUID = UUID(),
        image: CGImage,
        scrollOffset: CGFloat,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.image = image
        self.scrollOffset = scrollOffset
        self.timestamp = timestamp
    }
}
