import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - GIFEncoderError

/// Errors that can occur during GIF encoding
enum GIFEncoderError: LocalizedError {
    /// No frames were provided for encoding
    case noFrames

    /// Failed to create the image destination
    case failedToCreateDestination

    /// Failed to finalize the GIF
    case failedToFinalize

    var errorDescription: String? {
        switch self {
        case .noFrames:
            return "No frames to encode into GIF"
        case .failedToCreateDestination:
            return "Failed to create GIF image destination"
        case .failedToFinalize:
            return "Failed to finalize GIF encoding"
        }
    }
}

// MARK: - GIFEncoderProtocol

/// Protocol for GIF encoding operations
protocol GIFEncoderProtocol {
    /// Encodes an array of frames into an animated GIF
    static func encode(frames: [CGImage], frameDelay: Double, loopCount: Int, to url: URL) throws

    /// Reduces frames from source FPS to target FPS
    static func reduceFrames(_ frames: [CGImage], targetFPS: Int, sourceFPS: Int) -> [CGImage]
}

// MARK: - GIFEncoder (T041)

/// Utility for encoding CGImage frames into animated GIF files using ImageIO
enum GIFEncoder: GIFEncoderProtocol {

    // MARK: - Encoding (T042)

    /// Encodes an array of CGImage frames into an animated GIF file
    /// - Parameters:
    ///   - frames: Array of CGImage frames to encode
    ///   - frameDelay: Delay between frames in seconds
    ///   - loopCount: Number of times to loop (0 = infinite)
    ///   - url: Output URL for the GIF file
    /// - Throws: GIFEncoderError if encoding fails
    static func encode(frames: [CGImage], frameDelay: Double, loopCount: Int, to url: URL) throws {
        guard !frames.isEmpty else {
            throw GIFEncoderError.noFrames
        }

        // Create image destination
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.gif.identifier as CFString,
            frames.count,
            nil
        ) else {
            throw GIFEncoderError.failedToCreateDestination
        }

        // Set file-level properties (loop count)
        let fileProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: loopCount
            ]
        ]
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)

        // Per-frame properties
        // Use unclamped delay time for delays < 0.1s (which GIF readers may otherwise clamp to 0.1s)
        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay,
                kCGImagePropertyGIFUnclampedDelayTime as String: frameDelay
            ]
        ]

        // Add each frame
        for frame in frames {
            CGImageDestinationAddImage(destination, frame, frameProperties as CFDictionary)
        }

        // Finalize
        guard CGImageDestinationFinalize(destination) else {
            throw GIFEncoderError.failedToFinalize
        }
    }

    // MARK: - Frame Reduction (T043)

    /// Reduces frames from source FPS to target FPS by sampling
    /// - Parameters:
    ///   - frames: Source frames at sourceFPS
    ///   - targetFPS: Desired output frame rate
    ///   - sourceFPS: Frame rate of source frames
    /// - Returns: Reduced array of frames at approximately targetFPS
    static func reduceFrames(_ frames: [CGImage], targetFPS: Int, sourceFPS: Int) -> [CGImage] {
        guard !frames.isEmpty else { return [] }
        guard sourceFPS > 0 else { return frames }
        guard targetFPS > 0 else { return frames.isEmpty ? [] : [frames[0]] }

        // If target FPS >= source FPS, keep all frames
        if targetFPS >= sourceFPS {
            return frames
        }

        // Calculate step: how many source frames per output frame
        let ratio = Double(sourceFPS) / Double(targetFPS)

        var reducedFrames: [CGImage] = []
        var nextIndex: Double = 0

        while Int(nextIndex) < frames.count {
            reducedFrames.append(frames[Int(nextIndex)])
            nextIndex += ratio
        }

        return reducedFrames
    }

    // MARK: - Frame Scaling

    /// Scales a CGImage to a new size
    /// - Parameters:
    ///   - image: The source image
    ///   - scale: Scale factor (0.5 = half size)
    /// - Returns: Scaled CGImage, or original if scaling fails
    static func scaleImage(_ image: CGImage, scale: CGFloat) -> CGImage {
        guard scale != 1.0, scale > 0 else { return image }

        let newWidth = Int(CGFloat(image.width) * scale)
        let newHeight = Int(CGFloat(image.height) * scale)

        guard newWidth > 0, newHeight > 0 else { return image }

        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) else {
            return image
        }

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: newWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        return context.makeImage() ?? image
    }

    // MARK: - Convenience Methods

    /// Encodes frames using a GIFConfig
    /// - Parameters:
    ///   - frames: Array of CGImage frames at source FPS
    ///   - config: GIF configuration including target frame rate and scale
    ///   - sourceFPS: The FPS of the source frames
    ///   - url: Output URL for the GIF file
    /// - Throws: GIFEncoderError if encoding fails
    static func encode(frames: [CGImage], config: GIFConfig, sourceFPS: Int, to url: URL) throws {
        guard !frames.isEmpty else {
            throw GIFEncoderError.noFrames
        }

        // Reduce frames to target FPS
        var processedFrames = reduceFrames(frames, targetFPS: config.frameRate, sourceFPS: sourceFPS)

        // Scale frames if needed
        if config.scale < 1.0 {
            processedFrames = processedFrames.map { scaleImage($0, scale: config.scale) }
        }

        // Encode with config settings
        try encode(
            frames: processedFrames,
            frameDelay: config.frameDelay,
            loopCount: config.loopCount,
            to: url
        )
    }

    // MARK: - Memory Management

    /// Estimates memory usage for storing frames
    /// - Parameters:
    ///   - frameCount: Number of frames
    ///   - width: Frame width in pixels
    ///   - height: Frame height in pixels
    /// - Returns: Estimated memory usage in bytes
    static func estimatedMemoryUsage(frameCount: Int, width: Int, height: Int) -> Int {
        // Each pixel is 4 bytes (RGBA)
        let bytesPerFrame = width * height * 4
        return bytesPerFrame * frameCount
    }

    /// Checks if the estimated memory usage exceeds a threshold
    /// - Parameters:
    ///   - frameCount: Number of frames
    ///   - width: Frame width
    ///   - height: Frame height
    ///   - threshold: Memory threshold in bytes (default 500MB)
    /// - Returns: True if memory usage would exceed threshold
    static func wouldExceedMemoryThreshold(
        frameCount: Int,
        width: Int,
        height: Int,
        threshold: Int = 500_000_000
    ) -> Bool {
        return estimatedMemoryUsage(frameCount: frameCount, width: width, height: height) > threshold
    }
}
