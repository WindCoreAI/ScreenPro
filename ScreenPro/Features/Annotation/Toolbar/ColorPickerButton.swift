import SwiftUI

// MARK: - ColorPickerButton (T013)

/// A button that shows a color picker popover with preset colors.
/// Displays the currently selected color and allows selection from presets or custom color.
struct ColorPickerButton: View {
    @Binding var selectedColor: AnnotationColor
    @State private var showingPopover = false

    var body: some View {
        Button(action: { showingPopover.toggle() }) {
            ZStack {
                // Color swatch
                RoundedRectangle(cornerRadius: 4)
                    .fill(selectedColor.color)
                    .frame(width: 24, height: 24)

                // Border
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    .frame(width: 24, height: 24)
            }
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Annotation color")
        .accessibilityValue(colorName(for: selectedColor))
        .popover(isPresented: $showingPopover) {
            colorPopover
        }
    }

    private var colorPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color")
                .font(.headline)

            // Preset colors grid
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 8), count: 4), spacing: 8) {
                ForEach(AnnotationColor.presets, id: \.self) { color in
                    colorButton(for: color)
                }
            }

            Divider()

            // System color picker for custom colors
            ColorPicker("Custom", selection: customColorBinding)
                .labelsHidden()
        }
        .padding()
        .frame(width: 180)
    }

    private func colorButton(for color: AnnotationColor) -> some View {
        Button(action: {
            selectedColor = color
            showingPopover = false
        }) {
            ZStack {
                Circle()
                    .fill(color.color)
                    .frame(width: 28, height: 28)

                if selectedColor == color {
                    Circle()
                        .stroke(Color.primary, lineWidth: 2)
                        .frame(width: 28, height: 28)

                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(contrastColor(for: color))
                }
            }
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(colorName(for: color))
        .accessibilityAddTraits(selectedColor == color ? .isSelected : [])
    }

    private var customColorBinding: Binding<Color> {
        Binding(
            get: { selectedColor.color },
            set: { newColor in
                selectedColor = AnnotationColor(nsColor: NSColor(newColor))
            }
        )
    }

    private func colorName(for color: AnnotationColor) -> String {
        switch color {
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .black: return "Black"
        case .white: return "White"
        default: return "Custom"
        }
    }

    private func contrastColor(for color: AnnotationColor) -> Color {
        // Simple luminance calculation
        let luminance = 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue
        return luminance > 0.5 ? .black : .white
    }
}

// MARK: - Preview

#if DEBUG
struct ColorPickerButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 16) {
            ColorPickerButton(selectedColor: .constant(.red))
            ColorPickerButton(selectedColor: .constant(.blue))
            ColorPickerButton(selectedColor: .constant(.black))
        }
        .padding()
    }
}
#endif
