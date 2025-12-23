import SwiftUI

// MARK: - StrokeWidthPicker (T014)

/// A picker for selecting stroke width with visual circle indicators.
struct StrokeWidthPicker: View {
    @Binding var selectedWidth: CGFloat
    @State private var showingPopover = false

    var body: some View {
        Button(action: { showingPopover.toggle() }) {
            strokeIndicator(width: selectedWidth)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Stroke width")
        .accessibilityValue("\(Int(selectedWidth)) points")
        .popover(isPresented: $showingPopover) {
            strokePopover
        }
    }

    private var strokePopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stroke Width")
                .font(.headline)

            // Stroke width options
            HStack(spacing: 8) {
                ForEach(ToolConfiguration.availableStrokeWidths, id: \.self) { width in
                    strokeButton(width: width)
                }
            }

            Divider()

            // Custom slider
            HStack {
                Text("Custom:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $selectedWidth, in: 1...20, step: 1)
                    .frame(width: 100)

                Text("\(Int(selectedWidth))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .trailing)
            }
        }
        .padding()
        .frame(width: 280)
    }

    private func strokeIndicator(width: CGFloat) -> some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(0.1))
                .frame(width: 28, height: 28)

            // Stroke circle
            Circle()
                .fill(Color.primary)
                .frame(width: min(width * 2, 16), height: min(width * 2, 16))
        }
    }

    private func strokeButton(width: CGFloat) -> some View {
        Button(action: {
            selectedWidth = width
            showingPopover = false
        }) {
            ZStack {
                // Selection indicator
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedWidth == width ? Color.accentColor.opacity(0.2) : Color.clear)
                    .frame(width: 32, height: 32)

                // Stroke circle
                Circle()
                    .fill(Color.primary)
                    .frame(width: min(width * 2, 16), height: min(width * 2, 16))
            }
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("\(Int(width)) points")
        .accessibilityAddTraits(selectedWidth == width ? .isSelected : [])
    }
}

// MARK: - Preview

#if DEBUG
struct StrokeWidthPicker_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 16) {
            StrokeWidthPicker(selectedWidth: .constant(1))
            StrokeWidthPicker(selectedWidth: .constant(3))
            StrokeWidthPicker(selectedWidth: .constant(6))
        }
        .padding()
    }
}
#endif
