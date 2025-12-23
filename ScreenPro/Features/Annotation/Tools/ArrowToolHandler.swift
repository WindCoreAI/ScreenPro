import Foundation
import CoreGraphics
import SwiftUI

// MARK: - ArrowToolHandler (T025, T026)

/// Handles arrow annotation creation through drag gestures.
/// Creates ArrowAnnotation instances when user drags on the canvas.
@MainActor
final class ArrowToolHandler: ObservableObject {
    // MARK: - Published Properties

    /// Whether a drag operation is currently in progress.
    @Published private(set) var isDragging: Bool = false

    /// Start point of the current drag operation.
    @Published private(set) var startPoint: CGPoint?

    /// Current point during drag operation.
    @Published private(set) var currentPoint: CGPoint?

    // MARK: - Properties

    /// Reference to tool configuration for color and stroke settings.
    private weak var toolConfig: ToolConfiguration?

    /// Reference to the document for adding annotations.
    private weak var document: AnnotationDocument?

    // MARK: - Constants

    /// Minimum drag distance to create an arrow (5 points per spec).
    private static let minimumDragDistance: CGFloat = 5

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

    /// Ends the drag operation and creates an arrow if valid.
    /// - Parameter point: The ending point in canvas coordinates.
    /// - Returns: The created ArrowAnnotation, or nil if the drag was too short.
    @discardableResult
    func endDrag(at point: CGPoint) -> ArrowAnnotation? {
        defer {
            // Reset state
            startPoint = nil
            currentPoint = nil
            isDragging = false
        }

        guard let start = startPoint else { return nil }

        // Check minimum drag distance
        let distance = hypot(point.x - start.x, point.y - start.y)
        guard distance >= Self.minimumDragDistance else { return nil }

        // Create the arrow annotation
        let arrow = createArrow(from: start, to: point)

        // Add to document
        document?.addAnnotation(arrow)

        return arrow
    }

    /// Cancels the current drag operation without creating an annotation.
    func cancelDrag() {
        startPoint = nil
        currentPoint = nil
        isDragging = false
    }

    // MARK: - Arrow Creation

    /// Creates an ArrowAnnotation with current tool settings.
    /// - Parameters:
    ///   - start: The start point (tail).
    ///   - end: The end point (head).
    /// - Returns: A new ArrowAnnotation.
    private func createArrow(from start: CGPoint, to end: CGPoint) -> ArrowAnnotation {
        let color = toolConfig?.color ?? .red
        let strokeWidth = toolConfig?.strokeWidth ?? 3

        return ArrowAnnotation(
            startPoint: start,
            endPoint: end,
            style: .default,
            color: color,
            strokeWidth: strokeWidth
        )
    }

    // MARK: - Preview Support (T026)

    /// Returns the current preview state for rendering.
    /// - Returns: A tuple of start and end points if dragging, nil otherwise.
    var previewPoints: (start: CGPoint, end: CGPoint)? {
        guard isDragging,
              let start = startPoint,
              let current = currentPoint else {
            return nil
        }
        return (start, current)
    }

    /// Creates a preview arrow for display during drag.
    /// - Returns: An ArrowAnnotation representing the preview, or nil if not dragging.
    var previewArrow: ArrowAnnotation? {
        guard let points = previewPoints else { return nil }

        return ArrowAnnotation(
            startPoint: points.start,
            endPoint: points.end,
            style: .default,
            color: toolConfig?.color ?? .red,
            strokeWidth: toolConfig?.strokeWidth ?? 3
        )
    }
}

// MARK: - Arrow Preview View (T026)

/// SwiftUI view for rendering arrow preview during drag.
struct ArrowPreviewView: View {
    let startPoint: CGPoint
    let endPoint: CGPoint
    let color: Color
    let strokeWidth: CGFloat
    let scale: CGFloat

    var body: some View {
        Canvas { context, _ in
            // Draw line
            var path = Path()
            path.move(to: scaledPoint(startPoint))
            path.addLine(to: scaledPoint(endPoint))

            context.stroke(
                path,
                with: .color(color),
                lineWidth: strokeWidth
            )

            // Draw arrowhead
            drawArrowHead(in: &context)
        }
    }

    private func scaledPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * scale, y: point.y * scale)
    }

    private func drawArrowHead(in context: inout GraphicsContext) {
        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
        let headLength: CGFloat = 15 + strokeWidth * 2
        let headAngle: CGFloat = .pi / 6

        let scaledEnd = scaledPoint(endPoint)

        let point1 = CGPoint(
            x: scaledEnd.x - headLength * cos(angle - headAngle),
            y: scaledEnd.y - headLength * sin(angle - headAngle)
        )
        let point2 = CGPoint(
            x: scaledEnd.x - headLength * cos(angle + headAngle),
            y: scaledEnd.y - headLength * sin(angle + headAngle)
        )

        var arrowPath = Path()
        arrowPath.move(to: scaledEnd)
        arrowPath.addLine(to: point1)
        arrowPath.addLine(to: point2)
        arrowPath.closeSubpath()

        context.fill(arrowPath, with: .color(color))
    }
}
