import Foundation
import CoreGraphics
import SwiftUI

// MARK: - BlurToolHandler (T040, T041)

/// Handles blur/pixelate annotation creation through drag gestures.
/// Creates BlurAnnotation instances when user drags on the canvas.
@MainActor
final class BlurToolHandler: ObservableObject {
    // MARK: - Published Properties

    /// Whether a drag operation is currently in progress.
    @Published private(set) var isDragging: Bool = false

    /// Start point of the current drag operation.
    @Published private(set) var startPoint: CGPoint?

    /// Current point during drag operation.
    @Published private(set) var currentPoint: CGPoint?

    // MARK: - Properties

    /// Reference to tool configuration for blur settings.
    private weak var toolConfig: ToolConfiguration?

    /// Reference to the document for adding annotations.
    private weak var document: AnnotationDocument?

    /// The type of blur being created.
    var blurType: BlurType = .gaussian

    // MARK: - Constants

    /// Minimum drag size to create a blur region (5x5 points per spec).
    private static let minimumSize: CGFloat = 5

    // MARK: - Initialization

    init(toolConfig: ToolConfiguration, document: AnnotationDocument) {
        self.toolConfig = toolConfig
        self.document = document
    }

    // MARK: - Drag Handling

    /// Begins a drag operation at the specified point.
    /// - Parameter point: The starting point in canvas coordinates.
    func beginDrag(at point: CGPoint) {
        startPoint = point
        currentPoint = point
        isDragging = true
    }

    /// Updates the current drag position.
    /// - Parameter point: The current point in canvas coordinates.
    func updateDrag(to point: CGPoint) {
        guard isDragging else { return }
        currentPoint = point
    }

    /// Ends the drag operation and creates a blur annotation if valid.
    /// - Parameter point: The ending point in canvas coordinates.
    /// - Returns: The created BlurAnnotation, or nil if the region was too small.
    @discardableResult
    func endDrag(at point: CGPoint) -> BlurAnnotation? {
        defer {
            // Reset state
            startPoint = nil
            currentPoint = nil
            isDragging = false
        }

        guard let start = startPoint else { return nil }

        // Calculate bounds
        let bounds = calculateBounds(from: start, to: point)

        // Check minimum size
        guard bounds.width >= Self.minimumSize && bounds.height >= Self.minimumSize else {
            return nil
        }

        // Get intensity from tool config
        let intensity = toolConfig?.blurIntensity ?? 0.5

        // Create the blur annotation
        let blur = BlurAnnotation(
            bounds: bounds,
            blurType: blurType,
            intensity: intensity
        )

        // Add to document
        document?.addAnnotation(blur)

        return blur
    }

    /// Cancels the current drag operation without creating an annotation.
    func cancelDrag() {
        startPoint = nil
        currentPoint = nil
        isDragging = false
    }

    // MARK: - Helpers

    private func calculateBounds(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    // MARK: - Preview Support (T041)

    /// Returns the current preview bounds for rendering.
    /// - Returns: The preview bounds if dragging, nil otherwise.
    var previewBounds: CGRect? {
        guard isDragging,
              let start = startPoint,
              let current = currentPoint else {
            return nil
        }
        return calculateBounds(from: start, to: current)
    }

    /// Creates a preview blur annotation for display during drag.
    /// - Returns: A BlurAnnotation representing the preview, or nil if not dragging.
    var previewBlur: BlurAnnotation? {
        guard let bounds = previewBounds else { return nil }

        return BlurAnnotation(
            bounds: bounds,
            blurType: blurType,
            intensity: toolConfig?.blurIntensity ?? 0.5
        )
    }
}

// MARK: - Blur Preview View (T041)

/// SwiftUI view for rendering blur region preview during drag.
struct BlurPreviewView: View {
    let bounds: CGRect
    let blurType: BlurType
    let scale: CGFloat

    var body: some View {
        let displayBounds = CGRect(
            x: bounds.origin.x * scale,
            y: bounds.origin.y * scale,
            width: bounds.width * scale,
            height: bounds.height * scale
        )

        ZStack {
            // Semi-transparent overlay
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: displayBounds.width, height: displayBounds.height)
                .position(x: displayBounds.midX, y: displayBounds.midY)

            // Dashed border
            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .foregroundColor(Color.blue.opacity(0.8))
                .frame(width: displayBounds.width, height: displayBounds.height)
                .position(x: displayBounds.midX, y: displayBounds.midY)

            // Blur type indicator
            blurTypeIcon
                .position(x: displayBounds.midX, y: displayBounds.midY)
        }
    }

    @ViewBuilder
    private var blurTypeIcon: some View {
        switch blurType {
        case .gaussian:
            Image(systemName: "drop.fill")
                .font(.title2)
                .foregroundColor(.blue.opacity(0.7))

        case .pixelate:
            Image(systemName: "square.grid.3x3")
                .font(.title2)
                .foregroundColor(.blue.opacity(0.7))
        }
    }
}
