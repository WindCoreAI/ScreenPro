import Foundation

// MARK: - Text Recognition Error (T014)

/// Errors that can occur during OCR text recognition operations
enum TextRecognitionError: LocalizedError {
    /// The Vision framework failed to process the image
    case recognitionFailed
    /// No text was found in the image
    case noTextFound
    /// The provided image is invalid or corrupted
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .recognitionFailed:
            return "Text recognition failed to process the image."
        case .noTextFound:
            return "No text was found in the selected region."
        case .invalidImage:
            return "The image could not be processed for text recognition."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .recognitionFailed:
            return "Try capturing a different region or ensure the text is clearly visible."
        case .noTextFound:
            return "Select a region that contains visible text. Ensure the text is not too small or blurry."
        case .invalidImage:
            return "Try capturing the region again."
        }
    }
}
