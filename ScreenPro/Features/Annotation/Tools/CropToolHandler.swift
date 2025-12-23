import Foundation
import CoreGraphics
import SwiftUI

// MARK: - CropToolHandler (T102, T103, T104, T107)

/// Handles crop tool interactions for selecting and applying crop regions.
@MainActor
final class CropToolHandler: ObservableObject {
    // MARK: - Published Properties

    /// Whether a crop operation is in progress.
    @Published var isActive: Bool = false

    /// The current crop selection rectangle (in canvas coordinates).
    @Published var cropRect: CGRect = .zero

    /// Whether the crop is being constrained to aspect ratio.
    @Published var isConstrained: Bool = false

    /// The drag start point.
    private var startPoint: CGPoint = .zero

    // MARK: - Crop Lifecycle

    /// Starts a new crop selection.
    /// - Parameter point: The starting point in canvas coordinates.
    func startCrop(at point: CGPoint) {
        isActive = true
        startPoint = point
        cropRect = CGRect(origin: point, size: .zero)
    }

    /// Updates the crop selection during drag.
    /// - Parameters:
    ///   - point: The current drag point in canvas coordinates.
    ///   - constrainAspectRatio: Whether to constrain to square (Shift-drag) (T107).
    func updateCrop(to point: CGPoint, constrainAspectRatio: Bool = false) {
        guard isActive else { return }

        isConstrained = constrainAspectRatio

        var width = point.x - startPoint.x
        var height = point.y - startPoint.y

        // Constrain to square if Shift is held (T107)
        if constrainAspectRatio {
            let maxDimension = max(abs(width), abs(height))
            width = width >= 0 ? maxDimension : -maxDimension
            height = height >= 0 ? maxDimension : -maxDimension
        }

        // Normalize rect to handle negative width/height
        let x = width >= 0 ? startPoint.x : startPoint.x + width
        let y = height >= 0 ? startPoint.y : startPoint.y + height

        cropRect = CGRect(
            x: x,
            y: y,
            width: abs(width),
            height: abs(height)
        )
    }

    /// Completes the crop selection and prepares for confirmation.
    func endCropSelection() {
        // Crop selection is complete, ready for confirm/cancel
    }

    /// Confirms and applies the crop to the document (T104).
    /// - Parameter document: The annotation document to crop.
    /// - Returns: True if crop was applied successfully.
    @discardableResult
    func confirmCrop(document: AnnotationDocument) -> Bool {
        guard isActive, cropRect.width >= 10, cropRect.height >= 10 else {
            cancelCrop()
            return false
        }

        let success = document.applyCrop(cropRect)
        reset()
        return success
    }

    /// Cancels the current crop operation (T104).
    func cancelCrop() {
        reset()
    }

    /// Resets the crop handler state.
    private func reset() {
        isActive = false
        cropRect = .zero
        startPoint = .zero
        isConstrained = false
    }

    // MARK: - Validation

    /// Whether the current crop selection is valid.
    var isValidCrop: Bool {
        cropRect.width >= 10 && cropRect.height >= 10
    }
}

// MARK: - CropOverlayView (T103)

/// Overlay view showing the crop selection region.
struct CropOverlayView: View {
    let cropRect: CGRect
    let canvasSize: CGSize
    let scale: CGFloat
    let isValid: Bool

    var body: some View {
        let displayRect = CGRect(
            x: cropRect.origin.x * scale,
            y: cropRect.origin.y * scale,
            width: cropRect.width * scale,
            height: cropRect.height * scale
        )

        ZStack {
            // Dimmed overlay outside crop region
            GeometryReader { _ in
                Path { path in
                    // Full canvas
                    let fullRect = CGRect(
                        x: 0,
                        y: 0,
                        width: canvasSize.width * scale,
                        height: canvasSize.height * scale
                    )
                    path.addRect(fullRect)

                    // Cut out crop region
                    path.addRect(displayRect)
                }
                .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
            }

            // Crop region border
            Rectangle()
                .stroke(isValid ? Color.accentColor : Color.red, lineWidth: 2)
                .frame(width: displayRect.width, height: displayRect.height)
                .position(x: displayRect.midX, y: displayRect.midY)

            // Corner handles
            CropHandles(rect: displayRect)

            // Dimension label
            if cropRect.width > 50 && cropRect.height > 30 {
                Text("\(Int(cropRect.width)) × \(Int(cropRect.height))")
                    .font(.caption)
                    .padding(4)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .position(x: displayRect.midX, y: displayRect.maxY + 20)
            }
        }
    }
}

// MARK: - Crop Handles

/// Corner handles for the crop selection.
struct CropHandles: View {
    let rect: CGRect
    private let handleSize: CGFloat = 12
    private let handleLineLength: CGFloat = 20

    var body: some View {
        let corners: [(CGPoint, Alignment)] = [
            (CGPoint(x: rect.minX, y: rect.minY), .topLeading),
            (CGPoint(x: rect.maxX, y: rect.minY), .topTrailing),
            (CGPoint(x: rect.minX, y: rect.maxY), .bottomLeading),
            (CGPoint(x: rect.maxX, y: rect.maxY), .bottomTrailing)
        ]

        ForEach(0..<corners.count, id: \.self) { index in
            CropCornerHandle(
                position: corners[index].0,
                alignment: corners[index].1,
                handleLineLength: handleLineLength
            )
        }
    }
}

/// A single corner handle for crop.
struct CropCornerHandle: View {
    let position: CGPoint
    let alignment: Alignment
    let handleLineLength: CGFloat

    var body: some View {
        Canvas { context, size in
            var path = Path()

            switch alignment {
            case .topLeading:
                path.move(to: CGPoint(x: 0, y: handleLineLength))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: handleLineLength, y: 0))

            case .topTrailing:
                path.move(to: CGPoint(x: -handleLineLength, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: handleLineLength))

            case .bottomLeading:
                path.move(to: CGPoint(x: 0, y: -handleLineLength))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: handleLineLength, y: 0))

            case .bottomTrailing:
                path.move(to: CGPoint(x: -handleLineLength, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: -handleLineLength))

            default:
                break
            }

            context.stroke(
                path,
                with: .color(.white),
                lineWidth: 3
            )
        }
        .frame(width: handleLineLength * 2, height: handleLineLength * 2)
        .position(position)
    }
}

// MARK: - Crop Confirmation Bar

/// Toolbar showing confirm/cancel buttons for crop.
struct CropConfirmationBar: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let isValid: Bool

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onCancel) {
                Label("Cancel", systemImage: "xmark")
            }
            .keyboardShortcut(.escape, modifiers: [])

            Button(action: onConfirm) {
                Label("Apply Crop", systemImage: "checkmark")
            }
            .keyboardShortcut(.return, modifiers: [])
            .disabled(!isValid)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}
