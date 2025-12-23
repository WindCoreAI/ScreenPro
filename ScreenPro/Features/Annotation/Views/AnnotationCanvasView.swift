import SwiftUI
import AppKit

// MARK: - AnnotationCanvasView (T009, T018, T019)

/// The main canvas view for the annotation editor.
/// Displays the base image with annotations overlaid and handles user input.
struct AnnotationCanvasView: View {
    @ObservedObject var document: AnnotationDocument
    @ObservedObject var toolConfig: ToolConfiguration
    @StateObject private var counterHandler: CounterToolHandler
    @StateObject private var cropHandler: CropToolHandler = CropToolHandler()

    // MARK: - Initialization

    init(document: AnnotationDocument, toolConfig: ToolConfiguration) {
        self._document = ObservedObject(wrappedValue: document)
        self._toolConfig = ObservedObject(wrappedValue: toolConfig)
        self._counterHandler = StateObject(wrappedValue: CounterToolHandler(toolConfig: toolConfig))
    }

    // MARK: - State

    /// Current zoom level (1.0 = 100%).
    @State private var zoomLevel: CGFloat = 1.0

    /// Current scroll offset for pan.
    @State private var scrollOffset: CGPoint = .zero

    /// Drag start point for creating annotations.
    @State private var dragStart: CGPoint?

    /// Current drag point during annotation creation.
    @State private var dragCurrent: CGPoint?

    /// Whether a drag operation is in progress.
    @State private var isDragging: Bool = false

    /// Points collected during highlighter drawing.
    @State private var highlighterPoints: [CGPoint] = []

    /// Minimum distance between consecutive highlighter points.
    private let minHighlighterPointDistance: CGFloat = 3

    // MARK: - Constants

    private let minZoom: CGFloat = 0.25
    private let maxZoom: CGFloat = 4.0
    private let zoomStep: CGFloat = 0.25

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack {
                    // Base image layer
                    baseImageLayer

                    // Annotations layer
                    AnnotationsLayer(
                        document: document,
                        scale: zoomLevel
                    )

                    // Current annotation preview (during drag)
                    if let start = dragStart, let current = dragCurrent {
                        currentAnnotationPreview(from: start, to: current)
                    }

                    // Highlighter preview during drawing
                    if !highlighterPoints.isEmpty && toolConfig.selectedTool == .highlighter {
                        HighlighterPreviewView(
                            points: highlighterPoints,
                            color: toolConfig.color.color,
                            strokeWidth: max(toolConfig.strokeWidth * 5, 15),
                            scale: zoomLevel
                        )
                    }

                    // Selection handles for selected annotations
                    ForEach(document.selectedAnnotations.map { $0.id }, id: \.self) { id in
                        if let annotation = document.annotations.first(where: { $0.id == id }) {
                            SelectionHandlesView(
                                bounds: annotation.bounds,
                                scale: zoomLevel,
                                onMove: { delta in
                                    moveSelectedAnnotations(by: delta)
                                },
                                onResize: { corner, delta in
                                    resizeSelectedAnnotation(corner: corner, delta: delta)
                                }
                            )
                        }
                    }

                    // Crop overlay (T103)
                    if cropHandler.isActive {
                        CropOverlayView(
                            cropRect: cropHandler.cropRect,
                            canvasSize: document.canvasSize,
                            scale: zoomLevel,
                            isValid: cropHandler.isValidCrop
                        )
                    }
                }
                .frame(
                    width: document.canvasSize.width * zoomLevel,
                    height: document.canvasSize.height * zoomLevel
                )
                .gesture(canvasGesture)
                .onTapGesture { location in
                    handleTap(at: location)
                }
                // Crop confirmation bar (T104)
                .overlay(alignment: .bottom) {
                    if cropHandler.isActive {
                        CropConfirmationBar(
                            onConfirm: {
                                cropHandler.confirmCrop(document: document)
                            },
                            onCancel: {
                                cropHandler.cancelCrop()
                            },
                            isValid: cropHandler.isValidCrop
                        )
                        .padding(.bottom, 20)
                    }
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .onAppear {
                fitToWindow(geometry: geometry)
            }
        }
        .focusable()
        .onKeyPress { keyPress in
            handleKeyPress(keyPress)
        }
    }

    // MARK: - Layers

    private var baseImageLayer: some View {
        Image(nsImage: NSImage(cgImage: document.baseImage, size: document.canvasSize))
            .resizable()
            .frame(
                width: document.canvasSize.width * zoomLevel,
                height: document.canvasSize.height * zoomLevel
            )
    }

    @ViewBuilder
    private func currentAnnotationPreview(from start: CGPoint, to end: CGPoint) -> some View {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        // Scale rect for display
        let displayRect = CGRect(
            x: rect.origin.x * zoomLevel,
            y: rect.origin.y * zoomLevel,
            width: rect.width * zoomLevel,
            height: rect.height * zoomLevel
        )

        switch toolConfig.selectedTool {
        case .rectangle, .crop:
            Rectangle()
                .stroke(toolConfig.color.color, lineWidth: toolConfig.strokeWidth)
                .frame(width: displayRect.width, height: displayRect.height)
                .position(x: displayRect.midX, y: displayRect.midY)

        case .blur:
            // Blur preview with gaussian indicator
            BlurPreviewView(
                bounds: rect,
                blurType: .gaussian,
                scale: zoomLevel
            )

        case .pixelate:
            // Pixelate preview with grid indicator
            BlurPreviewView(
                bounds: rect,
                blurType: .pixelate,
                scale: zoomLevel
            )

        case .ellipse:
            Ellipse()
                .stroke(toolConfig.color.color, lineWidth: toolConfig.strokeWidth)
                .frame(width: displayRect.width, height: displayRect.height)
                .position(x: displayRect.midX, y: displayRect.midY)

        case .arrow:
            // Arrow preview with arrowhead
            ArrowPreviewView(
                startPoint: start,
                endPoint: end,
                color: toolConfig.color.color,
                strokeWidth: toolConfig.strokeWidth,
                scale: zoomLevel
            )

        case .line:
            // Line preview (no arrowhead)
            Path { path in
                path.move(to: CGPoint(x: start.x * zoomLevel, y: start.y * zoomLevel))
                path.addLine(to: CGPoint(x: end.x * zoomLevel, y: end.y * zoomLevel))
            }
            .stroke(toolConfig.color.color, lineWidth: toolConfig.strokeWidth)

        default:
            EmptyView()
        }
    }

    // MARK: - Gestures

    private var canvasGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let canvasPoint = CGPoint(
                    x: value.location.x / zoomLevel,
                    y: value.location.y / zoomLevel
                )

                // Special handling for highlighter tool - collect continuous points
                if toolConfig.selectedTool == .highlighter {
                    if highlighterPoints.isEmpty {
                        let startPoint = CGPoint(
                            x: value.startLocation.x / zoomLevel,
                            y: value.startLocation.y / zoomLevel
                        )
                        highlighterPoints = [startPoint]
                    }

                    // Add point if it's far enough from the last point
                    if let lastPoint = highlighterPoints.last {
                        let distance = hypot(canvasPoint.x - lastPoint.x, canvasPoint.y - lastPoint.y)
                        if distance >= minHighlighterPointDistance {
                            highlighterPoints.append(canvasPoint)
                        }
                    }
                    isDragging = true
                    return
                }

                // Standard drag handling for other tools
                if dragStart == nil {
                    dragStart = CGPoint(
                        x: value.startLocation.x / zoomLevel,
                        y: value.startLocation.y / zoomLevel
                    )
                }

                dragCurrent = canvasPoint
                isDragging = true
            }
            .onEnded { value in
                let endPoint = CGPoint(
                    x: value.location.x / zoomLevel,
                    y: value.location.y / zoomLevel
                )

                // Special handling for highlighter tool
                if toolConfig.selectedTool == .highlighter {
                    // Add final point
                    if let lastPoint = highlighterPoints.last,
                       hypot(endPoint.x - lastPoint.x, endPoint.y - lastPoint.y) >= 1 {
                        highlighterPoints.append(endPoint)
                    }

                    // Create highlighter annotation if we have enough points
                    createHighlighterAnnotation()

                    // Reset state
                    highlighterPoints = []
                    isDragging = false
                    return
                }

                // Standard end handling for other tools
                defer {
                    dragStart = nil
                    dragCurrent = nil
                    isDragging = false
                }

                guard let start = dragStart else { return }

                // Check minimum drag distance (5 points)
                let distance = hypot(endPoint.x - start.x, endPoint.y - start.y)
                guard distance >= 5 else { return }

                // Create annotation based on current tool
                createAnnotation(from: start, to: endPoint)
            }
    }

    /// Creates a highlighter annotation from collected points.
    private func createHighlighterAnnotation() {
        guard highlighterPoints.count >= 2 else { return }

        let highlighter = HighlighterAnnotation(
            points: highlighterPoints,
            color: toolConfig.color,
            strokeWidth: max(toolConfig.strokeWidth * 5, 15)
        )
        document.addAnnotation(highlighter)
    }

    // MARK: - Input Handling

    private func handleTap(at location: CGPoint) {
        let canvasPoint = CGPoint(
            x: location.x / zoomLevel,
            y: location.y / zoomLevel
        )

        switch toolConfig.selectedTool {
        case .select:
            document.selectAnnotation(at: canvasPoint)

        case .text:
            // Text tool: click to place text - create simple text annotation
            createTextAnnotation(at: canvasPoint)

        case .counter:
            // Counter tool: click to place numbered circle (T097, T098)
            createCounterAnnotation(at: canvasPoint)

        default:
            // Other tools use drag gestures
            break
        }
    }

    /// Creates a text annotation at the specified position.
    private func createTextAnnotation(at position: CGPoint) {
        // Create text annotation with prompt text
        let text = TextAnnotation(
            text: "Text",
            position: position,
            textColor: toolConfig.color,
            backgroundColor: nil,
            font: toolConfig.currentFont
        )
        document.addAnnotation(text)
    }

    /// Creates a counter annotation at the specified position (T097, T098).
    private func createCounterAnnotation(at position: CGPoint) {
        counterHandler.handleClick(at: position, document: document)
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        // Tool selection shortcuts (T018)
        if let char = keyPress.characters.first?.lowercased().first {
            for tool in AnnotationTool.allCases {
                if tool.shortcut == char {
                    toolConfig.selectedTool = tool
                    return .handled
                }
            }
        }

        // Delete key removes selected annotations
        if keyPress.key == .delete || keyPress.key == .deleteForward {
            deleteSelectedAnnotations()
            return .handled
        }

        // Escape deselects all
        if keyPress.key == .escape {
            document.deselectAll()
            return .handled
        }

        // Zoom shortcuts
        if keyPress.modifiers.contains(.command) {
            switch keyPress.characters {
            case "=", "+":
                zoomIn()
                return .handled
            case "-":
                zoomOut()
                return .handled
            case "0":
                resetZoom()
                return .handled
            default:
                break
            }
        }

        return .ignored
    }

    // MARK: - Annotation Creation (T028, T029)

    private func createAnnotation(from start: CGPoint, to end: CGPoint) {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        switch toolConfig.selectedTool {
        case .arrow:
            // Create arrow annotation with arrowhead (T028)
            let arrow = ArrowAnnotation(
                startPoint: start,
                endPoint: end,
                style: ArrowStyle(headStyle: .filled, tailStyle: .none, lineStyle: .straight),
                color: toolConfig.color,
                strokeWidth: toolConfig.strokeWidth
            )
            document.addAnnotation(arrow)

        case .line:
            // Create line annotation (arrow without heads)
            let line = ArrowAnnotation(
                startPoint: start,
                endPoint: end,
                style: ArrowStyle(headStyle: .none, tailStyle: .none, lineStyle: .straight),
                color: toolConfig.color,
                strokeWidth: toolConfig.strokeWidth
            )
            document.addAnnotation(line)

        case .blur:
            // Create blur annotation with gaussian blur
            let blur = BlurAnnotation(
                bounds: rect,
                blurType: .gaussian,
                intensity: toolConfig.blurIntensity
            )
            document.addAnnotation(blur)

        case .pixelate:
            // Create blur annotation with pixelate effect
            let pixelate = BlurAnnotation(
                bounds: rect,
                blurType: .pixelate,
                intensity: toolConfig.blurIntensity
            )
            document.addAnnotation(pixelate)

        case .rectangle:
            // Create rectangle shape annotation
            let shape = ShapeAnnotation(
                bounds: rect,
                shapeType: .rectangle,
                fillColor: toolConfig.fillEnabled ? toolConfig.fillColor : nil,
                strokeColor: toolConfig.color,
                strokeWidth: toolConfig.strokeWidth
            )
            document.addAnnotation(shape)

        case .ellipse:
            // Create ellipse shape annotation
            let shape = ShapeAnnotation(
                bounds: rect,
                shapeType: .ellipse,
                fillColor: toolConfig.fillEnabled ? toolConfig.fillColor : nil,
                strokeColor: toolConfig.color,
                strokeWidth: toolConfig.strokeWidth
            )
            document.addAnnotation(shape)

        case .highlighter:
            // Highlighter uses path points (implemented in US7)
            break

        case .crop:
            // Start crop selection (T102)
            cropHandler.startCrop(at: start)
            cropHandler.updateCrop(to: end, constrainAspectRatio: false)
            cropHandler.endCropSelection()

        default:
            break
        }
    }

    // MARK: - Selection Actions

    private func moveSelectedAnnotations(by delta: CGSize) {
        for annotation in document.selectedAnnotations {
            annotation.bounds = annotation.bounds.offsetBy(dx: delta.width, dy: delta.height)
        }
    }

    private func resizeSelectedAnnotation(corner: ResizeCorner, delta: CGSize) {
        // Resize implementation will be added in Polish phase
    }

    private func deleteSelectedAnnotations() {
        for id in document.selectedAnnotationIds {
            document.removeAnnotation(id: id)
        }
    }

    // MARK: - Zoom (T019)

    private func fitToWindow(geometry: GeometryProxy) {
        let widthScale = geometry.size.width / document.canvasSize.width
        let heightScale = geometry.size.height / document.canvasSize.height
        zoomLevel = min(widthScale, heightScale, 1.0)
    }

    private func zoomIn() {
        zoomLevel = min(zoomLevel + zoomStep, maxZoom)
    }

    private func zoomOut() {
        zoomLevel = max(zoomLevel - zoomStep, minZoom)
    }

    private func resetZoom() {
        zoomLevel = 1.0
    }
}

// MARK: - Resize Corner

enum ResizeCorner {
    case topLeft, topRight, bottomLeft, bottomRight
}

// MARK: - Selection Handles View (placeholder)

/// Selection handles for resizing/moving annotations.
/// Full implementation in Polish phase (T109).
struct SelectionHandlesView: View {
    let bounds: CGRect
    let scale: CGFloat
    let onMove: (CGSize) -> Void
    let onResize: (ResizeCorner, CGSize) -> Void

    private let handleSize: CGFloat = 8

    var body: some View {
        let displayBounds = CGRect(
            x: bounds.origin.x * scale,
            y: bounds.origin.y * scale,
            width: bounds.width * scale,
            height: bounds.height * scale
        )

        ZStack {
            // Selection border
            Rectangle()
                .stroke(Color.accentColor, lineWidth: 1)
                .frame(width: displayBounds.width, height: displayBounds.height)
                .position(x: displayBounds.midX, y: displayBounds.midY)

            // Corner handles
            ForEach([
                CGPoint(x: displayBounds.minX, y: displayBounds.minY),
                CGPoint(x: displayBounds.maxX, y: displayBounds.minY),
                CGPoint(x: displayBounds.minX, y: displayBounds.maxY),
                CGPoint(x: displayBounds.maxX, y: displayBounds.maxY)
            ], id: \.debugDescription) { point in
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 1))
                    .frame(width: handleSize, height: handleSize)
                    .position(point)
            }
        }
    }
}
