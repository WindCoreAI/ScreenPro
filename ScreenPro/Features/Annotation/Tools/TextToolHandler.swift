import Foundation
import CoreGraphics
import SwiftUI
import Combine

// MARK: - TextToolHandler (T051, T052)

/// Handles text annotation creation through click-to-place behavior.
/// Creates TextAnnotation instances and manages inline text editing.
@MainActor
final class TextToolHandler: ObservableObject {
    // MARK: - Published Properties

    /// The text annotation currently being edited.
    @Published private(set) var editingAnnotation: TextAnnotation?

    /// The current text being entered.
    @Published var currentText: String = ""

    /// Position of the text entry field.
    @Published private(set) var textFieldPosition: CGPoint?

    /// Whether text editing is in progress.
    @Published private(set) var isEditing: Bool = false

    // MARK: - Properties

    /// Reference to tool configuration for font and color settings.
    private weak var toolConfig: ToolConfiguration?

    /// Reference to the document for adding annotations.
    private weak var document: AnnotationDocument?

    // MARK: - Initialization

    init(toolConfig: ToolConfiguration, document: AnnotationDocument) {
        self.toolConfig = toolConfig
        self.document = document
    }

    // MARK: - Click Handling (T051)

    /// Handles a click on the canvas to place or edit text.
    /// - Parameter point: The click point in canvas coordinates.
    func handleClick(at point: CGPoint) {
        if isEditing {
            // Commit current text and start new
            commitText()
        }

        // Start new text annotation
        beginEditing(at: point)
    }

    /// Begins text editing at the specified position.
    /// - Parameter point: The position for the new text.
    private func beginEditing(at point: CGPoint) {
        // Create a new text annotation
        let annotation = TextAnnotation(
            text: "",
            position: point,
            textColor: toolConfig?.color ?? .black,
            backgroundColor: nil,
            font: toolConfig?.currentFont ?? .default
        )
        annotation.isEditing = true

        editingAnnotation = annotation
        textFieldPosition = point
        currentText = ""
        isEditing = true
    }

    // MARK: - Text Editing (T052)

    /// Commits the current text and adds the annotation to the document.
    func commitText() {
        guard let annotation = editingAnnotation else { return }

        // Update annotation text
        annotation.text = currentText
        annotation.isEditing = false

        // Only add if text is not empty
        if !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            document?.addAnnotation(annotation)
        }

        // Reset state
        editingAnnotation = nil
        textFieldPosition = nil
        currentText = ""
        isEditing = false
    }

    /// Cancels the current text editing without adding annotation.
    func cancelEditing() {
        editingAnnotation?.isEditing = false
        editingAnnotation = nil
        textFieldPosition = nil
        currentText = ""
        isEditing = false
    }

    /// Updates the current text during editing.
    /// - Parameter text: The new text content.
    func updateText(_ text: String) {
        currentText = text
        editingAnnotation?.text = text
    }

    // MARK: - Editing Existing Text

    /// Begins editing an existing text annotation.
    /// - Parameter annotation: The annotation to edit.
    func beginEditingExisting(_ annotation: TextAnnotation) {
        // Commit any current editing
        if isEditing {
            commitText()
        }

        // Set up editing for existing annotation
        annotation.isEditing = true
        editingAnnotation = annotation
        textFieldPosition = annotation.position
        currentText = annotation.text
        isEditing = true
    }
}

// MARK: - Text Input View (T052)

/// SwiftUI view for inline text input during annotation creation.
struct TextInputOverlay: View {
    @ObservedObject var handler: TextToolHandler
    @FocusState private var isFocused: Bool
    let scale: CGFloat

    var body: some View {
        if handler.isEditing, let position = handler.textFieldPosition {
            let scaledPosition = CGPoint(
                x: position.x * scale,
                y: position.y * scale
            )

            TextField("Enter text", text: $handler.currentText)
                .textFieldStyle(.plain)
                .font(.system(size: 16 * scale))
                .foregroundColor(Color(nsColor: .textColor))
                .background(Color.white.opacity(0.9))
                .padding(4)
                .cornerRadius(4)
                .shadow(radius: 2)
                .frame(minWidth: 100 * scale, maxWidth: 400 * scale)
                .position(x: scaledPosition.x + 100 * scale, y: scaledPosition.y + 12 * scale)
                .focused($isFocused)
                .onAppear {
                    isFocused = true
                }
                .onSubmit {
                    handler.commitText()
                }
                .onKeyPress(.escape) {
                    handler.cancelEditing()
                    return .handled
                }
        }
    }
}

// MARK: - Text Preview View

/// SwiftUI view for rendering text preview during creation.
struct TextPreviewView: View {
    let text: String
    let position: CGPoint
    let font: AnnotationFont
    let color: Color
    let backgroundColor: Color?
    let scale: CGFloat

    var body: some View {
        if !text.isEmpty {
            let scaledPosition = CGPoint(
                x: position.x * scale,
                y: position.y * scale
            )

            Text(text)
                .font(.system(size: font.size * scale, weight: fontWeight))
                .foregroundColor(color)
                .padding(4 * scale)
                .background(backgroundColor ?? Color.clear)
                .position(scaledPosition)
        }
    }

    private var fontWeight: Font.Weight {
        switch font.weight {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}
