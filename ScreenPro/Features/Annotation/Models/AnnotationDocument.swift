import Foundation
import CoreGraphics
import AppKit
import Combine

// MARK: - AnnotationDocument (T006, T007, T008)

/// Container for base image and all annotations with undo support.
/// This is the main document model for the annotation editor.
@MainActor
final class AnnotationDocument: ObservableObject {
    // MARK: - Published Properties

    /// The base screenshot image.
    @Published private(set) var baseImage: CGImage

    /// All annotations on the canvas.
    @Published private(set) var annotations: [any Annotation] = []

    /// IDs of currently selected annotations.
    @Published var selectedAnnotationIds: Set<UUID> = []

    /// Canvas dimensions (matches image size initially).
    @Published private(set) var canvasSize: CGSize

    /// Current z-index counter for new annotations.
    private var nextZIndex: Int = 0

    // MARK: - Undo Support

    /// Undo manager for annotation operations.
    let undoManager = UndoManager()

    /// Whether undo is available.
    var canUndo: Bool {
        undoManager.canUndo
    }

    /// Whether redo is available.
    var canRedo: Bool {
        undoManager.canRedo
    }

    // MARK: - Computed Properties

    /// Currently selected annotations.
    var selectedAnnotations: [any Annotation] {
        annotations.filter { selectedAnnotationIds.contains($0.id) }
    }

    /// Whether any annotations exist.
    var hasAnnotations: Bool {
        !annotations.isEmpty
    }

    /// Whether there are unsaved changes.
    var hasUnsavedChanges: Bool {
        undoManager.canUndo
    }

    // MARK: - Initialization

    /// Creates a document from a CGImage.
    init(image: CGImage) {
        self.baseImage = image
        self.canvasSize = CGSize(width: image.width, height: image.height)
    }

    /// Creates a document from a CaptureResult.
    init(result: CaptureResult) {
        self.baseImage = result.image
        self.canvasSize = CGSize(width: result.image.width, height: result.image.height)
    }

    // MARK: - Annotation Management (T007)

    /// Adds an annotation to the document with undo support.
    /// - Parameter annotation: The annotation to add.
    func addAnnotation(_ annotation: any Annotation) {
        // Assign z-index
        annotation.zIndex = nextZIndex
        nextZIndex += 1

        // Store current state for undo
        let annotationsCopy = annotations

        // Add annotation
        annotations.append(annotation)

        // Register undo
        undoManager.registerUndo(withTarget: self) { [weak self] doc in
            doc.annotations = annotationsCopy
            doc.nextZIndex -= 1
        }
        undoManager.setActionName("Add Annotation")
    }

    /// Removes an annotation by ID with undo support.
    /// - Parameter id: The UUID of the annotation to remove.
    func removeAnnotation(id: UUID) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }

        // Store current state for undo
        let annotationsCopy = annotations
        let removedAnnotation = annotations[index]

        // Remove annotation
        annotations.remove(at: index)
        selectedAnnotationIds.remove(id)

        // Register undo
        undoManager.registerUndo(withTarget: self) { [weak self] doc in
            doc.annotations = annotationsCopy
            if removedAnnotation.isSelected {
                doc.selectedAnnotationIds.insert(id)
            }
        }
        undoManager.setActionName("Remove Annotation")
    }

    /// Updates an existing annotation with undo support.
    /// - Parameter annotation: The updated annotation (matched by ID).
    func updateAnnotation(_ annotation: any Annotation) {
        guard let index = annotations.firstIndex(where: { $0.id == annotation.id }) else { return }

        // Store current state for undo
        let annotationsCopy = annotations

        // Update annotation
        annotations[index] = annotation

        // Register undo
        undoManager.registerUndo(withTarget: self) { [weak self] doc in
            doc.annotations = annotationsCopy
        }
        undoManager.setActionName("Update Annotation")
    }

    /// Removes all annotations with undo support.
    func clearAnnotations() {
        guard !annotations.isEmpty else { return }

        // Store current state for undo
        let annotationsCopy = annotations
        let selectedCopy = selectedAnnotationIds

        // Clear annotations
        annotations.removeAll()
        selectedAnnotationIds.removeAll()

        // Register undo
        undoManager.registerUndo(withTarget: self) { [weak self] doc in
            doc.annotations = annotationsCopy
            doc.selectedAnnotationIds = selectedCopy
        }
        undoManager.setActionName("Clear All Annotations")
    }

    // MARK: - Selection (T008)

    /// Selects the annotation at the given point.
    /// - Parameter point: Point in canvas coordinates.
    /// - Returns: The selected annotation, or nil if none hit.
    @discardableResult
    func selectAnnotation(at point: CGPoint) -> (any Annotation)? {
        // Hit test in reverse z-order (top to bottom)
        for annotation in annotations.reversed() {
            if annotation.hitTest(point) {
                // Clear previous selection and select this one
                deselectAll()
                annotation.isSelected = true
                selectedAnnotationIds.insert(annotation.id)
                return annotation
            }
        }

        // No hit - clear selection
        deselectAll()
        return nil
    }

    /// Selects all annotations within the given rect.
    /// - Parameter rect: Selection rectangle in canvas coordinates.
    func selectAnnotations(in rect: CGRect) {
        deselectAll()

        for annotation in annotations {
            if rect.intersects(annotation.transformedBounds) {
                annotation.isSelected = true
                selectedAnnotationIds.insert(annotation.id)
            }
        }
    }

    /// Clears the selection.
    func deselectAll() {
        for annotation in annotations {
            annotation.isSelected = false
        }
        selectedAnnotationIds.removeAll()
    }

    /// Toggles selection state for an annotation.
    /// - Parameter id: The annotation ID to toggle.
    func toggleSelection(id: UUID) {
        guard let annotation = annotations.first(where: { $0.id == id }) else { return }

        if selectedAnnotationIds.contains(id) {
            annotation.isSelected = false
            selectedAnnotationIds.remove(id)
        } else {
            annotation.isSelected = true
            selectedAnnotationIds.insert(id)
        }
    }

    // MARK: - Undo/Redo

    /// Undoes the last action.
    func undo() {
        undoManager.undo()
    }

    /// Redoes the last undone action.
    func redo() {
        undoManager.redo()
    }

    // MARK: - Rendering (placeholder - full implementation in US1)

    /// Renders all annotations to a CGImage.
    /// - Parameter scale: Scale factor for output resolution.
    /// - Returns: The rendered image, or nil on failure.
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
        ) else {
            return nil
        }

        // Draw base image
        context.draw(baseImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Apply scale for annotation rendering
        context.scaleBy(x: scale, y: scale)

        // Render annotations in z-order
        let sortedAnnotations = annotations.sorted { $0.zIndex < $1.zIndex }
        for annotation in sortedAnnotations {
            annotation.render(in: context, scale: scale)
        }

        return context.makeImage()
    }

    // MARK: - Canvas Operations (T105, T106, T108)

    /// Updates the canvas size (used by crop).
    /// - Parameter newSize: The new canvas size.
    func setCanvasSize(_ newSize: CGSize) {
        canvasSize = newSize
    }

    /// Updates the base image (used by crop).
    /// - Parameter image: The new base image.
    func setBaseImage(_ image: CGImage) {
        baseImage = image
        canvasSize = CGSize(width: image.width, height: image.height)
    }

    /// Applies a crop to the document with undo support (T105, T106, T108).
    /// - Parameter cropRect: The crop rectangle in canvas coordinates.
    /// - Returns: True if crop was applied successfully.
    @discardableResult
    func applyCrop(_ cropRect: CGRect) -> Bool {
        // Validate crop rect
        let normalizedRect = cropRect.intersection(CGRect(origin: .zero, size: canvasSize))
        guard normalizedRect.width >= 10, normalizedRect.height >= 10 else {
            return false
        }

        // Store current state for undo
        let previousImage = baseImage
        let previousCanvasSize = canvasSize
        let previousAnnotations = annotations

        // Crop the base image
        guard let croppedImage = cropImage(baseImage, to: normalizedRect) else {
            return false
        }

        // Update document state
        baseImage = croppedImage
        canvasSize = normalizedRect.size

        // Offset all annotations by the crop origin
        for annotation in annotations {
            annotation.bounds = CGRect(
                x: annotation.bounds.origin.x - normalizedRect.origin.x,
                y: annotation.bounds.origin.y - normalizedRect.origin.y,
                width: annotation.bounds.width,
                height: annotation.bounds.height
            )
        }

        // Register undo (T108)
        undoManager.registerUndo(withTarget: self) { [weak self] doc in
            doc.baseImage = previousImage
            doc.canvasSize = previousCanvasSize
            doc.annotations = previousAnnotations
        }
        undoManager.setActionName("Crop")

        return true
    }

    /// Crops a CGImage to the specified rect.
    private func cropImage(_ image: CGImage, to rect: CGRect) -> CGImage? {
        // Convert to image coordinates (CGImage uses integer coordinates)
        let cropRect = CGRect(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.width,
            height: rect.height
        )

        return image.cropping(to: cropRect)
    }
}
