import Foundation
import CoreGraphics

// MARK: - RecognitionResult (T032)

/// Aggregated result from text recognition.
struct RecognitionResult: Sendable {
    /// Individual recognized text blocks.
    let texts: [RecognizedText]

    /// All recognized text concatenated with newlines.
    let fullText: String

    /// How long the recognition took.
    let processingTime: TimeInterval

    /// Size of the source image for coordinate conversion.
    let sourceImageSize: CGSize

    /// Creates a new recognition result.
    /// - Parameters:
    ///   - texts: Individual recognized text blocks.
    ///   - processingTime: How long the recognition took.
    ///   - sourceImageSize: Size of the source image.
    init(
        texts: [RecognizedText],
        processingTime: TimeInterval = 0,
        sourceImageSize: CGSize
    ) {
        self.texts = texts
        self.fullText = texts.map { $0.text }.joined(separator: "\n")
        self.processingTime = processingTime
        self.sourceImageSize = sourceImageSize
    }

    /// Whether any text was recognized.
    var hasText: Bool {
        !texts.isEmpty
    }

    /// Average confidence across all recognized text blocks.
    var averageConfidence: Float {
        guard !texts.isEmpty else { return 0 }
        let total = texts.reduce(0) { $0 + $1.confidence }
        return total / Float(texts.count)
    }

    /// Number of text blocks with high confidence.
    var highConfidenceCount: Int {
        texts.filter { $0.isHighConfidence }.count
    }
}
