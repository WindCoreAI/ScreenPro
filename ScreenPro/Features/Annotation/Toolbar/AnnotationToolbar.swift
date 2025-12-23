import SwiftUI

// MARK: - AnnotationToolbar (T011)

/// The main toolbar for the annotation editor.
/// Contains tool selection, color picker, stroke width, and action buttons.
struct AnnotationToolbar: View {
    @ObservedObject var toolConfig: ToolConfiguration
    @ObservedObject var document: AnnotationDocument

    // MARK: - Actions

    var onSave: () -> Void = {}
    var onCopy: () -> Void = {}
    var onCancel: () -> Void = {}

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Tool selection section
            toolSelectionSection

            Divider()
                .frame(height: 24)

            // Color and stroke section
            colorAndStrokeSection

            Spacer()

            // Undo/Redo section
            undoRedoSection

            Divider()
                .frame(height: 24)

            // Action buttons section
            actionButtonsSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    // MARK: - Sections

    private var toolSelectionSection: some View {
        HStack(spacing: 4) {
            // Primary tools
            ForEach(AnnotationTool.primaryTools, id: \.self) { tool in
                ToolButton(
                    tool: tool,
                    isSelected: toolConfig.selectedTool == tool,
                    action: { toolConfig.selectedTool = tool }
                )
            }

            Divider()
                .frame(height: 20)

            // Privacy tools
            ForEach(AnnotationTool.privacyTools, id: \.self) { tool in
                ToolButton(
                    tool: tool,
                    isSelected: toolConfig.selectedTool == tool,
                    action: { toolConfig.selectedTool = tool }
                )
            }

            Divider()
                .frame(height: 20)

            // Additional tools
            ForEach(AnnotationTool.additionalTools, id: \.self) { tool in
                ToolButton(
                    tool: tool,
                    isSelected: toolConfig.selectedTool == tool,
                    action: { toolConfig.selectedTool = tool }
                )
            }
        }
    }

    private var colorAndStrokeSection: some View {
        HStack(spacing: 8) {
            // Color picker
            ColorPickerButton(selectedColor: $toolConfig.color)

            // Stroke width picker
            StrokeWidthPicker(selectedWidth: $toolConfig.strokeWidth)

            // Fill toggle (for shape tools)
            if toolConfig.selectedTool == .rectangle || toolConfig.selectedTool == .ellipse {
                Toggle(isOn: $toolConfig.fillEnabled) {
                    Image(systemName: "square.fill")
                }
                .toggleStyle(.button)
                .help("Toggle fill")
                .accessibilityLabel("Toggle shape fill")
            }

            // Blur intensity slider (for blur tools)
            if toolConfig.selectedTool == .blur || toolConfig.selectedTool == .pixelate {
                HStack(spacing: 4) {
                    Image(systemName: "drop")
                        .foregroundColor(.secondary)
                    Slider(value: $toolConfig.blurIntensity, in: 0.1...1.0)
                        .frame(width: 80)
                        .accessibilityLabel("Blur intensity")
                }
            }

            // Font size picker (for text tool)
            if toolConfig.selectedTool == .text {
                Picker("", selection: $toolConfig.fontSize) {
                    ForEach(AnnotationFont.availableSizes, id: \.self) { size in
                        Text("\(Int(size))").tag(size)
                    }
                }
                .frame(width: 70)
                .accessibilityLabel("Font size")
            }
        }
    }

    private var undoRedoSection: some View {
        HStack(spacing: 4) {
            Button(action: { document.undo() }) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!document.canUndo)
            .keyboardShortcut("z", modifiers: .command)
            .help("Undo (⌘Z)")
            .accessibilityLabel("Undo")

            Button(action: { document.redo() }) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!document.canRedo)
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .help("Redo (⇧⌘Z)")
            .accessibilityLabel("Redo")
        }
        .buttonStyle(.borderless)
    }

    private var actionButtonsSection: some View {
        HStack(spacing: 8) {
            Button("Cancel") {
                onCancel()
            }
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel("Cancel and discard changes")

            Button(action: { onCopy() }) {
                Image(systemName: "doc.on.clipboard")
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .help("Copy to clipboard (⇧⌘C)")
            .accessibilityLabel("Copy to clipboard")
            .buttonStyle(.borderless)

            Button("Save") {
                onSave()
            }
            .keyboardShortcut("s", modifiers: .command)
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Save annotated image")
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AnnotationToolbar_Previews: PreviewProvider {
    static var previews: some View {
        let toolConfig = ToolConfiguration()
        let testImage = CGContext(
            data: nil,
            width: 100,
            height: 100,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!.makeImage()!

        let document = AnnotationDocument(image: testImage)

        AnnotationToolbar(toolConfig: toolConfig, document: document)
            .frame(height: 50)
    }
}
#endif
