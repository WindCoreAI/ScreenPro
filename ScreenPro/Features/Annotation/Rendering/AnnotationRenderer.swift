import Foundation
import CoreGraphics
import AppKit

// MARK: - AnnotationRenderer (T016)

/// Renders annotations to a CGContext using Core Graphics.
/// This is the central rendering engine for all annotation types.
@MainActor
final class AnnotationRenderer {
    // MARK: - Properties

    private let document: AnnotationDocument
    private let scale: CGFloat

    // MARK: - Initialization

    init(document: AnnotationDocument, scale: CGFloat = 1.0) {
        self.document = document
        self.scale = scale
    }

    // MARK: - Rendering

    /// Renders all annotations to a new CGImage.
    /// - Parameter includeBase: Whether to include the base image.
    /// - Returns: The rendered image, or nil on failure.
    func render(includeBase: Bool = true) -> CGImage? {
        let width = Int(document.canvasSize.width * scale)
        let height = Int(document.canvasSize.height * scale)

        guard let context = createContext(width: width, height: height) else {
            return nil
        }

        // Draw base image if requested
        if includeBase {
            context.draw(document.baseImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        // Apply scale for annotation rendering
        context.scaleBy(x: scale, y: scale)

        // Render annotations in z-order
        renderAnnotations(in: context)

        return context.makeImage()
    }

    /// Renders all annotations to an existing context.
    /// - Parameter context: The context to render into.
    func renderAnnotations(in context: CGContext) {
        // Sort annotations by z-index for proper layering
        let sortedAnnotations = document.annotations.sorted { $0.zIndex < $1.zIndex }

        for annotation in sortedAnnotations {
            context.saveGState()
            annotation.render(in: context, scale: scale)
            context.restoreGState()
        }
    }

    /// Renders selection indicators for selected annotations.
    /// - Parameter context: The context to render into.
    func renderSelectionIndicators(in context: CGContext) {
        let selectedAnnotations = document.selectedAnnotations

        for annotation in selectedAnnotations {
            renderSelectionIndicator(for: annotation, in: context)
        }
    }

    // MARK: - Helper Methods

    private func createContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    private func renderSelectionIndicator(for annotation: any Annotation, in context: CGContext) {
        let bounds = annotation.transformedBounds
        let handleSize: CGFloat = 8

        context.saveGState()
        defer { context.restoreGState() }

        // Selection border
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(1 / scale)
        context.stroke(bounds)

        // Corner handles
        let corners = [
            CGPoint(x: bounds.minX, y: bounds.minY),
            CGPoint(x: bounds.maxX, y: bounds.minY),
            CGPoint(x: bounds.minX, y: bounds.maxY),
            CGPoint(x: bounds.maxX, y: bounds.maxY)
        ]

        context.setFillColor(CGColor.white)

        for corner in corners {
            let handleRect = CGRect(
                x: corner.x - handleSize / 2 / scale,
                y: corner.y - handleSize / 2 / scale,
                width: handleSize / scale,
                height: handleSize / scale
            )

            // White fill
            context.fillEllipse(in: handleRect)

            // Accent stroke
            context.setStrokeColor(NSColor.controlAccentColor.cgColor)
            context.strokeEllipse(in: handleRect)
        }
    }
}

// MARK: - Annotation Rendering Extensions

/// Extension methods for common rendering operations.
extension CGContext {
    /// Draws an arrow from start to end with the specified style.
    func drawArrow(
        from start: CGPoint,
        to end: CGPoint,
        style: ArrowStyle,
        color: CGColor,
        strokeWidth: CGFloat,
        scale: CGFloat
    ) {
        saveGState()
        defer { restoreGState() }

        setStrokeColor(color)
        setLineWidth(strokeWidth / scale)
        setLineCap(.round)
        setLineJoin(.round)

        // Draw line
        move(to: start)
        addLine(to: end)
        strokePath()

        // Draw arrowhead if not none
        if style.headStyle != .none {
            drawArrowHead(at: end, from: start, style: style.headStyle, color: color, strokeWidth: strokeWidth, scale: scale)
        }

        // Draw tail if not none
        if style.tailStyle != .none {
            drawArrowHead(at: start, from: end, style: style.tailStyle, color: color, strokeWidth: strokeWidth, scale: scale)
        }
    }

    private func drawArrowHead(
        at point: CGPoint,
        from origin: CGPoint,
        style: ArrowHeadStyle,
        color: CGColor,
        strokeWidth: CGFloat,
        scale: CGFloat
    ) {
        // Calculate angle
        let angle = atan2(point.y - origin.y, point.x - origin.x)

        // Arrowhead parameters
        let headLength: CGFloat = 15 + strokeWidth * 2
        let headAngle: CGFloat = .pi / 6 // 30 degrees

        // Calculate arrowhead points
        let point1 = CGPoint(
            x: point.x - headLength * cos(angle - headAngle),
            y: point.y - headLength * sin(angle - headAngle)
        )
        let point2 = CGPoint(
            x: point.x - headLength * cos(angle + headAngle),
            y: point.y - headLength * sin(angle + headAngle)
        )

        switch style {
        case .none:
            break

        case .open:
            move(to: point1)
            addLine(to: point)
            addLine(to: point2)
            strokePath()

        case .filled:
            setFillColor(color)
            move(to: point)
            addLine(to: point1)
            addLine(to: point2)
            closePath()
            fillPath()

        case .circle:
            let circleRadius = headLength / 2
            let circleRect = CGRect(
                x: point.x - circleRadius,
                y: point.y - circleRadius,
                width: circleRadius * 2,
                height: circleRadius * 2
            )
            setFillColor(color)
            fillEllipse(in: circleRect)
        }
    }

    /// Draws a shape annotation.
    func drawShape(
        bounds: CGRect,
        type: ShapeType,
        fillColor: CGColor?,
        strokeColor: CGColor,
        strokeWidth: CGFloat,
        cornerRadius: CGFloat,
        scale: CGFloat
    ) {
        saveGState()
        defer { restoreGState() }

        setStrokeColor(strokeColor)
        setLineWidth(strokeWidth / scale)

        switch type {
        case .rectangle:
            if cornerRadius > 0 {
                let path = CGPath(roundedRect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                addPath(path)
            } else {
                addRect(bounds)
            }

        case .ellipse:
            addEllipse(in: bounds)

        case .line:
            move(to: CGPoint(x: bounds.minX, y: bounds.minY))
            addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        }

        if let fillColor = fillColor, type != .line {
            setFillColor(fillColor)
            fillPath()

            // Re-add path for stroke
            switch type {
            case .rectangle:
                if cornerRadius > 0 {
                    let path = CGPath(roundedRect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                    addPath(path)
                } else {
                    addRect(bounds)
                }
            case .ellipse:
                addEllipse(in: bounds)
            case .line:
                break
            }
        }

        strokePath()
    }

    /// Draws text with optional background.
    func drawText(
        _ text: String,
        at point: CGPoint,
        font: NSFont,
        color: CGColor,
        backgroundColor: CGColor?,
        padding: CGFloat
    ) {
        saveGState()
        defer { restoreGState() }

        // Create attributed string
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(cgColor: color) ?? .black
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)

        // Calculate bounds
        let textSize = attributedString.size()
        let textRect = CGRect(
            x: point.x,
            y: point.y,
            width: textSize.width + padding * 2,
            height: textSize.height + padding * 2
        )

        // Draw background if specified
        if let backgroundColor = backgroundColor {
            setFillColor(backgroundColor)
            fill(textRect)
        }

        // Draw text using Core Text
        let line = CTLineCreateWithAttributedString(attributedString)

        // Flip coordinate system for text
        textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        textPosition = CGPoint(
            x: point.x + padding,
            y: point.y + textSize.height + padding
        )

        CTLineDraw(line, self)
    }

    /// Draws a highlighter stroke path.
    func drawHighlighter(
        points: [CGPoint],
        color: CGColor,
        strokeWidth: CGFloat,
        scale: CGFloat
    ) {
        guard points.count >= 2 else { return }

        saveGState()
        defer { restoreGState() }

        // Set highlighter blend mode
        setBlendMode(.multiply)
        setAlpha(0.4)
        setStrokeColor(color)
        setLineWidth(strokeWidth / scale)
        setLineCap(.round)
        setLineJoin(.round)

        // Draw path
        move(to: points[0])
        for i in 1..<points.count {
            addLine(to: points[i])
        }
        strokePath()
    }

    /// Draws a numbered counter circle.
    func drawCounter(
        at center: CGPoint,
        number: Int,
        color: CGColor,
        size: CGFloat,
        scale: CGFloat
    ) {
        saveGState()
        defer { restoreGState() }

        let radius = size / 2

        // Draw circle background
        let circleRect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: size,
            height: size
        )
        setFillColor(color)
        fillEllipse(in: circleRect)

        // Draw number text
        let font = NSFont.boldSystemFont(ofSize: size * 0.5)
        let text = "\(number)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()

        // Center text in circle
        let textPoint = CGPoint(
            x: center.x - textSize.width / 2,
            y: center.y - textSize.height / 2
        )

        let line = CTLineCreateWithAttributedString(attributedString)
        textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        textPosition = CGPoint(
            x: textPoint.x,
            y: textPoint.y + textSize.height
        )
        CTLineDraw(line, self)
    }
}
