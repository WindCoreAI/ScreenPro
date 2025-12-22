import SwiftUI
import AppKit

// MARK: - Selection Overlay View

/// Main view for area selection, combining crosshair, selection rectangle,
/// dimensions display, and instructions.
struct SelectionOverlayView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: SelectionOverlayViewModel

    // MARK: - Configuration

    private let dimColor = Color.black.opacity(0.3)
    private let selectionBorderColor = Color.white
    private let selectionBorderWidth: CGFloat = 2
    private let cornerHandleSize: CGFloat = 8
    private let minimumSelectionSize: CGFloat = 5

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background with selection cutout
                overlayWithCutout(in: geometry.size)

                // Crosshair (shown before/during dragging when no selection yet)
                CrosshairView(
                    position: viewModel.mousePosition,
                    viewSize: geometry.size,
                    isVisible: !viewModel.isDragging && viewModel.selectionRect == nil
                )

                // Selection rectangle with border and handles
                if let selectionRect = viewModel.selectionRect {
                    selectionRectangle(selectionRect, in: geometry.size)
                }

                // Dimensions display
                if let selectionRect = viewModel.selectionRect,
                   let size = viewModel.selectionSize {
                    DimensionsView(
                        size: size,
                        position: CGPoint(x: selectionRect.maxX, y: selectionRect.maxY),
                        offsetDirection: DimensionsView.offsetDirection(
                            for: selectionRect,
                            in: geometry.size
                        )
                    )
                }

                // Instructions (shown when not dragging)
                InstructionsView(
                    isDragging: viewModel.isDragging,
                    mousePosition: viewModel.mousePosition,
                    viewSize: geometry.size
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    viewModel.updateMousePosition(location)
                case .ended:
                    break
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Area selection overlay")
        .accessibilityHint("Click and drag to select a rectangular area for capture")
    }

    // MARK: - Overlay with Cutout

    /// Creates a dimmed overlay with a transparent cutout for the selection.
    @ViewBuilder
    private func overlayWithCutout(in size: CGSize) -> some View {
        if let selectionRect = viewModel.selectionRect {
            // Dim everything except the selection
            Canvas { context, size in
                // Full dim overlay
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(dimColor)
                )

                // Clear the selection area
                context.blendMode = .destinationOut
                context.fill(
                    Path(selectionRect),
                    with: .color(.black)
                )
            }
            .compositingGroup()
        } else {
            // Just a uniform dim when no selection
            dimColor
        }
    }

    // MARK: - Selection Rectangle

    @ViewBuilder
    private func selectionRectangle(_ rect: CGRect, in size: CGSize) -> some View {
        ZStack {
            // Border
            Rectangle()
                .strokeBorder(selectionBorderColor, lineWidth: selectionBorderWidth)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

            // Corner handles
            cornerHandles(for: rect)
        }
        .accessibilityHidden(true)
    }

    /// Draws corner handles at each corner of the selection.
    @ViewBuilder
    private func cornerHandles(for rect: CGRect) -> some View {
        let corners: [CGPoint] = [
            CGPoint(x: rect.minX, y: rect.minY), // Top-left
            CGPoint(x: rect.maxX, y: rect.minY), // Top-right
            CGPoint(x: rect.minX, y: rect.maxY), // Bottom-left
            CGPoint(x: rect.maxX, y: rect.maxY)  // Bottom-right
        ]

        ForEach(0..<4, id: \.self) { index in
            cornerHandle
                .position(corners[index])
        }
    }

    private var cornerHandle: some View {
        Circle()
            .fill(selectionBorderColor)
            .frame(width: cornerHandleSize, height: cornerHandleSize)
            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
    }

    // MARK: - Gestures

    /// Drag gesture for selection.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !viewModel.isDragging {
                    // Start new selection
                    viewModel.startSelection(at: value.startLocation)
                }
                viewModel.updateSelection(to: value.location)
            }
            .onEnded { value in
                // Validate minimum selection size (T024)
                if let rect = viewModel.selectionRect,
                   rect.width >= minimumSelectionSize,
                   rect.height >= minimumSelectionSize {
                    viewModel.completeSelection()
                } else {
                    // Selection too small, cancel
                    viewModel.cancelSelection()
                }
            }
    }
}

// MARK: - Preview

#Preview {
    let viewModel = SelectionOverlayViewModel(
        screenFrame: CGRect(x: 0, y: 0, width: 800, height: 600)
    )
    viewModel.startSelection(at: CGPoint(x: 100, y: 100))
    viewModel.updateSelection(to: CGPoint(x: 400, y: 300))

    return SelectionOverlayView(viewModel: viewModel)
        .frame(width: 800, height: 600)
        .background(Color.gray)
}
