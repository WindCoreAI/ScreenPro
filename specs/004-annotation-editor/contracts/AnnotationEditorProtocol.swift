// MARK: - Annotation Editor Protocol
// Contract: specs/004-annotation-editor/contracts/AnnotationEditorProtocol.swift
// Feature: 004-annotation-editor
//
// This file defines the protocol contract for the annotation editor window controller.

import Foundation
import AppKit

// MARK: - Annotation Editor Window Controller Protocol

/// Protocol for the annotation editor window controller.
/// Manages the editor window lifecycle and actions.
@MainActor
protocol AnnotationEditorWindowControllerProtocol {
    /// Opens the editor with a capture result.
    /// - Parameters:
    ///   - result: The capture result to annotate.
    ///   - coordinator: The app coordinator for state management.
    func open(with result: CaptureResult, coordinator: AppCoordinator)

    /// Closes the editor window.
    func close()
}

// MARK: - Annotation Editor Actions

/// Actions available in the annotation editor.
enum AnnotationEditorAction {
    /// Save the annotated image to disk.
    case save

    /// Copy the annotated image to clipboard.
    case copy

    /// Discard changes and close.
    case cancel

    /// Undo the last action.
    case undo

    /// Redo the last undone action.
    case redo

    /// Delete selected annotations.
    case delete

    /// Select all annotations.
    case selectAll
}

// MARK: - Editor Delegate

/// Delegate protocol for annotation editor events.
@MainActor
protocol AnnotationEditorDelegate: AnyObject {
    /// Called when the user saves the annotated image.
    /// - Parameters:
    ///   - data: The exported image data.
    ///   - format: The image format.
    func annotationEditor(didSave data: Data, format: ImageFormat)

    /// Called when the user copies the annotated image.
    /// - Parameter image: The rendered image.
    func annotationEditor(didCopy image: CGImage)

    /// Called when the editor is closed.
    /// - Parameter saved: Whether changes were saved.
    func annotationEditor(didClose saved: Bool)
}

// MARK: - Accessibility Labels

/// Accessibility labels for annotation editor UI elements.
/// Ensures VoiceOver compatibility per Constitution VI.
enum AnnotationEditorAccessibility {
    static let toolbar = "Annotation Toolbar"
    static let canvas = "Annotation Canvas"
    static let undoButton = "Undo"
    static let redoButton = "Redo"
    static let saveButton = "Save annotated image"
    static let copyButton = "Copy to clipboard"
    static let cancelButton = "Cancel and discard changes"
    static let colorPicker = "Annotation color"
    static let strokeWidthPicker = "Stroke width"

    /// Tool-specific labels.
    static func toolLabel(for tool: AnnotationTool) -> String {
        switch tool {
        case .select: return "Select tool"
        case .arrow: return "Arrow tool"
        case .rectangle: return "Rectangle tool"
        case .ellipse: return "Ellipse tool"
        case .line: return "Line tool"
        case .text: return "Text tool"
        case .blur: return "Blur tool"
        case .pixelate: return "Pixelate tool"
        case .highlighter: return "Highlighter tool"
        case .counter: return "Counter tool"
        case .crop: return "Crop tool"
        }
    }

    /// Tool hint including keyboard shortcut.
    static func toolHint(for tool: AnnotationTool) -> String {
        let base = tool.rawValue
        if let shortcut = tool.shortcut {
            return "\(base) (\(shortcut))"
        }
        return base
    }
}

// MARK: - Keyboard Shortcuts

/// Keyboard shortcuts for annotation editor.
enum AnnotationEditorShortcuts {
    static let undo = "⌘Z"
    static let redo = "⇧⌘Z"
    static let save = "⌘S"
    static let copy = "⇧⌘C"
    static let cancel = "⎋" // Escape
    static let delete = "⌫" // Delete key
    static let selectAll = "⌘A"
}
