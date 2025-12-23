import Foundation
import CoreGraphics
import AppKit

// MARK: - Annotation Protocol (T005)

/// Base protocol that all annotation types must conform to.
/// Provides common properties and behaviors for canvas rendering and manipulation.
protocol Annotation: Identifiable, AnyObject {
    /// Unique identifier for this annotation.
    var id: UUID { get }

    /// Bounding rectangle in canvas coordinates.
    var bounds: CGRect { get set }

    /// Transformation matrix for rotation/scaling.
    var transform: CGAffineTransform { get set }

    /// Layer order (higher = rendered on top).
    var zIndex: Int { get set }

    /// Whether this annotation is currently selected.
    var isSelected: Bool { get set }

    /// Renders the annotation to the given graphics context.
    /// - Parameters:
    ///   - context: The Core Graphics context to draw into.
    ///   - scale: The current zoom level for proper stroke scaling.
    func render(in context: CGContext, scale: CGFloat)

    /// Tests whether a point intersects with this annotation.
    /// - Parameter point: Point in canvas coordinates.
    /// - Returns: True if the point is within the annotation bounds.
    func hitTest(_ point: CGPoint) -> Bool

    /// Creates a deep copy of this annotation with a new UUID.
    /// - Returns: A copy of this annotation.
    func copy() -> any Annotation
}

// MARK: - Annotation Default Implementations

extension Annotation {
    /// Bounds after applying the transform.
    var transformedBounds: CGRect {
        bounds.applying(transform)
    }

    /// Default hit test implementation using transformed bounds with padding.
    func hitTest(_ point: CGPoint) -> Bool {
        let hitPadding: CGFloat = 5
        return transformedBounds.insetBy(dx: -hitPadding, dy: -hitPadding).contains(point)
    }
}

// MARK: - Base Annotation Class

/// Base class providing common annotation functionality.
/// Concrete annotation types should inherit from this.
class BaseAnnotation: Annotation {
    let id: UUID
    var bounds: CGRect
    var transform: CGAffineTransform
    var zIndex: Int
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        bounds: CGRect,
        transform: CGAffineTransform = .identity,
        zIndex: Int = 0,
        isSelected: Bool = false
    ) {
        self.id = id
        self.bounds = bounds
        self.transform = transform
        self.zIndex = zIndex
        self.isSelected = isSelected
    }

    func render(in context: CGContext, scale: CGFloat) {
        // Override in subclasses
        fatalError("render(in:scale:) must be overridden in subclass")
    }

    func copy() -> any Annotation {
        // Override in subclasses
        fatalError("copy() must be overridden in subclass")
    }
}

// MARK: - Arrow Style Types

/// Configuration for arrow head styles.
enum ArrowHeadStyle: String, Codable, Sendable {
    case none
    case open
    case filled
    case circle
}

/// Configuration for arrow line styles.
enum ArrowLineStyle: String, Codable, Sendable {
    case straight
    case curved
}

/// Complete arrow style configuration.
struct ArrowStyle: Codable, Equatable, Sendable {
    var headStyle: ArrowHeadStyle = .filled
    var tailStyle: ArrowHeadStyle = .none
    var lineStyle: ArrowLineStyle = .straight

    static let `default` = ArrowStyle()
}

// MARK: - Shape Types

/// Types of geometric shapes that can be drawn.
enum ShapeType: String, Codable, Sendable {
    case rectangle
    case ellipse
    case line
}

// MARK: - Blur Types

/// Types of blur effects for privacy masking.
enum BlurType: String, Codable, Sendable {
    case gaussian
    case pixelate
}

// MARK: - Placeholder Annotation (for basic rendering tests)

/// A simple placeholder annotation for testing the annotation system.
/// Will be replaced with concrete annotation types in user story phases.
final class PlaceholderAnnotation: BaseAnnotation {
    var color: AnnotationColor
    var strokeWidth: CGFloat

    init(
        id: UUID = UUID(),
        bounds: CGRect,
        color: AnnotationColor = .red,
        strokeWidth: CGFloat = 3,
        zIndex: Int = 0
    ) {
        self.color = color
        self.strokeWidth = strokeWidth
        super.init(id: id, bounds: bounds, zIndex: zIndex)
    }

    override func render(in context: CGContext, scale: CGFloat) {
        context.saveGState()
        defer { context.restoreGState() }

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(strokeWidth / scale)
        context.stroke(bounds)
    }

    override func copy() -> any Annotation {
        PlaceholderAnnotation(
            id: UUID(),
            bounds: bounds,
            color: color,
            strokeWidth: strokeWidth,
            zIndex: zIndex
        )
    }
}

// MARK: - ArrowAnnotation (T022, T023, T024)

/// Arrow annotation with start and end points, customizable head/tail styles.
final class ArrowAnnotation: BaseAnnotation {
    // MARK: - Properties

    /// Arrow start point (tail position).
    var startPoint: CGPoint {
        didSet { updateBounds() }
    }

    /// Arrow end point (head position).
    var endPoint: CGPoint {
        didSet { updateBounds() }
    }

    /// Arrow style configuration.
    var style: ArrowStyle

    /// Stroke color.
    var color: AnnotationColor

    /// Line thickness.
    var strokeWidth: CGFloat

    // MARK: - Constants

    /// Base arrowhead length.
    private static let baseHeadLength: CGFloat = 15

    /// Arrowhead angle in radians (30 degrees).
    private static let headAngle: CGFloat = .pi / 6

    /// Hit test tolerance.
    private static let hitTolerance: CGFloat = 8

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        startPoint: CGPoint,
        endPoint: CGPoint,
        style: ArrowStyle = .default,
        color: AnnotationColor = .red,
        strokeWidth: CGFloat = 3,
        zIndex: Int = 0
    ) {
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.style = style
        self.color = color
        self.strokeWidth = strokeWidth

        // Calculate initial bounds
        let bounds = ArrowAnnotation.calculateBounds(from: startPoint, to: endPoint, strokeWidth: strokeWidth)
        super.init(id: id, bounds: bounds, zIndex: zIndex)
    }

    // MARK: - Bounds Calculation

    private func updateBounds() {
        bounds = ArrowAnnotation.calculateBounds(from: startPoint, to: endPoint, strokeWidth: strokeWidth)
    }

    private static func calculateBounds(from start: CGPoint, to end: CGPoint, strokeWidth: CGFloat) -> CGRect {
        let minX = min(start.x, end.x)
        let maxX = max(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxY = max(start.y, end.y)

        // Add padding for stroke width and arrowhead
        let padding = max(strokeWidth, baseHeadLength) + 5

        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: maxX - minX + padding * 2,
            height: maxY - minY + padding * 2
        )
    }

    // MARK: - Rendering (T024)

    override func render(in context: CGContext, scale: CGFloat) {
        context.saveGState()
        defer { context.restoreGState() }

        // Apply transform if any
        if transform != .identity {
            context.concatenate(transform)
        }

        // Set line properties
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(strokeWidth / scale)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Draw the line based on style
        switch style.lineStyle {
        case .straight:
            drawStraightLine(in: context)
        case .curved:
            drawCurvedLine(in: context)
        }

        // Draw arrowhead if needed
        if style.headStyle != .none {
            drawArrowHead(
                in: context,
                at: endPoint,
                from: startPoint,
                style: style.headStyle,
                scale: scale
            )
        }

        // Draw tail if needed
        if style.tailStyle != .none {
            drawArrowHead(
                in: context,
                at: startPoint,
                from: endPoint,
                style: style.tailStyle,
                scale: scale
            )
        }
    }

    private func drawStraightLine(in context: CGContext) {
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()
    }

    private func drawCurvedLine(in context: CGContext) {
        // Calculate control point for quadratic curve
        let midX = (startPoint.x + endPoint.x) / 2
        let midY = (startPoint.y + endPoint.y) / 2

        // Perpendicular offset for curve
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let length = hypot(dx, dy)
        let curveOffset = length * 0.2 // 20% curve offset

        // Perpendicular direction
        let perpX = -dy / length * curveOffset
        let perpY = dx / length * curveOffset

        let controlPoint = CGPoint(x: midX + perpX, y: midY + perpY)

        context.move(to: startPoint)
        context.addQuadCurve(to: endPoint, control: controlPoint)
        context.strokePath()
    }

    private func drawArrowHead(
        in context: CGContext,
        at point: CGPoint,
        from origin: CGPoint,
        style: ArrowHeadStyle,
        scale: CGFloat
    ) {
        // Calculate angle from origin to point
        let angle = atan2(point.y - origin.y, point.x - origin.x)

        // Scale head length with stroke width
        let headLength = Self.baseHeadLength + strokeWidth * 2

        // Calculate arrowhead points
        let point1 = CGPoint(
            x: point.x - headLength * cos(angle - Self.headAngle),
            y: point.y - headLength * sin(angle - Self.headAngle)
        )
        let point2 = CGPoint(
            x: point.x - headLength * cos(angle + Self.headAngle),
            y: point.y - headLength * sin(angle + Self.headAngle)
        )

        switch style {
        case .none:
            break

        case .open:
            context.move(to: point1)
            context.addLine(to: point)
            context.addLine(to: point2)
            context.strokePath()

        case .filled:
            context.setFillColor(color.cgColor)
            context.move(to: point)
            context.addLine(to: point1)
            context.addLine(to: point2)
            context.closePath()
            context.fillPath()

        case .circle:
            let circleRadius = headLength / 2
            let circleRect = CGRect(
                x: point.x - circleRadius,
                y: point.y - circleRadius,
                width: circleRadius * 2,
                height: circleRadius * 2
            )
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: circleRect)
        }
    }

    // MARK: - Hit Testing

    override func hitTest(_ point: CGPoint) -> Bool {
        // Calculate distance from point to line segment
        let distance = distanceToLineSegment(point: point, from: startPoint, to: endPoint)

        // Hit tolerance is based on stroke width plus padding
        let tolerance = max(strokeWidth / 2, Self.hitTolerance)

        return distance <= tolerance
    }

    /// Calculates the distance from a point to a line segment.
    private func distanceToLineSegment(point: CGPoint, from start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy

        // If start and end are the same point
        if lengthSquared == 0 {
            return hypot(point.x - start.x, point.y - start.y)
        }

        // Calculate projection parameter t
        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))

        // Find closest point on line segment
        let closestX = start.x + t * dx
        let closestY = start.y + t * dy

        // Return distance to closest point
        return hypot(point.x - closestX, point.y - closestY)
    }

    // MARK: - Copy

    override func copy() -> any Annotation {
        ArrowAnnotation(
            id: UUID(),
            startPoint: startPoint,
            endPoint: endPoint,
            style: style,
            color: color,
            strokeWidth: strokeWidth,
            zIndex: zIndex
        )
    }
}

// MARK: - BlurAnnotation (T035, T036, T039)

/// Blur/pixelate annotation for privacy masking.
/// The blur effect is rendered as a placeholder during editing and
/// destructively applied during export.
final class BlurAnnotation: BaseAnnotation {
    // MARK: - Properties

    /// Type of blur effect (gaussian or pixelate).
    var blurType: BlurType

    /// Blur intensity (0.0 to 1.0).
    var intensity: CGFloat

    // MARK: - Constants

    /// Default overlay color for blur preview.
    private static let overlayColor = CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.3)

    /// Stroke color for blur region border.
    private static let borderColor = CGColor(red: 0.3, green: 0.3, blue: 0.8, alpha: 0.8)

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        bounds: CGRect,
        blurType: BlurType = .gaussian,
        intensity: CGFloat = 0.5,
        zIndex: Int = 0
    ) {
        self.blurType = blurType
        self.intensity = max(0, min(1, intensity)) // Clamp to 0-1
        super.init(id: id, bounds: bounds, zIndex: zIndex)
    }

    // MARK: - Rendering (T039)

    /// Renders a placeholder rectangle during editing.
    /// Actual blur is applied during export via BlurRenderer.
    override func render(in context: CGContext, scale: CGFloat) {
        context.saveGState()
        defer { context.restoreGState() }

        // Apply transform if any
        if transform != .identity {
            context.concatenate(transform)
        }

        // Draw semi-transparent overlay to indicate blur region
        context.setFillColor(Self.overlayColor)
        context.fill(bounds)

        // Draw dashed border
        context.setStrokeColor(Self.borderColor)
        context.setLineWidth(2 / scale)
        context.setLineDash(phase: 0, lengths: [6 / scale, 4 / scale])
        context.stroke(bounds)

        // Draw blur type icon in center
        drawBlurIcon(in: context, scale: scale)
    }

    private func drawBlurIcon(in context: CGContext, scale: CGFloat) {
        let iconSize: CGFloat = min(bounds.width, bounds.height, 40) * 0.5
        let centerX = bounds.midX
        let centerY = bounds.midY

        context.setFillColor(CGColor(red: 0.3, green: 0.3, blue: 0.8, alpha: 0.6))

        switch blurType {
        case .gaussian:
            // Draw concentric circles for gaussian blur icon
            for i in 0..<3 {
                let radius = iconSize * (0.3 + CGFloat(i) * 0.2)
                context.strokeEllipse(in: CGRect(
                    x: centerX - radius,
                    y: centerY - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
            }

        case .pixelate:
            // Draw grid for pixelate icon
            let gridSize = iconSize / 3
            for row in 0..<3 {
                for col in 0..<3 {
                    if (row + col) % 2 == 0 {
                        context.fill(CGRect(
                            x: centerX - iconSize / 2 + CGFloat(col) * gridSize,
                            y: centerY - iconSize / 2 + CGFloat(row) * gridSize,
                            width: gridSize,
                            height: gridSize
                        ))
                    }
                }
            }
        }
    }

    // MARK: - Hit Testing

    override func hitTest(_ point: CGPoint) -> Bool {
        let hitPadding: CGFloat = 5
        return transformedBounds.insetBy(dx: -hitPadding, dy: -hitPadding).contains(point)
    }

    // MARK: - Copy

    override func copy() -> any Annotation {
        BlurAnnotation(
            id: UUID(),
            bounds: bounds,
            blurType: blurType,
            intensity: intensity,
            zIndex: zIndex
        )
    }
}

// MARK: - TextAnnotation (T048, T050, T053, T056)

/// Text annotation with customizable font, color, and optional background.
final class TextAnnotation: BaseAnnotation {
    // MARK: - Properties

    /// The text content.
    var text: String {
        didSet { updateBounds() }
    }

    /// Position of the text (top-left corner).
    var position: CGPoint {
        didSet { updateBounds() }
    }

    /// Text color.
    var textColor: AnnotationColor

    /// Optional background color.
    var backgroundColor: AnnotationColor?

    /// Font configuration.
    var font: AnnotationFont {
        didSet { updateBounds() }
    }

    /// Padding around text (for background).
    var padding: CGFloat

    /// Whether the text is currently being edited.
    var isEditing: Bool = false

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        text: String,
        position: CGPoint,
        textColor: AnnotationColor = .black,
        backgroundColor: AnnotationColor? = nil,
        font: AnnotationFont = .default,
        padding: CGFloat = 4,
        zIndex: Int = 0
    ) {
        self.text = text
        self.position = position
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.font = font
        self.padding = padding

        // Calculate initial bounds
        let bounds = TextAnnotation.calculateBounds(
            text: text,
            position: position,
            font: font,
            padding: padding
        )
        super.init(id: id, bounds: bounds, zIndex: zIndex)
    }

    // MARK: - Bounds Calculation (T053)

    private func updateBounds() {
        bounds = TextAnnotation.calculateBounds(
            text: text,
            position: position,
            font: font,
            padding: padding
        )
    }

    private static func calculateBounds(
        text: String,
        position: CGPoint,
        font: AnnotationFont,
        padding: CGFloat
    ) -> CGRect {
        // Handle empty text
        guard !text.isEmpty else {
            return CGRect(x: position.x, y: position.y, width: 20, height: font.size + padding * 2)
        }

        // Calculate text size
        let nsFont = font.nsFont
        let attributes: [NSAttributedString.Key: Any] = [.font: nsFont]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()

        return CGRect(
            x: position.x,
            y: position.y,
            width: textSize.width + padding * 2,
            height: textSize.height + padding * 2
        )
    }

    // MARK: - Rendering (T050, T056)

    override func render(in context: CGContext, scale: CGFloat) {
        context.saveGState()
        defer { context.restoreGState() }

        // Apply transform if any
        if transform != .identity {
            context.concatenate(transform)
        }

        // Don't render if editing (UI overlay handles this)
        guard !isEditing else { return }

        // Draw background if specified (T056)
        if let bgColor = backgroundColor {
            context.setFillColor(bgColor.cgColor)
            context.fill(bounds)
        }

        // Draw text using Core Text
        guard !text.isEmpty else { return }

        let nsFont = font.nsFont
        let attributes: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .foregroundColor: NSColor(cgColor: textColor.cgColor) ?? .black
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)

        // Handle multiline text
        let lines = text.components(separatedBy: "\n")
        var yOffset: CGFloat = padding

        for line in lines {
            let lineAttrs: [NSAttributedString.Key: Any] = [
                .font: nsFont,
                .foregroundColor: NSColor(cgColor: textColor.cgColor) ?? .black
            ]
            let lineString = NSAttributedString(string: line, attributes: lineAttrs)
            let ctLine = CTLineCreateWithAttributedString(lineString)

            // Core Graphics has flipped Y coordinate
            let textX = position.x + padding
            let textY = position.y + yOffset + nsFont.ascender

            context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
            context.textPosition = CGPoint(x: textX, y: textY)

            CTLineDraw(ctLine, context)

            yOffset += nsFont.ascender - nsFont.descender + nsFont.leading
        }
    }

    // MARK: - Hit Testing

    override func hitTest(_ point: CGPoint) -> Bool {
        let hitPadding: CGFloat = 5
        return transformedBounds.insetBy(dx: -hitPadding, dy: -hitPadding).contains(point)
    }

    // MARK: - Copy

    override func copy() -> any Annotation {
        TextAnnotation(
            id: UUID(),
            text: text,
            position: position,
            textColor: textColor,
            backgroundColor: backgroundColor,
            font: font,
            padding: padding,
            zIndex: zIndex
        )
    }
}

// MARK: - ShapeAnnotation (T059, T060, T061)

/// Shape annotation for rectangles, ellipses, and lines.
final class ShapeAnnotation: BaseAnnotation {
    // MARK: - Properties

    /// Type of shape.
    var shapeType: ShapeType

    /// Optional fill color (nil for stroke-only shapes).
    var fillColor: AnnotationColor?

    /// Stroke color.
    var strokeColor: AnnotationColor

    /// Stroke width.
    var strokeWidth: CGFloat

    /// Corner radius (for rectangles only).
    var cornerRadius: CGFloat

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        bounds: CGRect,
        shapeType: ShapeType = .rectangle,
        fillColor: AnnotationColor? = nil,
        strokeColor: AnnotationColor = .red,
        strokeWidth: CGFloat = 3,
        cornerRadius: CGFloat = 0,
        zIndex: Int = 0
    ) {
        self.shapeType = shapeType
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.cornerRadius = cornerRadius
        super.init(id: id, bounds: bounds, zIndex: zIndex)
    }

    // MARK: - Rendering (T061)

    override func render(in context: CGContext, scale: CGFloat) {
        context.saveGState()
        defer { context.restoreGState() }

        // Apply transform if any
        if transform != .identity {
            context.concatenate(transform)
        }

        // Set stroke properties
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(strokeWidth / scale)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch shapeType {
        case .rectangle:
            renderRectangle(in: context)

        case .ellipse:
            renderEllipse(in: context)

        case .line:
            renderLine(in: context)
        }
    }

    private func renderRectangle(in context: CGContext) {
        // Draw filled rectangle if fill color specified
        if let fillColor = fillColor {
            context.setFillColor(fillColor.cgColor)
            if cornerRadius > 0 {
                let path = CGPath(roundedRect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                context.addPath(path)
                context.fillPath()
            } else {
                context.fill(bounds)
            }
        }

        // Draw stroke
        if cornerRadius > 0 {
            let path = CGPath(roundedRect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            context.addPath(path)
            context.strokePath()
        } else {
            context.stroke(bounds)
        }
    }

    private func renderEllipse(in context: CGContext) {
        // Draw filled ellipse if fill color specified
        if let fillColor = fillColor {
            context.setFillColor(fillColor.cgColor)
            context.fillEllipse(in: bounds)
        }

        // Draw stroke
        context.strokeEllipse(in: bounds)
    }

    private func renderLine(in context: CGContext) {
        // Line from top-left to bottom-right of bounds
        context.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
        context.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        context.strokePath()
    }

    // MARK: - Hit Testing

    override func hitTest(_ point: CGPoint) -> Bool {
        let hitPadding: CGFloat = 5
        return transformedBounds.insetBy(dx: -hitPadding, dy: -hitPadding).contains(point)
    }

    // MARK: - Copy

    override func copy() -> any Annotation {
        ShapeAnnotation(
            id: UUID(),
            bounds: bounds,
            shapeType: shapeType,
            fillColor: fillColor,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            cornerRadius: cornerRadius,
            zIndex: zIndex
        )
    }
}

// MARK: - HighlighterAnnotation (T088, T089, T092)

/// Highlighter annotation for semi-transparent emphasis strokes.
/// Uses multiply blend mode at 0.4 alpha for highlighter effect.
final class HighlighterAnnotation: BaseAnnotation {
    // MARK: - Properties

    /// Points defining the highlighter stroke path.
    var points: [CGPoint]

    /// Highlighter color.
    var color: AnnotationColor

    /// Stroke width.
    var strokeWidth: CGFloat

    /// Highlighter alpha (0.4 for semi-transparency).
    private let highlighterAlpha: CGFloat = 0.4

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        points: [CGPoint],
        color: AnnotationColor = .yellow,
        strokeWidth: CGFloat = 20,
        zIndex: Int = 0
    ) {
        self.points = points
        self.color = color
        self.strokeWidth = strokeWidth

        // Calculate bounds from points
        let calculatedBounds = HighlighterAnnotation.calculateBounds(from: points, strokeWidth: strokeWidth)
        super.init(id: id, bounds: calculatedBounds, zIndex: zIndex)
    }

    // MARK: - Bounds Calculation (T092)

    private static func calculateBounds(from points: [CGPoint], strokeWidth: CGFloat) -> CGRect {
        guard !points.isEmpty else {
            return .zero
        }

        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity

        for point in points {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }

        // Add stroke padding
        let padding = strokeWidth / 2
        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: maxX - minX + strokeWidth,
            height: maxY - minY + strokeWidth
        )
    }

    /// Updates bounds when points change.
    func updateBounds() {
        bounds = HighlighterAnnotation.calculateBounds(from: points, strokeWidth: strokeWidth)
    }

    // MARK: - Rendering (T089)

    override func render(in context: CGContext, scale: CGFloat) {
        guard points.count >= 2 else { return }

        context.saveGState()
        defer { context.restoreGState() }

        // Apply transform if any
        if transform != .identity {
            context.concatenate(transform)
        }

        // Set multiply blend mode for highlighter effect
        context.setBlendMode(.multiply)

        // Set stroke properties with semi-transparency
        let colorWithAlpha = color.cgColor.copy(alpha: highlighterAlpha) ?? color.cgColor
        context.setStrokeColor(colorWithAlpha)
        context.setLineWidth(strokeWidth / scale)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Draw the path through all points
        context.move(to: points[0])
        for i in 1..<points.count {
            context.addLine(to: points[i])
        }
        context.strokePath()
    }

    // MARK: - Hit Testing

    override func hitTest(_ point: CGPoint) -> Bool {
        guard points.count >= 2 else { return false }

        let hitTolerance = max(strokeWidth / 2, 10)

        // Check distance from point to each line segment
        for i in 0..<(points.count - 1) {
            let distance = distanceFromPointToLineSegment(
                point: point,
                lineStart: points[i],
                lineEnd: points[i + 1]
            )
            if distance <= hitTolerance {
                return true
            }
        }

        return false
    }

    /// Calculates the distance from a point to a line segment.
    private func distanceFromPointToLineSegment(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSquared = dx * dx + dy * dy

        if lengthSquared == 0 {
            // Line segment is a point
            return hypot(point.x - lineStart.x, point.y - lineStart.y)
        }

        // Calculate projection parameter
        let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSquared))

        // Find closest point on segment
        let closestX = lineStart.x + t * dx
        let closestY = lineStart.y + t * dy

        return hypot(point.x - closestX, point.y - closestY)
    }

    // MARK: - Copy

    override func copy() -> any Annotation {
        HighlighterAnnotation(
            id: UUID(),
            points: points,
            color: color,
            strokeWidth: strokeWidth,
            zIndex: zIndex
        )
    }
}

// MARK: - CounterAnnotation (T095, T096, T100)

/// Numbered circle callout for step-by-step annotations.
/// Displays a colored circle with a centered number.
final class CounterAnnotation: BaseAnnotation {
    // MARK: - Properties

    /// The display number.
    var number: Int

    /// Center position of the counter circle.
    var position: CGPoint {
        didSet { updateBounds() }
    }

    /// Background color of the circle.
    var color: AnnotationColor

    /// Diameter of the circle.
    var size: CGFloat {
        didSet { updateBounds() }
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        number: Int,
        position: CGPoint,
        color: AnnotationColor = .red,
        size: CGFloat = 28,
        zIndex: Int = 0
    ) {
        self.number = number
        self.position = position
        self.color = color
        self.size = size

        // Calculate bounds from position and size
        let bounds = CounterAnnotation.calculateBounds(position: position, size: size)
        super.init(id: id, bounds: bounds, zIndex: zIndex)
    }

    // MARK: - Bounds Calculation

    private func updateBounds() {
        bounds = CounterAnnotation.calculateBounds(position: position, size: size)
    }

    private static func calculateBounds(position: CGPoint, size: CGFloat) -> CGRect {
        let radius = size / 2
        return CGRect(
            x: position.x - radius,
            y: position.y - radius,
            width: size,
            height: size
        )
    }

    // MARK: - Rendering (T096)

    override func render(in context: CGContext, scale: CGFloat) {
        context.saveGState()
        defer { context.restoreGState() }

        // Apply transform if any
        if transform != .identity {
            context.concatenate(transform)
        }

        // Draw circle background
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: bounds)

        // Draw white number text centered in circle
        let text = "\(number)"
        let fontSize = size * 0.5
        let font = NSFont.boldSystemFont(ofSize: fontSize)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()

        // Center text in circle
        let textX = position.x - textSize.width / 2
        let textY = position.y - textSize.height / 2

        // Draw text using Core Text
        let line = CTLineCreateWithAttributedString(attributedString)
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = CGPoint(x: textX, y: textY + textSize.height)
        CTLineDraw(line, context)
    }

    // MARK: - Hit Testing

    override func hitTest(_ point: CGPoint) -> Bool {
        // Use circular hit testing
        let radius = size / 2
        let distance = hypot(point.x - position.x, point.y - position.y)
        return distance <= radius + 5 // 5pt hit tolerance
    }

    // MARK: - Copy

    override func copy() -> any Annotation {
        CounterAnnotation(
            id: UUID(),
            number: number,
            position: position,
            color: color,
            size: size,
            zIndex: zIndex
        )
    }
}
