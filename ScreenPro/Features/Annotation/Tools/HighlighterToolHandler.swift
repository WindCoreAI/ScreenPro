import Foundation
import CoreGraphics
import SwiftUI
import Combine

// MARK: - HighlighterToolHandler (T090, T091)

/// Handles highlighter annotation creation through continuous drag tracking.
/// Collects points during drag and creates HighlighterAnnotation on completion.
@MainActor
final class HighlighterToolHandler: ObservableObject {
    // MARK: - Published Properties

    /// Points collected during the current drag.
    @Published private(set) var currentPoints: [CGPoint] = []

    /// Whether a drag operation is in progress.
    @Published private(set) var isDragging: Bool = false

    // MARK: - Properties

    /// Reference to tool configuration for color and stroke settings.
    private weak var toolConfig: ToolConfiguration?

    /// Reference to the document for adding annotations.
    private weak var document: AnnotationDocument?

    /// Minimum distance between consecutive points (reduces point count).
    private let minPointDistance: CGFloat = 3

    // MARK: - Initialization

    init(toolConfig: ToolConfiguration, document: AnnotationDocument) {
        self.toolConfig = toolConfig
        self.document = document
    }

    // MARK: - Drag Handling (T090, T091)

    /// Called when drag begins.
    /// - Parameter point: The starting point in canvas coordinates.
    func beginDrag(at point: CGPoint) {
        currentPoints = [point]
        isDragging = true
    }

    /// Called during drag to update the current position.
    /// - Parameter point: The current point in canvas coordinates.
    func continueDrag(to point: CGPoint) {
        guard isDragging, let lastPoint = currentPoints.last else { return }

        // Only add point if it's far enough from the last point
        let distance = hypot(point.x - lastPoint.x, point.y - lastPoint.y)
        if distance >= minPointDistance {
            currentPoints.append(point)
        }
    }

    /// Called when drag ends.
    /// - Parameter point: The ending point in canvas coordinates.
    func endDrag(at point: CGPoint) {
        guard isDragging else { return }

        // Add final point
        if let lastPoint = currentPoints.last,
           hypot(point.x - lastPoint.x, point.y - lastPoint.y) >= 1 {
            currentPoints.append(point)
        }

        // Create annotation if we have enough points
        createAnnotation()

        // Reset state
        currentPoints = []
        isDragging = false
    }

    /// Cancels the current drag operation without creating an annotation.
    func cancelDrag() {
        currentPoints = []
        isDragging = false
    }

    // MARK: - Annotation Creation

    /// Creates a highlighter annotation from the collected points.
    private func createAnnotation() {
        guard currentPoints.count >= 2,
              let toolConfig = toolConfig,
              let document = document else { return }

        let highlighter = HighlighterAnnotation(
            points: currentPoints,
            color: toolConfig.color,
            strokeWidth: max(toolConfig.strokeWidth * 5, 15) // Highlighter is thicker than normal strokes
        )

        document.addAnnotation(highlighter)
    }
}

// MARK: - Highlighter Preview View

/// SwiftUI view for rendering the highlighter preview during creation.
struct HighlighterPreviewView: View {
    let points: [CGPoint]
    let color: Color
    let strokeWidth: CGFloat
    let scale: CGFloat

    var body: some View {
        if points.count >= 2 {
            Path { path in
                let scaledPoints = points.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
                path.move(to: scaledPoints[0])
                for i in 1..<scaledPoints.count {
                    path.addLine(to: scaledPoints[i])
                }
            }
            .stroke(
                color.opacity(0.4),
                style: StrokeStyle(
                    lineWidth: strokeWidth * scale,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .blendMode(.multiply)
        }
    }
}

// MARK: - Highlighter Tool Extension for Canvas

extension AnnotationCanvasView {
    /// Creates a highlighter tool handler for this canvas.
    func createHighlighterHandler() -> HighlighterToolHandler {
        HighlighterToolHandler(toolConfig: toolConfig, document: document)
    }
}
