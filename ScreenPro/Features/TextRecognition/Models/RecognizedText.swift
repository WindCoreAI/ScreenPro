import Foundation
import CoreGraphics

// MARK: - RecognizedText (T031)

/// Represents a single recognized text block from OCR.
struct RecognizedText: Identifiable, Sendable {
    /// Unique identifier for this text block.
    let id: UUID

    /// The recognized text content.
    let text: String

    /// Recognition confidence (0.0 to 1.0).
    let confidence: Float

    /// Normalized bounding box in Vision coordinates (0.0 to 1.0).
    /// Origin is bottom-left, Y increases upward.
    let boundingBox: CGRect

    /// Creates a new recognized text block.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID).
    ///   - text: The recognized text content.
    ///   - confidence: Recognition confidence (0.0 to 1.0).
    ///   - boundingBox: Normalized bounding box in Vision coordinates.
    init(
        id: UUID = UUID(),
        text: String,
        confidence: Float,
        boundingBox: CGRect
    ) {
        self.id = id
        self.text = text
        self.confidence = max(0, min(1, confidence))
        self.boundingBox = boundingBox
    }

    /// Whether this text has high confidence (>= 0.5).
    var isHighConfidence: Bool {
        confidence >= 0.5
    }

    /// Converts the Vision bounding box to image coordinates.
    /// - Parameter imageSize: The size of the source image.
    /// - Returns: The bounding box in image coordinates (origin top-left).
    func imageRect(for imageSize: CGSize) -> CGRect {
        let x = boundingBox.origin.x * imageSize.width
        let y = (1 - boundingBox.origin.y - boundingBox.height) * imageSize.height
        let width = boundingBox.width * imageSize.width
        let height = boundingBox.height * imageSize.height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
