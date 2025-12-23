import Foundation
import CoreGraphics
import AppKit
import UniformTypeIdentifiers

// MARK: - ExportImageFormat

/// Supported image export formats for annotation editor.
/// This extends the base ImageFormat with additional properties for export.
enum ExportImageFormat: String, CaseIterable, Sendable {
    case png = "PNG"
    case jpeg = "JPEG"
    case tiff = "TIFF"
    case heic = "HEIC"

    /// The file extension for this format.
    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .tiff: return "tiff"
        case .heic: return "heic"
        }
    }

    /// The UTType for this format.
    var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .tiff: return .tiff
        case .heic: return .heic
        }
    }

    /// The NSBitmapImageRep file type.
    var bitmapFileType: NSBitmapImageRep.FileType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .tiff: return .tiff
        case .heic: return .png // Fallback, HEIC uses ImageIO
        }
    }

    /// MIME type for this format.
    var mimeType: String {
        switch self {
        case .png: return "image/png"
        case .jpeg: return "image/jpeg"
        case .tiff: return "image/tiff"
        case .heic: return "image/heic"
        }
    }

    /// Converts from the settings ImageFormat.
    init(from settingsFormat: ImageFormat) {
        switch settingsFormat {
        case .png: self = .png
        case .jpeg: self = .jpeg
        case .tiff: self = .tiff
        case .heic: self = .heic
        }
    }
}

// MARK: - ExportRenderer (T030, T042, T043)

/// Renders annotated images for export.
/// Composes base image with all annotations into a final CGImage.
/// Blur annotations are destructively applied during export for privacy.
@MainActor
final class ExportRenderer {
    // MARK: - Properties

    private let document: AnnotationDocument
    private let blurRenderer = BlurRenderer()

    // MARK: - Initialization

    init(document: AnnotationDocument) {
        self.document = document
    }

    // MARK: - Rendering

    /// Renders the document to a CGImage.
    /// - Parameter scale: Scale factor for output resolution (1.0 = original size).
    /// - Returns: The rendered image, or nil on failure.
    func render(scale: CGFloat = 1.0) -> CGImage? {
        let width = Int(document.canvasSize.width * scale)
        let height = Int(document.canvasSize.height * scale)

        // First, apply blur annotations destructively to the base image
        let baseWithBlur = applyBlurAnnotations(to: document.baseImage, scale: scale)

        guard let context = createContext(width: width, height: height) else {
            return nil
        }

        // Draw base image (with blur applied)
        context.draw(baseWithBlur, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Apply scale for annotation rendering
        context.scaleBy(x: scale, y: scale)

        // Render non-blur annotations in z-order
        let sortedAnnotations = document.annotations.sorted { $0.zIndex < $1.zIndex }
        for annotation in sortedAnnotations {
            // Skip blur annotations (already applied destructively)
            if annotation is BlurAnnotation { continue }

            context.saveGState()
            annotation.render(in: context, scale: scale)
            context.restoreGState()
        }

        return context.makeImage()
    }

    // MARK: - Blur Application (T043)

    /// Applies blur annotations destructively to the base image.
    /// - Parameters:
    ///   - image: The source image.
    ///   - scale: Scale factor for output resolution.
    /// - Returns: The image with blur effects applied.
    private func applyBlurAnnotations(to image: CGImage, scale: CGFloat) -> CGImage {
        // Extract blur annotations
        let blurAnnotations = document.annotations.compactMap { $0 as? BlurAnnotation }

        guard !blurAnnotations.isEmpty else { return image }

        // Sort by z-index and apply
        let sortedBlurs = blurAnnotations.sorted { $0.zIndex < $1.zIndex }

        // Apply blur using BlurRenderer
        if let blurredImage = blurRenderer.applyBlurAnnotations(to: image, annotations: sortedBlurs) {
            return blurredImage
        }

        return image
    }

    /// Exports the document to the specified format.
    /// - Parameters:
    ///   - format: The image format for export.
    ///   - quality: JPEG compression quality (0.0-1.0), ignored for other formats.
    /// - Returns: Image data, or nil on failure.
    func export(format: ExportImageFormat, quality: CGFloat = 0.9) -> Data? {
        guard let image = render() else { return nil }

        switch format {
        case .heic:
            return exportHEIC(image: image, quality: quality)
        default:
            return exportBitmap(image: image, format: format, quality: quality)
        }
    }

    // MARK: - Private Methods

    private func createContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    private func exportBitmap(image: CGImage, format: ExportImageFormat, quality: CGFloat) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: image)

        var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]

        if format == .jpeg {
            properties[.compressionFactor] = quality
        }

        return bitmapRep.representation(using: format.bitmapFileType, properties: properties)
    }

    private func exportHEIC(image: CGImage, quality: CGFloat) -> Data? {
        let data = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]

        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return data as Data
    }
}

// MARK: - AnnotationDocument Export Extension (T031)

extension AnnotationDocument {
    /// Exports the annotated image to the specified format.
    /// - Parameters:
    ///   - format: The image format for export.
    ///   - quality: JPEG compression quality (0.0-1.0), ignored for other formats.
    /// - Returns: Image data, or nil on failure.
    func export(format: ExportImageFormat, quality: CGFloat = 0.9) -> Data? {
        let renderer = ExportRenderer(document: self)
        return renderer.export(format: format, quality: quality)
    }

    /// Renders the document with blur effects applied (for privacy).
    /// Blur annotations are destructively applied to the base image.
    /// - Parameter scale: Scale factor for output resolution.
    /// - Returns: The rendered image with blur, or nil on failure.
    func renderWithBlur(scale: CGFloat = 1.0) -> CGImage? {
        // ExportRenderer now handles blur application automatically
        let renderer = ExportRenderer(document: self)
        return renderer.render(scale: scale)
    }
}
