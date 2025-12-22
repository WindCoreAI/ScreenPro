import Foundation
import AppKit
import ScreenCaptureKit

// MARK: - Capture Result

/// The result of a successful capture operation.
struct CaptureResult: @unchecked Sendable {
    /// Unique identifier for this capture.
    let id: UUID

    /// The captured image at native resolution.
    let image: CGImage

    /// The capture mode that was used.
    let mode: CaptureMode

    /// When the capture occurred.
    let timestamp: Date

    /// Original screen coordinates of the captured area.
    let sourceRect: CGRect

    /// The scale factor used for this capture.
    let scaleFactor: CGFloat

    /// Initializes a new capture result.
    init(
        id: UUID = UUID(),
        image: CGImage,
        mode: CaptureMode,
        timestamp: Date = Date(),
        sourceRect: CGRect,
        scaleFactor: CGFloat = 2.0
    ) {
        self.id = id
        self.image = image
        self.mode = mode
        self.timestamp = timestamp
        self.sourceRect = sourceRect
        self.scaleFactor = scaleFactor
    }

    /// Converts the CGImage to NSImage for clipboard/UI display.
    /// Scales to logical pixels based on the capture's scale factor.
    var nsImage: NSImage {
        NSImage(cgImage: image, size: NSSize(
            width: CGFloat(image.width) / scaleFactor,
            height: CGFloat(image.height) / scaleFactor
        ))
    }

    /// Image dimensions in pixels.
    var pixelSize: CGSize {
        CGSize(width: image.width, height: image.height)
    }

    /// Image dimensions in logical points.
    var pointSize: CGSize {
        CGSize(
            width: CGFloat(image.width) / scaleFactor,
            height: CGFloat(image.height) / scaleFactor
        )
    }
}
