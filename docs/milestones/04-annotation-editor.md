# Milestone 4: Annotation Editor

## Overview

**Goal**: Build a full-featured image markup editor with drawing tools, text, shapes, blur effects, and export capabilities.

**Prerequisites**: Milestone 3 completed

---

## Deliverables

| Deliverable | Description | Priority |
|-------------|-------------|----------|
| AnnotationWindow | Editor window with toolbar | P0 |
| AnnotationCanvas | Drawing surface with pan/zoom | P0 |
| Arrow Tool | Straight and curved arrows | P0 |
| Shape Tools | Rectangle, ellipse, line | P0 |
| Text Tool | Text with style presets | P0 |
| Blur/Pixelate | Privacy masking tools | P0 |
| Highlighter | Transparent highlight strokes | P1 |
| Counter Tool | Numbered callouts | P1 |
| Crop Tool | Resize with aspect ratios | P1 |
| Undo/Redo | Full history support | P0 |
| Export | Save in multiple formats | P0 |

---

## Implementation Tasks

### 4.1 Define Annotation Data Model

**Task**: Create the annotation type hierarchy

**File**: `Features/Annotation/Models/Annotation.swift`

```swift
import Foundation
import CoreGraphics
import AppKit

// MARK: - Base Protocol

protocol Annotation: Identifiable, Codable {
    var id: UUID { get }
    var bounds: CGRect { get set }
    var transform: CGAffineTransform { get set }
    var zIndex: Int { get set }
    var isSelected: Bool { get set }

    func render(in context: CGContext, scale: CGFloat)
    func hitTest(_ point: CGPoint) -> Bool
    func copy() -> any Annotation
}

extension Annotation {
    var transformedBounds: CGRect {
        bounds.applying(transform)
    }

    func hitTest(_ point: CGPoint) -> Bool {
        transformedBounds.insetBy(dx: -5, dy: -5).contains(point)
    }
}

// MARK: - Annotation Types

struct ArrowAnnotation: Annotation {
    let id: UUID
    var bounds: CGRect
    var transform: CGAffineTransform = .identity
    var zIndex: Int = 0
    var isSelected: Bool = false

    var startPoint: CGPoint
    var endPoint: CGPoint
    var style: ArrowStyle
    var color: AnnotationColor
    var strokeWidth: CGFloat

    struct ArrowStyle: Codable {
        var headStyle: HeadStyle = .filled
        var tailStyle: HeadStyle = .none
        var lineStyle: LineStyle = .straight

        enum HeadStyle: String, Codable {
            case none, open, filled, circle
        }

        enum LineStyle: String, Codable {
            case straight, curved
        }
    }

    init(from start: CGPoint, to end: CGPoint, color: AnnotationColor = .red, strokeWidth: CGFloat = 3) {
        self.id = UUID()
        self.startPoint = start
        self.endPoint = end
        self.color = color
        self.strokeWidth = strokeWidth
        self.style = ArrowStyle()
        self.bounds = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        ).insetBy(dx: -20, dy: -20)
    }

    func render(in context: CGContext, scale: CGFloat) {
        context.saveGState()
        context.concatenate(transform)

        let path = createArrowPath()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(strokeWidth * scale)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addPath(path)
        context.strokePath()

        // Draw arrow head
        drawArrowHead(in: context, scale: scale)

        context.restoreGState()
    }

    private func createArrowPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: startPoint)

        if style.lineStyle == .curved {
            let controlPoint = CGPoint(
                x: (startPoint.x + endPoint.x) / 2,
                y: min(startPoint.y, endPoint.y) - 50
            )
            path.addQuadCurve(to: endPoint, control: controlPoint)
        } else {
            path.addLine(to: endPoint)
        }

        return path
    }

    private func drawArrowHead(in context: CGContext, scale: CGFloat) {
        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
        let headLength: CGFloat = 15 * scale
        let headAngle: CGFloat = .pi / 6

        let point1 = CGPoint(
            x: endPoint.x - headLength * cos(angle - headAngle),
            y: endPoint.y - headLength * sin(angle - headAngle)
        )
        let point2 = CGPoint(
            x: endPoint.x - headLength * cos(angle + headAngle),
            y: endPoint.y - headLength * sin(angle + headAngle)
        )

        let headPath = CGMutablePath()
        headPath.move(to: point1)
        headPath.addLine(to: endPoint)
        headPath.addLine(to: point2)

        if style.headStyle == .filled {
            headPath.closeSubpath()
            context.setFillColor(color.cgColor)
            context.addPath(headPath)
            context.fillPath()
        } else {
            context.addPath(headPath)
            context.strokePath()
        }
    }

    func copy() -> any Annotation {
        var copy = self
        copy.id = UUID()
        return copy
    }
}

struct ShapeAnnotation: Annotation {
    let id: UUID
    var bounds: CGRect
    var transform: CGAffineTransform = .identity
    var zIndex: Int = 0
    var isSelected: Bool = false

    var shapeType: ShapeType
    var fillColor: AnnotationColor?
    var strokeColor: AnnotationColor
    var strokeWidth: CGFloat
    var cornerRadius: CGFloat = 0

    enum ShapeType: String, Codable {
        case rectangle, ellipse, line
    }

    func render(in context: CGContext, scale: CGFloat) {
        context.saveGState()
        context.concatenate(transform)

        let path: CGPath
        switch shapeType {
        case .rectangle:
            if cornerRadius > 0 {
                path = CGPath(
                    roundedRect: bounds,
                    cornerWidth: cornerRadius,
                    cornerHeight: cornerRadius,
                    transform: nil
                )
            } else {
                path = CGPath(rect: bounds, transform: nil)
            }
        case .ellipse:
            path = CGPath(ellipseIn: bounds, transform: nil)
        case .line:
            let linePath = CGMutablePath()
            linePath.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
            linePath.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
            path = linePath
        }

        if let fill = fillColor {
            context.setFillColor(fill.cgColor)
            context.addPath(path)
            context.fillPath()
        }

        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(strokeWidth * scale)
        context.addPath(path)
        context.strokePath()

        context.restoreGState()
    }

    func copy() -> any Annotation { var c = self; c.id = UUID(); return c }
}

struct TextAnnotation: Annotation {
    let id: UUID
    var bounds: CGRect
    var transform: CGAffineTransform = .identity
    var zIndex: Int = 0
    var isSelected: Bool = false

    var text: String
    var font: AnnotationFont
    var textColor: AnnotationColor
    var backgroundColor: AnnotationColor?
    var padding: CGFloat = 8

    struct AnnotationFont: Codable {
        var name: String = "SF Pro"
        var size: CGFloat = 16
        var weight: FontWeight = .regular

        enum FontWeight: String, Codable {
            case regular, medium, semibold, bold
        }

        var nsFont: NSFont {
            let weight: NSFont.Weight
            switch self.weight {
            case .regular: weight = .regular
            case .medium: weight = .medium
            case .semibold: weight = .semibold
            case .bold: weight = .bold
            }
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
    }

    func render(in context: CGContext, scale: CGFloat) {
        context.saveGState()
        context.concatenate(transform)

        // Background
        if let bg = backgroundColor {
            context.setFillColor(bg.cgColor)
            let bgPath = CGPath(
                roundedRect: bounds,
                cornerWidth: 4,
                cornerHeight: 4,
                transform: nil
            )
            context.addPath(bgPath)
            context.fillPath()
        }

        // Text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font.nsFont,
            .foregroundColor: textColor.nsColor
        ]

        let textRect = bounds.insetBy(dx: padding, dy: padding)
        let attributedString = NSAttributedString(string: text, attributes: attributes)

        // Need to flip for Core Graphics
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)

        let line = CTLineCreateWithAttributedString(attributedString)
        context.textPosition = CGPoint(x: textRect.minX, y: textRect.maxY - font.size)
        CTLineDraw(line, context)

        context.restoreGState()
    }

    func copy() -> any Annotation { var c = self; c.id = UUID(); return c }
}

struct BlurAnnotation: Annotation {
    let id: UUID
    var bounds: CGRect
    var transform: CGAffineTransform = .identity
    var zIndex: Int = 0
    var isSelected: Bool = false

    var blurType: BlurType
    var intensity: CGFloat  // 0.0 - 1.0

    enum BlurType: String, Codable {
        case gaussian
        case pixelate
    }

    func render(in context: CGContext, scale: CGFloat) {
        // Blur rendering requires special handling with Core Image
        // This is a placeholder - actual implementation uses CIFilter
        context.saveGState()
        context.concatenate(transform)

        // Draw placeholder rectangle showing blur region
        context.setFillColor(CGColor(gray: 0.5, alpha: 0.3))
        context.fill(bounds)

        context.restoreGState()
    }

    func copy() -> any Annotation { var c = self; c.id = UUID(); return c }
}

struct HighlighterAnnotation: Annotation {
    let id: UUID
    var bounds: CGRect
    var transform: CGAffineTransform = .identity
    var zIndex: Int = 0
    var isSelected: Bool = false

    var points: [CGPoint]
    var color: AnnotationColor
    var strokeWidth: CGFloat

    func render(in context: CGContext, scale: CGFloat) {
        guard points.count >= 2 else { return }

        context.saveGState()
        context.concatenate(transform)

        context.setStrokeColor(color.cgColor.copy(alpha: 0.4)!)
        context.setLineWidth(strokeWidth * scale)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setBlendMode(.multiply)

        let path = CGMutablePath()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        context.addPath(path)
        context.strokePath()

        context.restoreGState()
    }

    func copy() -> any Annotation { var c = self; c.id = UUID(); return c }
}

struct CounterAnnotation: Annotation {
    let id: UUID
    var bounds: CGRect
    var transform: CGAffineTransform = .identity
    var zIndex: Int = 0
    var isSelected: Bool = false

    var number: Int
    var position: CGPoint
    var color: AnnotationColor
    var size: CGFloat = 28

    init(number: Int, at position: CGPoint, color: AnnotationColor = .red) {
        self.id = UUID()
        self.number = number
        self.position = position
        self.color = color
        self.bounds = CGRect(
            x: position.x - size/2,
            y: position.y - size/2,
            width: size,
            height: size
        )
    }

    func render(in context: CGContext, scale: CGFloat) {
        context.saveGState()
        context.concatenate(transform)

        // Circle background
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: bounds)

        // Number text
        let text = "\(number)"
        let font = NSFont.systemFont(ofSize: size * 0.5, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        let textOrigin = CGPoint(
            x: bounds.midX - textSize.width / 2,
            y: bounds.midY - textSize.height / 2
        )

        // Draw text
        let line = CTLineCreateWithAttributedString(attributedString)
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = CGPoint(x: textOrigin.x, y: bounds.midY + textSize.height * 0.35)
        CTLineDraw(line, context)

        context.restoreGState()
    }

    func copy() -> any Annotation { var c = self; c.id = UUID(); return c }
}

// MARK: - Supporting Types

struct AnnotationColor: Codable, Hashable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    static let red = AnnotationColor(red: 1, green: 0.23, blue: 0.19, alpha: 1)
    static let orange = AnnotationColor(red: 1, green: 0.58, blue: 0, alpha: 1)
    static let yellow = AnnotationColor(red: 1, green: 0.8, blue: 0, alpha: 1)
    static let green = AnnotationColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1)
    static let blue = AnnotationColor(red: 0, green: 0.48, blue: 1, alpha: 1)
    static let purple = AnnotationColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1)
    static let black = AnnotationColor(red: 0, green: 0, blue: 0, alpha: 1)
    static let white = AnnotationColor(red: 1, green: 1, blue: 1, alpha: 1)

    var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
```

---

### 4.2 Implement Annotation Document

**Task**: Create the document model with undo support

**File**: `Features/Annotation/Models/AnnotationDocument.swift`

```swift
import Foundation
import AppKit
import Combine

@MainActor
final class AnnotationDocument: ObservableObject {
    // MARK: - Properties

    @Published private(set) var baseImage: CGImage
    @Published private(set) var annotations: [any Annotation] = []
    @Published var selectedAnnotationIds: Set<UUID> = []
    @Published private(set) var canvasSize: CGSize

    private let undoManager = UndoManager()

    var canUndo: Bool { undoManager.canUndo }
    var canRedo: Bool { undoManager.canRedo }

    // MARK: - Initialization

    init(image: CGImage) {
        self.baseImage = image
        self.canvasSize = CGSize(width: image.width, height: image.height)
    }

    init(result: CaptureService.CaptureResult) {
        self.baseImage = result.image
        self.canvasSize = CGSize(
            width: result.image.width,
            height: result.image.height
        )
    }

    // MARK: - Annotation Management

    func addAnnotation(_ annotation: any Annotation) {
        var mutableAnnotation = annotation
        mutableAnnotation.zIndex = annotations.count

        let previousAnnotations = annotations
        annotations.append(mutableAnnotation)

        undoManager.registerUndo(withTarget: self) { doc in
            doc.annotations = previousAnnotations
        }
    }

    func removeAnnotation(id: UUID) {
        let previousAnnotations = annotations
        annotations.removeAll { $0.id == id }

        undoManager.registerUndo(withTarget: self) { doc in
            doc.annotations = previousAnnotations
        }

        selectedAnnotationIds.remove(id)
    }

    func updateAnnotation<T: Annotation>(_ annotation: T) {
        guard let index = annotations.firstIndex(where: { $0.id == annotation.id }) else { return }

        let previousAnnotation = annotations[index]
        annotations[index] = annotation

        undoManager.registerUndo(withTarget: self) { doc in
            doc.annotations[index] = previousAnnotation
        }
    }

    func clearAnnotations() {
        let previousAnnotations = annotations
        annotations.removeAll()
        selectedAnnotationIds.removeAll()

        undoManager.registerUndo(withTarget: self) { doc in
            doc.annotations = previousAnnotations
        }
    }

    // MARK: - Selection

    func selectAnnotation(at point: CGPoint) -> (any Annotation)? {
        // Find topmost annotation at point
        let hit = annotations
            .sorted { $0.zIndex > $1.zIndex }
            .first { $0.hitTest(point) }

        if let annotation = hit {
            selectedAnnotationIds = [annotation.id]
            return annotation
        } else {
            selectedAnnotationIds.removeAll()
            return nil
        }
    }

    func selectAnnotations(in rect: CGRect) {
        let selected = annotations.filter { annotation in
            rect.intersects(annotation.transformedBounds)
        }
        selectedAnnotationIds = Set(selected.map { $0.id })
    }

    func deselectAll() {
        selectedAnnotationIds.removeAll()
    }

    var selectedAnnotations: [any Annotation] {
        annotations.filter { selectedAnnotationIds.contains($0.id) }
    }

    // MARK: - Undo/Redo

    func undo() {
        undoManager.undo()
    }

    func redo() {
        undoManager.redo()
    }

    // MARK: - Canvas Operations

    func expandCanvas(by insets: NSEdgeInsets) {
        let newWidth = canvasSize.width + insets.left + insets.right
        let newHeight = canvasSize.height + insets.top + insets.bottom

        canvasSize = CGSize(width: newWidth, height: newHeight)

        // Offset all annotations
        for i in annotations.indices {
            var annotation = annotations[i]
            annotation.bounds = annotation.bounds.offsetBy(
                dx: insets.left,
                dy: insets.top
            )
            annotations[i] = annotation
        }
    }

    // MARK: - Rendering

    func render(scale: CGFloat = 1.0) -> CGImage? {
        let width = Int(canvasSize.width * scale)
        let height = Int(canvasSize.height * scale)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Flip context for correct orientation
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)

        // Draw base image
        context.draw(baseImage, in: CGRect(origin: .zero, size: canvasSize))

        // Draw annotations in z-order
        let sortedAnnotations = annotations.sorted { $0.zIndex < $1.zIndex }
        for annotation in sortedAnnotations {
            annotation.render(in: context, scale: scale)
        }

        return context.makeImage()
    }

    // MARK: - Blur Rendering

    func renderWithBlur(scale: CGFloat = 1.0) -> CGImage? {
        guard let baseRendered = renderBase(scale: scale) else { return nil }

        var result = baseRendered

        // Apply blur annotations
        let blurAnnotations = annotations.compactMap { $0 as? BlurAnnotation }
        for blur in blurAnnotations {
            result = applyBlur(blur, to: result, scale: scale) ?? result
        }

        // Render other annotations on top
        guard let context = CGContext(
            data: nil,
            width: result.width,
            height: result.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return result }

        context.draw(result, in: CGRect(
            x: 0, y: 0,
            width: result.width,
            height: result.height
        ))

        // Draw non-blur annotations
        let otherAnnotations = annotations
            .filter { !($0 is BlurAnnotation) }
            .sorted { $0.zIndex < $1.zIndex }

        for annotation in otherAnnotations {
            annotation.render(in: context, scale: scale)
        }

        return context.makeImage()
    }

    private func renderBase(scale: CGFloat) -> CGImage? {
        let width = Int(canvasSize.width * scale)
        let height = Int(canvasSize.height * scale)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)
        context.draw(baseImage, in: CGRect(origin: .zero, size: canvasSize))

        return context.makeImage()
    }

    private func applyBlur(_ blur: BlurAnnotation, to image: CGImage, scale: CGFloat) -> CGImage? {
        let ciImage = CIImage(cgImage: image)
        let context = CIContext()

        let scaledBounds = blur.bounds.applying(
            CGAffineTransform(scaleX: scale, y: scale)
        )

        let filter: CIFilter?
        switch blur.blurType {
        case .gaussian:
            filter = CIFilter(name: "CIGaussianBlur")
            filter?.setValue(blur.intensity * 20, forKey: kCIInputRadiusKey)
        case .pixelate:
            filter = CIFilter(name: "CIPixellate")
            filter?.setValue(blur.intensity * 20 + 5, forKey: kCIInputScaleKey)
        }

        guard let filter = filter else { return image }

        // Crop region to blur
        let cropFilter = CIFilter(name: "CICrop")!
        cropFilter.setValue(ciImage, forKey: kCIInputImageKey)
        cropFilter.setValue(CIVector(cgRect: scaledBounds), forKey: "inputRectangle")

        guard let croppedRegion = cropFilter.outputImage else { return image }

        filter.setValue(croppedRegion, forKey: kCIInputImageKey)
        guard let blurredRegion = filter.outputImage else { return image }

        // Composite blurred region back onto original
        let composite = CIFilter(name: "CISourceOverCompositing")!
        composite.setValue(blurredRegion, forKey: kCIInputImageKey)
        composite.setValue(ciImage, forKey: kCIInputBackgroundImageKey)

        guard let output = composite.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return image
        }

        return cgImage
    }

    // MARK: - Export

    func export(format: SettingsManager.ImageFormat) -> Data? {
        guard let image = renderWithBlur() else { return nil }

        let bitmapRep = NSBitmapImageRep(cgImage: image)

        switch format {
        case .png:
            return bitmapRep.representation(using: .png, properties: [:])
        case .jpeg:
            return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        case .tiff:
            return bitmapRep.representation(using: .tiff, properties: [:])
        case .heic:
            return bitmapRep.representation(using: .png, properties: [:])
        }
    }
}
```

---

### 4.3 Implement Annotation Canvas View

**Task**: Create the interactive drawing canvas

**File**: `Features/Annotation/Views/AnnotationCanvasView.swift`

```swift
import SwiftUI
import AppKit

struct AnnotationCanvasView: View {
    @ObservedObject var document: AnnotationDocument
    @Binding var selectedTool: AnnotationTool
    @Binding var toolConfig: ToolConfiguration

    @State private var zoomLevel: CGFloat = 1.0
    @State private var panOffset: CGPoint = .zero
    @State private var currentAnnotation: (any Annotation)?
    @State private var dragStart: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                ZStack {
                    // Base image
                    Image(document.baseImage, scale: 1, label: Text("Screenshot"))
                        .resizable()
                        .frame(
                            width: document.canvasSize.width * zoomLevel,
                            height: document.canvasSize.height * zoomLevel
                        )

                    // Annotations layer
                    AnnotationsLayer(
                        document: document,
                        zoomLevel: zoomLevel,
                        selectedIds: document.selectedAnnotationIds
                    )

                    // Current drawing annotation
                    if let annotation = currentAnnotation {
                        CurrentAnnotationView(
                            annotation: annotation,
                            zoomLevel: zoomLevel
                        )
                    }
                }
                .frame(
                    width: document.canvasSize.width * zoomLevel,
                    height: document.canvasSize.height * zoomLevel
                )
                .gesture(canvasGesture)
            }
        }
        .background(CanvasBackground())
    }

    private var canvasGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let point = value.location.scaled(by: 1 / zoomLevel)

                if dragStart == nil {
                    dragStart = point
                    handleDragStart(at: point)
                }

                handleDragUpdate(to: point)
            }
            .onEnded { value in
                let point = value.location.scaled(by: 1 / zoomLevel)
                handleDragEnd(at: point)
                dragStart = nil
            }
    }

    private func handleDragStart(at point: CGPoint) {
        switch selectedTool {
        case .select:
            _ = document.selectAnnotation(at: point)

        case .arrow:
            currentAnnotation = ArrowAnnotation(
                from: point,
                to: point,
                color: toolConfig.color,
                strokeWidth: toolConfig.strokeWidth
            )

        case .rectangle:
            currentAnnotation = ShapeAnnotation(
                id: UUID(),
                bounds: CGRect(origin: point, size: .zero),
                shapeType: .rectangle,
                fillColor: toolConfig.fillEnabled ? toolConfig.color : nil,
                strokeColor: toolConfig.color,
                strokeWidth: toolConfig.strokeWidth
            )

        case .ellipse:
            currentAnnotation = ShapeAnnotation(
                id: UUID(),
                bounds: CGRect(origin: point, size: .zero),
                shapeType: .ellipse,
                fillColor: toolConfig.fillEnabled ? toolConfig.color : nil,
                strokeColor: toolConfig.color,
                strokeWidth: toolConfig.strokeWidth
            )

        case .line:
            currentAnnotation = ShapeAnnotation(
                id: UUID(),
                bounds: CGRect(origin: point, size: .zero),
                shapeType: .line,
                fillColor: nil,
                strokeColor: toolConfig.color,
                strokeWidth: toolConfig.strokeWidth
            )

        case .text:
            // Text tool opens editor on click
            break

        case .blur:
            currentAnnotation = BlurAnnotation(
                id: UUID(),
                bounds: CGRect(origin: point, size: .zero),
                blurType: .gaussian,
                intensity: toolConfig.blurIntensity
            )

        case .pixelate:
            currentAnnotation = BlurAnnotation(
                id: UUID(),
                bounds: CGRect(origin: point, size: .zero),
                blurType: .pixelate,
                intensity: toolConfig.blurIntensity
            )

        case .highlighter:
            currentAnnotation = HighlighterAnnotation(
                id: UUID(),
                bounds: CGRect(origin: point, size: .zero),
                points: [point],
                color: toolConfig.color,
                strokeWidth: toolConfig.strokeWidth * 3
            )

        case .counter:
            let counter = CounterAnnotation(
                number: document.annotations.compactMap { $0 as? CounterAnnotation }.count + 1,
                at: point,
                color: toolConfig.color
            )
            document.addAnnotation(counter)

        case .crop:
            // Crop tool has special handling
            break
        }
    }

    private func handleDragUpdate(to point: CGPoint) {
        guard let start = dragStart else { return }

        switch selectedTool {
        case .arrow:
            if var arrow = currentAnnotation as? ArrowAnnotation {
                arrow.endPoint = point
                arrow.bounds = CGRect(
                    x: min(start.x, point.x),
                    y: min(start.y, point.y),
                    width: abs(point.x - start.x),
                    height: abs(point.y - start.y)
                ).insetBy(dx: -20, dy: -20)
                currentAnnotation = arrow
            }

        case .rectangle, .ellipse, .blur, .pixelate:
            if var shape = currentAnnotation as? ShapeAnnotation {
                shape.bounds = CGRect(
                    x: min(start.x, point.x),
                    y: min(start.y, point.y),
                    width: abs(point.x - start.x),
                    height: abs(point.y - start.y)
                )
                currentAnnotation = shape
            } else if var blur = currentAnnotation as? BlurAnnotation {
                blur.bounds = CGRect(
                    x: min(start.x, point.x),
                    y: min(start.y, point.y),
                    width: abs(point.x - start.x),
                    height: abs(point.y - start.y)
                )
                currentAnnotation = blur
            }

        case .line:
            if var shape = currentAnnotation as? ShapeAnnotation {
                shape.bounds = CGRect(
                    x: min(start.x, point.x),
                    y: min(start.y, point.y),
                    width: abs(point.x - start.x),
                    height: abs(point.y - start.y)
                )
                currentAnnotation = shape
            }

        case .highlighter:
            if var highlighter = currentAnnotation as? HighlighterAnnotation {
                highlighter.points.append(point)
                highlighter.bounds = highlighter.bounds.union(
                    CGRect(origin: point, size: CGSize(width: 1, height: 1))
                )
                currentAnnotation = highlighter
            }

        default:
            break
        }
    }

    private func handleDragEnd(at point: CGPoint) {
        if let annotation = currentAnnotation {
            // Only add if it has meaningful size
            if annotation.bounds.width > 5 || annotation.bounds.height > 5 {
                document.addAnnotation(annotation)
            }
        }
        currentAnnotation = nil
    }
}

// MARK: - Supporting Views

struct AnnotationsLayer: View {
    @ObservedObject var document: AnnotationDocument
    let zoomLevel: CGFloat
    let selectedIds: Set<UUID>

    var body: some View {
        ForEach(document.annotations.sorted { $0.zIndex < $1.zIndex }, id: \.id) { annotation in
            AnnotationView(
                annotation: annotation,
                isSelected: selectedIds.contains(annotation.id),
                zoomLevel: zoomLevel
            )
        }
    }
}

struct AnnotationView: View {
    let annotation: any Annotation
    let isSelected: Bool
    let zoomLevel: CGFloat

    var body: some View {
        Canvas { context, size in
            var cgContext = context
            annotation.render(in: cgContext as! CGContext, scale: zoomLevel)
        }
        .frame(
            width: annotation.bounds.width * zoomLevel,
            height: annotation.bounds.height * zoomLevel
        )
        .position(
            x: annotation.bounds.midX * zoomLevel,
            y: annotation.bounds.midY * zoomLevel
        )
        .overlay(
            SelectionHandles(isVisible: isSelected)
        )
    }
}

struct SelectionHandles: View {
    let isVisible: Bool

    var body: some View {
        if isVisible {
            GeometryReader { geometry in
                ZStack {
                    // Selection border
                    Rectangle()
                        .stroke(Color.accentColor, lineWidth: 1)

                    // Corner handles
                    ForEach(Corner.allCases, id: \.self) { corner in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.accentColor, lineWidth: 1))
                            .position(corner.position(in: geometry.size))
                    }
                }
            }
        }
    }

    enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight

        func position(in size: CGSize) -> CGPoint {
            switch self {
            case .topLeft: return CGPoint(x: 0, y: 0)
            case .topRight: return CGPoint(x: size.width, y: 0)
            case .bottomLeft: return CGPoint(x: 0, y: size.height)
            case .bottomRight: return CGPoint(x: size.width, y: size.height)
            }
        }
    }
}

struct CanvasBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let gridSize: CGFloat = 20
                for x in stride(from: 0, to: geometry.size.width, by: gridSize) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                for y in stride(from: 0, to: geometry.size.height, by: gridSize) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Extensions

extension CGPoint {
    func scaled(by factor: CGFloat) -> CGPoint {
        CGPoint(x: x * factor, y: y * factor)
    }
}
```

---

### 4.4 Implement Annotation Toolbar

**File**: `Features/Annotation/Views/AnnotationToolbar.swift`

```swift
import SwiftUI

enum AnnotationTool: String, CaseIterable {
    case select = "Select"
    case arrow = "Arrow"
    case rectangle = "Rectangle"
    case ellipse = "Ellipse"
    case line = "Line"
    case text = "Text"
    case blur = "Blur"
    case pixelate = "Pixelate"
    case highlighter = "Highlighter"
    case counter = "Counter"
    case crop = "Crop"

    var icon: String {
        switch self {
        case .select: return "arrow.up.left.and.arrow.down.right"
        case .arrow: return "arrow.right"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .line: return "line.diagonal"
        case .text: return "textformat"
        case .blur: return "drop.fill"
        case .pixelate: return "square.grid.3x3"
        case .highlighter: return "highlighter"
        case .counter: return "number.circle"
        case .crop: return "crop"
        }
    }

    var shortcut: String? {
        switch self {
        case .select: return "V"
        case .arrow: return "A"
        case .rectangle: return "R"
        case .ellipse: return "O"
        case .line: return "L"
        case .text: return "T"
        case .blur: return "B"
        case .pixelate: return "P"
        case .highlighter: return "H"
        case .counter: return "N"
        case .crop: return "C"
        default: return nil
        }
    }
}

struct ToolConfiguration {
    var color: AnnotationColor = .red
    var strokeWidth: CGFloat = 3
    var fillEnabled: Bool = false
    var blurIntensity: CGFloat = 0.5
    var fontSize: CGFloat = 16
    var fontWeight: TextAnnotation.AnnotationFont.FontWeight = .regular
}

struct AnnotationToolbar: View {
    @Binding var selectedTool: AnnotationTool
    @Binding var config: ToolConfiguration
    @ObservedObject var document: AnnotationDocument

    var body: some View {
        HStack(spacing: 0) {
            // Undo/Redo
            HStack(spacing: 4) {
                ToolbarButton(icon: "arrow.uturn.backward", tooltip: "Undo") {
                    document.undo()
                }
                .disabled(!document.canUndo)

                ToolbarButton(icon: "arrow.uturn.forward", tooltip: "Redo") {
                    document.redo()
                }
                .disabled(!document.canRedo)
            }
            .padding(.horizontal, 8)

            Divider()
                .frame(height: 24)

            // Drawing tools
            HStack(spacing: 2) {
                ForEach([AnnotationTool.select, .arrow, .rectangle, .ellipse, .line], id: \.self) { tool in
                    ToolButton(tool: tool, selectedTool: $selectedTool)
                }
            }
            .padding(.horizontal, 8)

            Divider()
                .frame(height: 24)

            // Text and privacy
            HStack(spacing: 2) {
                ForEach([AnnotationTool.text, .blur, .pixelate], id: \.self) { tool in
                    ToolButton(tool: tool, selectedTool: $selectedTool)
                }
            }
            .padding(.horizontal, 8)

            Divider()
                .frame(height: 24)

            // Special tools
            HStack(spacing: 2) {
                ForEach([AnnotationTool.highlighter, .counter, .crop], id: \.self) { tool in
                    ToolButton(tool: tool, selectedTool: $selectedTool)
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            // Color picker
            ColorPickerButton(selectedColor: $config.color)
                .padding(.horizontal, 8)

            // Stroke width
            StrokeWidthPicker(width: $config.strokeWidth)
                .padding(.horizontal, 8)
        }
        .frame(height: 44)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct ToolButton: View {
    let tool: AnnotationTool
    @Binding var selectedTool: AnnotationTool

    var isSelected: Bool { selectedTool == tool }

    var body: some View {
        Button {
            selectedTool = tool
        } label: {
            Image(systemName: tool.icon)
                .font(.system(size: 14))
                .frame(width: 32, height: 32)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(tool.rawValue + (tool.shortcut.map { " (\($0))" } ?? ""))
    }
}

struct ToolbarButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

struct ColorPickerButton: View {
    @Binding var selectedColor: AnnotationColor

    static let colors: [AnnotationColor] = [.red, .orange, .yellow, .green, .blue, .purple, .black, .white]

    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Circle()
                .fill(Color(cgColor: selectedColor.cgColor))
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(Color.gray, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(28)), count: 4), spacing: 8) {
                ForEach(Self.colors, id: \.self) { color in
                    Button {
                        selectedColor = color
                        showPopover = false
                    } label: {
                        Circle()
                            .fill(Color(cgColor: color.cgColor))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle().stroke(
                                    color == selectedColor ? Color.accentColor : Color.clear,
                                    lineWidth: 2
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
    }
}

struct StrokeWidthPicker: View {
    @Binding var width: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            ForEach([1, 2, 3, 5, 8] as [CGFloat], id: \.self) { w in
                Button {
                    width = w
                } label: {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: w * 2 + 4, height: w * 2 + 4)
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(width == w ? Color.accentColor.opacity(0.2) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
```

---

### 4.5 Implement Annotation Editor Window

**File**: `Features/Annotation/AnnotationEditorWindow.swift`

```swift
import SwiftUI
import AppKit

@MainActor
final class AnnotationEditorWindowController {
    private var window: NSWindow?
    private var document: AnnotationDocument?

    func open(with result: CaptureService.CaptureResult, coordinator: AppCoordinator) {
        let document = AnnotationDocument(result: result)
        self.document = document

        let contentView = AnnotationEditorView(
            document: document,
            onSave: { [weak self] in self?.save(coordinator: coordinator) },
            onCopy: { [weak self] in self?.copyToClipboard() },
            onClose: { [weak self] in self?.close() }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Annotate Screenshot"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }

    private func save(coordinator: AppCoordinator) {
        guard let document = document,
              let data = document.export(format: coordinator.settingsManager.settings.defaultImageFormat) else {
            return
        }

        let filename = coordinator.settingsManager.generateFilename(for: .screenshot)

        do {
            let url = try coordinator.storageService.save(
                imageData: data,
                filename: filename,
                to: coordinator.settingsManager.settings.defaultSaveLocation
            )

            // Show in Finder
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")

            close()
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func copyToClipboard() {
        guard let document = document,
              let image = document.renderWithBlur() else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([NSImage(cgImage: image, size: document.canvasSize)])

        close()
    }

    private func close() {
        window?.close()
        window = nil
        document = nil
    }
}

struct AnnotationEditorView: View {
    @ObservedObject var document: AnnotationDocument

    let onSave: () -> Void
    let onCopy: () -> Void
    let onClose: () -> Void

    @State private var selectedTool: AnnotationTool = .arrow
    @State private var toolConfig = ToolConfiguration()

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            AnnotationToolbar(
                selectedTool: $selectedTool,
                config: $toolConfig,
                document: document
            )

            Divider()

            // Canvas
            AnnotationCanvasView(
                document: document,
                selectedTool: $selectedTool,
                toolConfig: $toolConfig
            )

            Divider()

            // Bottom bar
            HStack {
                Button("Cancel") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Copy") {
                    onCopy()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("Save") {
                    onSave()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }
}
```

---

## File Structure After Milestone 4

```
ScreenPro/
├── ... (previous files)
│
├── Features/
│   ├── Annotation/
│   │   ├── Models/
│   │   │   ├── Annotation.swift
│   │   │   └── AnnotationDocument.swift
│   │   ├── Views/
│   │   │   ├── AnnotationCanvasView.swift
│   │   │   ├── AnnotationToolbar.swift
│   │   │   └── PropertyPanel.swift
│   │   └── AnnotationEditorWindow.swift
│   └── ...
```

---

## Testing Checklist

- [ ] Arrow tool creates arrows with heads
- [ ] Rectangle/ellipse tools work
- [ ] Text tool adds editable text
- [ ] Blur/pixelate obscures regions
- [ ] Highlighter creates transparent strokes
- [ ] Counter adds sequential numbers
- [ ] Crop tool resizes canvas
- [ ] Color picker changes colors
- [ ] Stroke width affects tools
- [ ] Undo/redo works for all operations
- [ ] Selection allows moving annotations
- [ ] Export produces correct image
- [ ] Copy pastes to clipboard

---

## Exit Criteria

| Criterion | Verification |
|-----------|--------------|
| All tools functional | Test each tool |
| Undo/redo works | Multi-step undo |
| Export quality | Compare with original |
| Performance | Smooth drawing at 60fps |
| Memory | Stable with large images |

---

## Next Steps

Proceed to [Milestone 5: Screen Recording](./05-screen-recording.md).
