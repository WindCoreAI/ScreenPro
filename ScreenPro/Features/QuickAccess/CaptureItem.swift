import Foundation
import AppKit

// MARK: - CaptureItem

/// Represents a single capture in the Quick Access queue.
/// Wraps CaptureResult to add queue-specific properties like thumbnail and timing.
struct CaptureItem: Identifiable {
    // MARK: - Properties

    /// Unique identifier, inherited from the underlying CaptureResult.
    let id: UUID

    /// The original capture data containing the full-resolution image.
    let result: CaptureResult

    /// Scaled preview image for display in the overlay.
    /// Generated asynchronously after item creation.
    var thumbnail: NSImage?

    /// When this item was added to the queue.
    let createdAt: Date

    // MARK: - Computed Properties

    /// Original image dimensions in pixels.
    var dimensions: CGSize {
        result.pixelSize
    }

    /// Full-resolution image from the capture result.
    var nsImage: NSImage {
        result.nsImage
    }

    /// Formatted dimensions string (e.g., "1920 × 1080").
    var dimensionsText: String {
        "\(Int(dimensions.width)) × \(Int(dimensions.height))"
    }

    /// Relative time since capture (e.g., "Just now", "2m ago").
    var timeAgoText: String {
        let interval = Date().timeIntervalSince(createdAt)

        if interval < 5 {
            return "Just now"
        } else if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: createdAt)
        }
    }

    // MARK: - Initialization

    /// Creates a new CaptureItem from a CaptureResult.
    /// - Parameters:
    ///   - result: The capture result containing the image data.
    ///   - thumbnail: Optional pre-generated thumbnail.
    init(result: CaptureResult, thumbnail: NSImage? = nil) {
        self.id = result.id
        self.result = result
        self.thumbnail = thumbnail
        self.createdAt = Date()
    }
}

// MARK: - Equatable

extension CaptureItem: Equatable {
    static func == (lhs: CaptureItem, rhs: CaptureItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension CaptureItem: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
