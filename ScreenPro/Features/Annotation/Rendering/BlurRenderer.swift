import Foundation
import CoreGraphics
import CoreImage
import AppKit

// MARK: - BlurRenderer (T037, T038)

/// Renders blur and pixelate effects using Core Image filters.
/// Used during export to destructively apply blur annotations.
final class BlurRenderer {
    // MARK: - Properties

    /// Shared CIContext for filter operations.
    private let ciContext: CIContext

    // MARK: - Constants

    /// Maximum blur radius for gaussian blur.
    private static let maxBlurRadius: CGFloat = 40

    /// Minimum pixelate scale.
    private static let minPixelateScale: CGFloat = 5

    /// Maximum pixelate scale.
    private static let maxPixelateScale: CGFloat = 50

    // MARK: - Initialization

    init() {
        // Use GPU-accelerated context if available
        self.ciContext = CIContext(options: [
            .useSoftwareRenderer: false,
            .highQualityDownsample: true
        ])
    }

    // MARK: - Gaussian Blur (T037)

    /// Applies gaussian blur to a region of the image.
    /// - Parameters:
    ///   - image: The source image.
    ///   - region: The region to blur (in image coordinates).
    ///   - intensity: Blur intensity (0.0 to 1.0).
    /// - Returns: The image with blur applied, or nil on failure.
    func applyGaussianBlur(to image: CGImage, region: CGRect, intensity: CGFloat) -> CGImage? {
        guard let ciImage = CIImage(cgImage: image) else { return nil }

        // Calculate blur radius from intensity
        let blurRadius = intensity * Self.maxBlurRadius

        // Create blur filter
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return nil }
        blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
        blurFilter.setValue(blurRadius, forKey: kCIInputRadiusKey)

        guard let blurredFullImage = blurFilter.outputImage else { return nil }

        // Crop the blurred region
        let blurredRegion = blurredFullImage.cropped(to: region)

        // Composite the blurred region back onto the original
        let composited = blurredRegion.composited(over: ciImage)

        // Crop to original image bounds (blur filter expands the image)
        let finalImage = composited.cropped(to: CGRect(origin: .zero, size: CGSize(
            width: image.width,
            height: image.height
        )))

        // Render to CGImage
        return ciContext.createCGImage(finalImage, from: finalImage.extent)
    }

    // MARK: - Pixelate (T038)

    /// Applies pixelate effect to a region of the image.
    /// - Parameters:
    ///   - image: The source image.
    ///   - region: The region to pixelate (in image coordinates).
    ///   - intensity: Pixelate intensity (0.0 to 1.0), affects block size.
    /// - Returns: The image with pixelate applied, or nil on failure.
    func applyPixelate(to image: CGImage, region: CGRect, intensity: CGFloat) -> CGImage? {
        guard let ciImage = CIImage(cgImage: image) else { return nil }

        // Calculate pixelate scale from intensity
        let scale = Self.minPixelateScale + intensity * (Self.maxPixelateScale - Self.minPixelateScale)

        // Create pixelate filter
        guard let pixelateFilter = CIFilter(name: "CIPixellate") else { return nil }

        // First crop to region
        let regionImage = ciImage.cropped(to: region)

        pixelateFilter.setValue(regionImage, forKey: kCIInputImageKey)
        pixelateFilter.setValue(scale, forKey: kCIInputScaleKey)
        pixelateFilter.setValue(CIVector(cgPoint: CGPoint(x: region.midX, y: region.midY)), forKey: kCIInputCenterKey)

        guard let pixelatedRegion = pixelateFilter.outputImage else { return nil }

        // Composite the pixelated region back onto the original
        let composited = pixelatedRegion.composited(over: ciImage)

        // Crop to original image bounds
        let finalImage = composited.cropped(to: CGRect(origin: .zero, size: CGSize(
            width: image.width,
            height: image.height
        )))

        // Render to CGImage
        return ciContext.createCGImage(finalImage, from: finalImage.extent)
    }

    // MARK: - Apply All Blur Annotations

    /// Applies all blur annotations to an image.
    /// This is used during export to destructively apply blur effects.
    /// - Parameters:
    ///   - image: The source image.
    ///   - annotations: Array of blur annotations to apply.
    /// - Returns: The image with all blur effects applied, or nil on failure.
    func applyBlurAnnotations(to image: CGImage, annotations: [BlurAnnotation]) -> CGImage? {
        var currentImage = image

        // Apply blur annotations in z-order
        let sortedAnnotations = annotations.sorted { $0.zIndex < $1.zIndex }

        for annotation in sortedAnnotations {
            // Convert bounds to image coordinates (CGImage origin is bottom-left)
            let imageHeight = CGFloat(image.height)
            let flippedBounds = CGRect(
                x: annotation.bounds.origin.x,
                y: imageHeight - annotation.bounds.maxY,
                width: annotation.bounds.width,
                height: annotation.bounds.height
            )

            let result: CGImage?

            switch annotation.blurType {
            case .gaussian:
                result = applyGaussianBlur(
                    to: currentImage,
                    region: flippedBounds,
                    intensity: annotation.intensity
                )

            case .pixelate:
                result = applyPixelate(
                    to: currentImage,
                    region: flippedBounds,
                    intensity: annotation.intensity
                )
            }

            if let newImage = result {
                currentImage = newImage
            }
        }

        return currentImage
    }
}

// MARK: - CIImage Extension

extension CIImage {
    /// Composites this image over another image.
    func composited(over background: CIImage) -> CIImage {
        guard let compositingFilter = CIFilter(name: "CISourceOverCompositing") else {
            return self
        }
        compositingFilter.setValue(self, forKey: kCIInputImageKey)
        compositingFilter.setValue(background, forKey: kCIInputBackgroundImageKey)
        return compositingFilter.outputImage ?? self
    }
}
