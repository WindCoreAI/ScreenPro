import Foundation
import Vision
import AppKit

// MARK: - TextRecognitionService (T034)

/// Service for performing OCR text recognition using Vision framework.
@MainActor
final class TextRecognitionService: ObservableObject {
    // MARK: - Published Properties

    /// Whether OCR is currently processing.
    @Published private(set) var isProcessing = false

    /// The most recent recognition result.
    @Published private(set) var lastResult: RecognitionResult?

    // MARK: - Properties

    /// Languages to use for recognition.
    private var recognitionLanguages: [String]

    /// Whether to copy text to clipboard automatically.
    private var autoCopyToClipboard: Bool

    // MARK: - Initialization

    /// Creates a new text recognition service.
    /// - Parameters:
    ///   - languages: Language identifiers to use (defaults to common languages).
    ///   - autoCopy: Whether to auto-copy recognized text to clipboard.
    init(
        languages: [String] = LanguageOption.defaults.map { $0.rawValue },
        autoCopy: Bool = true
    ) {
        self.recognitionLanguages = languages
        self.autoCopyToClipboard = autoCopy
    }

    // MARK: - Configuration

    /// Updates the recognition languages.
    /// - Parameter languages: New language identifiers.
    func setLanguages(_ languages: [String]) {
        self.recognitionLanguages = languages
    }

    /// Updates the auto-copy setting.
    /// - Parameter enabled: Whether to auto-copy.
    func setAutoCopy(_ enabled: Bool) {
        self.autoCopyToClipboard = enabled
    }

    // MARK: - Recognition Methods

    /// Recognizes text in the given image.
    /// - Parameter image: The image to analyze.
    /// - Returns: The recognition result with all found text.
    /// - Throws: TextRecognitionError if recognition fails.
    func recognizeText(in image: CGImage) async throws -> RecognitionResult {
        isProcessing = true
        defer { isProcessing = false }

        let startTime = Date()

        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RecognitionResult, Error>) in
            performRecognition(on: image, startTime: startTime) { result in
                switch result {
                case .success(let recognitionResult):
                    continuation.resume(returning: recognitionResult)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }

        lastResult = result
        return result
    }

    /// Recognizes text and copies it to the clipboard.
    /// - Parameter image: The image to analyze.
    /// - Returns: The recognized text (also copied to clipboard).
    /// - Throws: TextRecognitionError if recognition fails.
    @discardableResult
    func recognizeAndCopy(from image: CGImage) async throws -> String {
        let result = try await recognizeText(in: image)

        guard result.hasText else {
            throw TextRecognitionError.noTextFound
        }

        // Copy to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result.fullText, forType: .string)

        return result.fullText
    }

    // MARK: - Private Methods

    /// Performs the actual Vision recognition.
    private func performRecognition(
        on image: CGImage,
        startTime: Date,
        completion: @escaping (Result<RecognitionResult, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(.failure(TextRecognitionError.recognitionFailed))
                return
            }

            // Create the text recognition request
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    completion(.failure(TextRecognitionError.recognitionFailed))
                    print("Vision error: \(error)")
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    completion(.failure(TextRecognitionError.recognitionFailed))
                    return
                }

                // Convert observations to our model
                let texts = observations.compactMap { observation -> RecognizedText? in
                    guard let candidate = observation.topCandidates(1).first else {
                        return nil
                    }

                    return RecognizedText(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }

                let processingTime = Date().timeIntervalSince(startTime)
                let result = RecognitionResult(
                    texts: texts,
                    processingTime: processingTime,
                    sourceImageSize: CGSize(width: image.width, height: image.height)
                )

                completion(.success(result))
            }

            // Configure the request
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = self.recognitionLanguages

            // Perform the request
            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                completion(.failure(TextRecognitionError.recognitionFailed))
            }
        }
    }
}
