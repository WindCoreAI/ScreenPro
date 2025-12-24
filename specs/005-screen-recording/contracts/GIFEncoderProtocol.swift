// MARK: - GIFEncoderProtocol
// Contract for GIF Encoding
// Feature: 005-screen-recording

import Foundation
import CoreGraphics

/// Protocol for GIF encoding operations.
/// Implementations should be thread-safe and can be called from background threads.
protocol GIFEncoderProtocol {
    /// Encode an array of frames into an animated GIF file.
    /// - Parameters:
    ///   - frames: Array of CGImage frames to encode
    ///   - frameDelay: Delay between frames in seconds
    ///   - loopCount: Number of times to loop (0 = infinite)
    ///   - url: Destination URL for the GIF file
    /// - Throws: GIFEncoderError if encoding fails
    static func encode(
        frames: [CGImage],
        frameDelay: Double,
        loopCount: Int,
        to url: URL
    ) throws

    /// Reduce the number of frames to achieve a target FPS.
    /// - Parameters:
    ///   - frames: Original array of frames
    ///   - targetFPS: Desired output frame rate
    ///   - sourceFPS: Original capture frame rate
    /// - Returns: Reduced array of frames
    static func reduceFrames(
        _ frames: [CGImage],
        targetFPS: Int,
        sourceFPS: Int
    ) -> [CGImage]
}

/// Errors that can occur during GIF encoding
enum GIFEncoderError: LocalizedError {
    /// No frames provided for encoding
    case noFrames

    /// Failed to create the GIF destination
    case failedToCreateDestination

    /// Failed to finalize the GIF file
    case failedToFinalize

    /// Invalid frame delay value
    case invalidFrameDelay

    var errorDescription: String? {
        switch self {
        case .noFrames:
            return "No frames to encode"
        case .failedToCreateDestination:
            return "Failed to create GIF destination"
        case .failedToFinalize:
            return "Failed to finalize GIF"
        case .invalidFrameDelay:
            return "Invalid frame delay value"
        }
    }
}
