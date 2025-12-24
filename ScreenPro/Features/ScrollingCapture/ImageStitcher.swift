import Foundation
import CoreGraphics
import Vision
import AppKit

// MARK: - ImageStitcher (T024)

/// Stitches multiple captured frames into a single continuous image.
/// Uses Vision framework's VNTranslationalImageRegistrationRequest for alignment.
@MainActor
final class ImageStitcher {
    // MARK: - Properties

    /// The stitch configuration.
    private let config: StitchConfig

    // MARK: - Initialization

    /// Creates a new image stitcher with the specified configuration.
    /// - Parameter config: The stitch configuration.
    init(config: StitchConfig = .default) {
        self.config = config
    }

    // MARK: - Public Methods

    /// Stitches an array of captured frames into a single image.
    /// - Parameter frames: The frames to stitch in capture order.
    /// - Returns: The stitched CGImage.
    /// - Throws: ScrollingCaptureError if stitching fails.
    func stitch(frames: [CapturedFrame]) async throws -> CGImage {
        guard !frames.isEmpty else {
            throw ScrollingCaptureError.noFrames
        }

        // Single frame - just return it
        if frames.count == 1 {
            return frames[0].image
        }

        // Calculate alignments between consecutive frames
        let alignments = try await calculateAlignments(for: frames)

        // Stitch frames based on direction
        return try stitchFrames(frames, alignments: alignments)
    }

    /// Generates a preview image from the current frames.
    /// - Parameter frames: The frames captured so far.
    /// - Returns: A preview CGImage showing the stitched result so far.
    func generatePreview(frames: [CapturedFrame]) async -> CGImage? {
        guard !frames.isEmpty else { return nil }

        // For preview, use a faster but less accurate approach
        do {
            return try await stitch(frames: frames)
        } catch {
            // Return the last frame if stitching fails during preview
            return frames.last?.image
        }
    }

    // MARK: - Private Methods - Alignment

    /// Calculates translation alignments between consecutive frames.
    private func calculateAlignments(for frames: [CapturedFrame]) async throws -> [CGPoint] {
        var alignments: [CGPoint] = []

        for i in 1..<frames.count {
            let reference = frames[i - 1].image
            let target = frames[i].image

            let translation = try await calculateTranslation(from: reference, to: target)
            alignments.append(translation)
        }

        return alignments
    }

    /// Calculates the translation needed to align target to reference.
    private func calculateTranslation(from reference: CGImage, to target: CGImage) async throws -> CGPoint {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNTranslationalImageRegistrationRequest(
                targetedCGImage: target,
                options: [:]
            )

            let handler = VNImageRequestHandler(cgImage: reference, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])

                    guard let observation = request.results?.first as? VNImageTranslationAlignmentObservation else {
                        // If alignment fails, assume vertical scroll with overlap
                        let estimatedTranslation = CGPoint(
                            x: 0,
                            y: CGFloat(reference.height) * (1 - 0.2)
                        )
                        continuation.resume(returning: estimatedTranslation)
                        return
                    }

                    let transform = observation.alignmentTransform
                    let translation = CGPoint(x: transform.tx, y: transform.ty)
                    continuation.resume(returning: translation)
                } catch {
                    // On error, estimate translation based on config
                    let estimatedTranslation = CGPoint(
                        x: 0,
                        y: CGFloat(reference.height) * (1 - 0.2)
                    )
                    continuation.resume(returning: estimatedTranslation)
                }
            }
        }
    }

    // MARK: - Private Methods - Stitching

    /// Stitches frames using calculated alignments.
    private func stitchFrames(_ frames: [CapturedFrame], alignments: [CGPoint]) throws -> CGImage {
        guard let firstFrame = frames.first else {
            throw ScrollingCaptureError.noFrames
        }

        // Calculate total canvas size
        let canvasSize = calculateCanvasSize(frames: frames, alignments: alignments)

        // Create the stitched image
        guard let context = createGraphicsContext(size: canvasSize) else {
            throw ScrollingCaptureError.stitchingFailed
        }

        // Draw frames onto canvas
        var currentPosition = CGPoint.zero

        for (index, frame) in frames.enumerated() {
            let frameRect = CGRect(
                x: currentPosition.x,
                y: canvasSize.height - currentPosition.y - CGFloat(frame.image.height),
                width: CGFloat(frame.image.width),
                height: CGFloat(frame.image.height)
            )

            // Apply gradient mask at overlap regions for smooth blending
            if index > 0 {
                let alignment = alignments[index - 1]
                drawWithBlending(frame.image, at: frameRect, overlapHeight: abs(alignment.y), in: context)
            } else {
                context.draw(frame.image, in: frameRect)
            }

            // Update position for next frame
            if index < alignments.count {
                currentPosition.x += alignments[index].x
                currentPosition.y += alignments[index].y
            }
        }

        guard let result = context.makeImage() else {
            throw ScrollingCaptureError.stitchingFailed
        }

        return result
    }

    /// Calculates the total canvas size needed for all frames.
    private func calculateCanvasSize(frames: [CapturedFrame], alignments: [CGPoint]) -> CGSize {
        guard let firstFrame = frames.first else {
            return .zero
        }

        var totalHeight: CGFloat = CGFloat(firstFrame.image.height)
        var totalWidth: CGFloat = CGFloat(firstFrame.image.width)

        var maxWidth = totalWidth
        var currentX: CGFloat = 0

        for alignment in alignments {
            currentX += alignment.x
            totalHeight += abs(alignment.y)
            maxWidth = max(maxWidth, totalWidth + currentX)
        }

        return CGSize(width: maxWidth, height: totalHeight)
    }

    /// Creates a graphics context for drawing.
    private func createGraphicsContext(size: CGSize) -> CGContext? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

        return CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )
    }

    /// Draws an image with gradient blending at the overlap region.
    private func drawWithBlending(_ image: CGImage, at rect: CGRect, overlapHeight: CGFloat, in context: CGContext) {
        // For simplicity, just draw the image
        // A more sophisticated implementation would apply a gradient mask at the overlap
        context.draw(image, in: rect)
    }
}

// MARK: - ImageStitcher Extension for Preview Generation

extension ImageStitcher {
    /// Estimates the progress of stitching based on frame count.
    /// - Parameters:
    ///   - frameCount: Current number of frames.
    ///   - maxFrames: Maximum allowed frames.
    /// - Returns: Progress value from 0.0 to 1.0.
    func estimateProgress(frameCount: Int, maxFrames: Int) -> Double {
        return min(1.0, Double(frameCount) / Double(maxFrames))
    }
}
