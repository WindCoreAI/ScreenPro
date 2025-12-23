import Foundation
import CoreGraphics
import AppKit

// MARK: - ThumbnailGenerator

/// Generates thumbnails from full-resolution captures.
/// Actor-isolated for thread-safe async generation.
actor ThumbnailGenerator {
    // MARK: - Thumbnail Generation

    /// Generates a thumbnail from a CGImage.
    /// - Parameters:
    ///   - image: The source image (full resolution).
    ///   - maxPixelSize: Maximum dimension in pixels (default 240).
    ///   - scaleFactor: Retina scale factor (default 2.0).
    /// - Returns: The generated thumbnail image, or nil if generation fails.
    nonisolated func generateThumbnail(
        from image: CGImage,
        maxPixelSize: Int = 240,
        scaleFactor: CGFloat = 2.0
    ) async -> CGImage? {
        // Perform scaling on background thread
        await Task.detached(priority: .userInitiated) {
            self.scaleCGImage(image, maxPixelSize: maxPixelSize)
        }.value
    }

    // MARK: - Private Methods

    /// Scales a CGImage to fit within the specified maximum pixel size.
    /// - Parameters:
    ///   - image: The source image.
    ///   - maxPixelSize: Maximum dimension (width or height).
    /// - Returns: The scaled image, or nil if scaling fails.
    private nonisolated func scaleCGImage(
        _ image: CGImage,
        maxPixelSize: Int
    ) -> CGImage? {
        let sourceWidth = CGFloat(image.width)
        let sourceHeight = CGFloat(image.height)

        // Calculate scale factor maintaining aspect ratio
        let scale: CGFloat
        if sourceWidth > sourceHeight {
            scale = min(1.0, CGFloat(maxPixelSize) / sourceWidth)
        } else {
            scale = min(1.0, CGFloat(maxPixelSize) / sourceHeight)
        }

        // Don't upscale
        guard scale < 1.0 else {
            return image
        }

        let scaledWidth = Int(sourceWidth * scale)
        let scaledHeight = Int(sourceHeight * scale)

        // Ensure valid dimensions
        guard scaledWidth > 0, scaledHeight > 0 else {
            return nil
        }

        // Get color space
        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }

        // Create graphics context
        guard let context = CGContext(
            data: nil,
            width: scaledWidth,
            height: scaledHeight,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: image.bitmapInfo.rawValue
        ) else {
            return nil
        }

        // Use high-quality interpolation for downsampling
        context.interpolationQuality = .high

        // Draw scaled image
        let rect = CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight)
        context.draw(image, in: rect)

        return context.makeImage()
    }
}

// MARK: - ThumbnailGenerator Preview Helper

extension ThumbnailGenerator {
    /// Creates a placeholder thumbnail for preview/testing.
    /// - Parameters:
    ///   - size: The size of the placeholder.
    ///   - color: The fill color.
    /// - Returns: A solid color image.
    nonisolated func createPlaceholder(
        size: CGSize,
        color: NSColor = .gray
    ) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
}
