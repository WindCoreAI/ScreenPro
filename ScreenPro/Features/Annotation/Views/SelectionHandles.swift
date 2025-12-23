import SwiftUI

// MARK: - SelectionHandles (T109, T111, T112)

/// Selection handles for resizing and moving annotations.
/// Displays corner and edge handles for precise manipulation.
struct SelectionHandles: View {
    let bounds: CGRect
    let scale: CGFloat
    let onMove: (CGSize) -> Void
    let onResize: (ResizeHandle, CGSize) -> Void

    // MARK: - Constants

    private let handleSize: CGFloat = 10
    private let edgeHandleLength: CGFloat = 16
    private let hitAreaPadding: CGFloat = 8

    // MARK: - Body

    var body: some View {
        let displayBounds = CGRect(
            x: bounds.origin.x * scale,
            y: bounds.origin.y * scale,
            width: bounds.width * scale,
            height: bounds.height * scale
        )

        ZStack {
            // Selection border
            selectionBorder(displayBounds)

            // Corner handles
            cornerHandles(displayBounds)

            // Edge handles (for larger selections)
            if displayBounds.width > 60 && displayBounds.height > 60 {
                edgeHandles(displayBounds)
            }
        }
    }

    // MARK: - Selection Border

    private func selectionBorder(_ bounds: CGRect) -> some View {
        Rectangle()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
            .foregroundColor(.accentColor)
            .frame(width: bounds.width, height: bounds.height)
            .position(x: bounds.midX, y: bounds.midY)
    }

    // MARK: - Corner Handles

    private func cornerHandles(_ bounds: CGRect) -> some View {
        let corners: [(position: CGPoint, handle: ResizeHandle)] = [
            (CGPoint(x: bounds.minX, y: bounds.minY), .topLeft),
            (CGPoint(x: bounds.maxX, y: bounds.minY), .topRight),
            (CGPoint(x: bounds.minX, y: bounds.maxY), .bottomLeft),
            (CGPoint(x: bounds.maxX, y: bounds.maxY), .bottomRight)
        ]

        return ForEach(0..<corners.count, id: \.self) { index in
            handleView(at: corners[index].position, handle: corners[index].handle)
        }
    }

    // MARK: - Edge Handles

    private func edgeHandles(_ bounds: CGRect) -> some View {
        let edges: [(position: CGPoint, handle: ResizeHandle)] = [
            (CGPoint(x: bounds.midX, y: bounds.minY), .top),
            (CGPoint(x: bounds.midX, y: bounds.maxY), .bottom),
            (CGPoint(x: bounds.minX, y: bounds.midY), .left),
            (CGPoint(x: bounds.maxX, y: bounds.midY), .right)
        ]

        return ForEach(0..<edges.count, id: \.self) { index in
            edgeHandleView(at: edges[index].position, handle: edges[index].handle)
        }
    }

    // MARK: - Handle Views

    private func handleView(at position: CGPoint, handle: ResizeHandle) -> some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
            .frame(width: handleSize, height: handleSize)
            .position(position)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let delta = CGSize(
                            width: value.translation.width / scale,
                            height: value.translation.height / scale
                        )
                        onResize(handle, delta)
                    }
            )
            .accessibilityLabel("\(handle.accessibilityLabel) resize handle")
            .accessibilityHint("Drag to resize from \(handle.rawValue)")
    }

    private func edgeHandleView(at position: CGPoint, handle: ResizeHandle) -> some View {
        let isHorizontal = handle == .top || handle == .bottom

        return RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.accentColor, lineWidth: 1.5))
            .frame(
                width: isHorizontal ? edgeHandleLength : 6,
                height: isHorizontal ? 6 : edgeHandleLength
            )
            .position(position)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let delta = CGSize(
                            width: value.translation.width / scale,
                            height: value.translation.height / scale
                        )
                        onResize(handle, delta)
                    }
            )
            .accessibilityLabel("\(handle.accessibilityLabel) resize handle")
            .accessibilityHint("Drag to resize from \(handle.rawValue)")
    }
}

// MARK: - ResizeHandle

/// Handle positions for resizing.
enum ResizeHandle: String {
    case topLeft = "top-left"
    case top = "top"
    case topRight = "top-right"
    case left = "left"
    case right = "right"
    case bottomLeft = "bottom-left"
    case bottom = "bottom"
    case bottomRight = "bottom-right"

    var accessibilityLabel: String {
        rawValue.replacingOccurrences(of: "-", with: " ")
    }

    /// Whether this handle affects the left edge.
    var affectsLeft: Bool {
        self == .topLeft || self == .left || self == .bottomLeft
    }

    /// Whether this handle affects the right edge.
    var affectsRight: Bool {
        self == .topRight || self == .right || self == .bottomRight
    }

    /// Whether this handle affects the top edge.
    var affectsTop: Bool {
        self == .topLeft || self == .top || self == .topRight
    }

    /// Whether this handle affects the bottom edge.
    var affectsBottom: Bool {
        self == .bottomLeft || self == .bottom || self == .bottomRight
    }
}

// MARK: - MovableSelection (T111)

/// A draggable selection overlay for moving annotations.
struct MovableSelectionOverlay: View {
    let bounds: CGRect
    let scale: CGFloat
    let onMove: (CGSize) -> Void

    @State private var isDragging = false

    var body: some View {
        let displayBounds = CGRect(
            x: bounds.origin.x * scale,
            y: bounds.origin.y * scale,
            width: bounds.width * scale,
            height: bounds.height * scale
        )

        Rectangle()
            .fill(Color.accentColor.opacity(isDragging ? 0.15 : 0.05))
            .frame(width: displayBounds.width, height: displayBounds.height)
            .position(x: displayBounds.midX, y: displayBounds.midY)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let delta = CGSize(
                            width: value.translation.width / scale,
                            height: value.translation.height / scale
                        )
                        onMove(delta)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .accessibilityLabel("Selected annotation")
            .accessibilityHint("Drag to move the annotation")
    }
}
