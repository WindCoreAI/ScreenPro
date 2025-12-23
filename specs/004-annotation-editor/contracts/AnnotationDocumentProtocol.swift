// MARK: - Annotation Document Protocol
// Contract: specs/004-annotation-editor/contracts/AnnotationDocumentProtocol.swift
// Feature: 004-annotation-editor
//
// This file defines the protocol contract for the annotation document model.
// The document manages the base image, annotations, selection, and undo/redo.

import Foundation
import CoreGraphics
import AppKit

// MARK: - Annotation Document Protocol

/// Protocol defining the annotation document interface.
/// The document manages annotations, selection state, and undo/redo history.
@MainActor
protocol AnnotationDocumentProtocol: ObservableObject {
    // MARK: - Properties

    /// The base screenshot image.
    var baseImage: CGImage { get }

    /// All annotations on the canvas.
    var annotations: [any Annotation] { get }

    /// IDs of currently selected annotations.
    var selectedAnnotationIds: Set<UUID> { get set }

    /// Canvas dimensions (may differ from image if expanded).
    var canvasSize: CGSize { get }

    /// Whether undo is available.
    var canUndo: Bool { get }

    /// Whether redo is available.
    var canRedo: Bool { get }

    // MARK: - Annotation Management

    /// Adds an annotation to the document with undo support.
    /// - Parameter annotation: The annotation to add.
    func addAnnotation(_ annotation: any Annotation)

    /// Removes an annotation by ID with undo support.
    /// - Parameter id: The UUID of the annotation to remove.
    func removeAnnotation(id: UUID)

    /// Updates an existing annotation with undo support.
    /// - Parameter annotation: The updated annotation (matched by ID).
    func updateAnnotation<T: Annotation>(_ annotation: T)

    /// Removes all annotations with undo support.
    func clearAnnotations()

    // MARK: - Selection

    /// Selects the annotation at the given point.
    /// - Parameter point: Point in canvas coordinates.
    /// - Returns: The selected annotation, or nil if none hit.
    @discardableResult
    func selectAnnotation(at point: CGPoint) -> (any Annotation)?

    /// Selects all annotations within the given rect.
    /// - Parameter rect: Selection rectangle in canvas coordinates.
    func selectAnnotations(in rect: CGRect)

    /// Clears the selection.
    func deselectAll()

    /// Currently selected annotations.
    var selectedAnnotations: [any Annotation] { get }

    // MARK: - Undo/Redo

    /// Undoes the last action.
    func undo()

    /// Redoes the last undone action.
    func redo()

    // MARK: - Rendering

    /// Renders all annotations to a CGImage.
    /// - Parameter scale: Scale factor for output resolution.
    /// - Returns: The rendered image, or nil on failure.
    func render(scale: CGFloat) -> CGImage?

    /// Renders with blur effects applied (for export).
    /// - Parameter scale: Scale factor for output resolution.
    /// - Returns: The rendered image with blur, or nil on failure.
    func renderWithBlur(scale: CGFloat) -> CGImage?

    // MARK: - Export

    /// Exports the annotated image to the specified format.
    /// - Parameter format: The image format for export.
    /// - Returns: Image data, or nil on failure.
    func export(format: ImageFormat) -> Data?
}

// MARK: - Annotation Document Initialization

/// Protocol for creating annotation documents.
protocol AnnotationDocumentInitializable {
    /// Creates a document from a CGImage.
    init(image: CGImage)

    /// Creates a document from a capture result.
    init(result: CaptureResult)
}
