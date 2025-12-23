import Foundation
import CoreGraphics

// MARK: - CounterToolHandler (T097, T098, T100)

/// Handles counter tool interactions for placing numbered callouts.
/// Manages auto-incrementing counter state independent of annotation deletions.
@MainActor
final class CounterToolHandler: ObservableObject {
    // MARK: - Properties

    /// The next number to assign to a new counter.
    /// This increments monotonically regardless of deletions (T100).
    @Published private(set) var nextNumber: Int = 1

    /// Reference to the tool configuration for color and size.
    private let toolConfig: ToolConfiguration

    /// Default counter circle size.
    static let defaultSize: CGFloat = 28

    // MARK: - Initialization

    init(toolConfig: ToolConfiguration) {
        self.toolConfig = toolConfig
    }

    // MARK: - Counter Creation (T098)

    /// Creates a counter annotation at the specified position.
    /// - Parameter position: The center position for the counter circle.
    /// - Returns: A new CounterAnnotation with auto-incremented number.
    func createCounter(at position: CGPoint) -> CounterAnnotation {
        let counter = CounterAnnotation(
            number: nextNumber,
            position: position,
            color: toolConfig.color,
            size: Self.defaultSize
        )

        // Auto-increment for next counter (T098)
        nextNumber += 1

        return counter
    }

    /// Resets the counter sequence back to 1.
    /// Call this when starting a new document or when explicitly requested.
    func resetCounter() {
        nextNumber = 1
    }

    // MARK: - Click Handling

    /// Handles a click on the canvas when the counter tool is active.
    /// - Parameters:
    ///   - location: The click location in canvas coordinates.
    ///   - document: The annotation document to add the counter to.
    func handleClick(at location: CGPoint, document: AnnotationDocument) {
        let counter = createCounter(at: location)
        document.addAnnotation(counter)
    }
}
