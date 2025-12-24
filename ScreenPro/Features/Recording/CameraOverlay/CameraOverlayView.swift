import SwiftUI
import AVFoundation
import AppKit

// MARK: - CameraOverlayView (T075, T082)

/// View displaying the camera preview with shape mask and drag support.
/// Includes VoiceOver accessibility labels (T082).
struct CameraOverlayView: View {
    @ObservedObject var controller: CameraOverlayController
    @Binding var config: OverlayConfig

    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            // Camera preview
            if controller.state.isRunning {
                CameraPreviewRepresentable(previewLayer: controller.previewLayer)
                    .scaleEffect(x: config.isMirrored ? -1 : 1, y: 1)
            } else {
                // Placeholder when camera is off
                Color.black
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
            }
        }
        .frame(width: config.size.width, height: config.size.height)
        .clipShape(overlayShape)
        .overlay(
            overlayShape
                .stroke(Color.white, lineWidth: config.borderWidth)
        )
        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
        .offset(dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    // Update config with new position
                    config.position = .custom
                    config.customPosition = CGPoint(
                        x: config.customPosition.x + value.translation.width,
                        y: config.customPosition.y - value.translation.height
                    )
                    dragOffset = .zero
                }
        )
        .animation(.spring(response: 0.3), value: isDragging)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cameraAccessibilityLabel)
        .accessibilityHint("Drag to reposition the camera overlay")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    /// Accessibility label describing the camera overlay state
    private var cameraAccessibilityLabel: String {
        let status = controller.state.isRunning ? "active" : "inactive"
        let shape = config.shape.displayName.lowercased()
        let position = config.position.displayName
        return "Camera overlay, \(status), \(shape) shape, positioned at \(position)"
    }

    private var overlayShape: AnyShape {
        switch config.shape {
        case .circle:
            AnyShape(Circle())
        case .roundedRectangle:
            AnyShape(RoundedRectangle(cornerRadius: config.shape.cornerRadius(for: config.size)))
        case .rectangle:
            AnyShape(Rectangle())
        }
    }
}

// MARK: - CameraPreviewRepresentable

/// NSViewRepresentable for the AVCaptureVideoPreviewLayer.
struct CameraPreviewRepresentable: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true

        if let layer = previewLayer {
            layer.frame = view.bounds
            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            view.layer?.addSublayer(layer)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        previewLayer?.frame = nsView.bounds
    }
}

// MARK: - CameraOverlayWindow

/// Window for displaying the camera overlay during recording.
@MainActor
final class CameraOverlayWindow: NSWindow {
    private let controller: CameraOverlayController

    init(controller: CameraOverlayController, config: Binding<OverlayConfig>) {
        self.controller = controller

        let size = config.wrappedValue.size
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let contentView = CameraOverlayView(controller: controller, config: config)
        self.contentView = NSHostingView(rootView: contentView)

        positionWindow(with: config.wrappedValue)
    }

    /// Positions the window based on configuration.
    func positionWindow(with config: OverlayConfig) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let padding: CGFloat = 20

        let position: CGPoint
        if config.position == .custom {
            position = CGPoint(
                x: screenFrame.minX + config.customPosition.x,
                y: screenFrame.minY + config.customPosition.y
            )
        } else {
            position = config.position.offset(for: screenFrame.size, overlaySize: config.size, padding: padding)
            // Convert to screen coordinates
        }

        setFrameOrigin(CGPoint(
            x: screenFrame.minX + (config.position == .custom ? config.customPosition.x : position.x),
            y: screenFrame.minY + (config.position == .custom ? config.customPosition.y : position.y)
        ))
    }
}

#Preview {
    CameraOverlayView(
        controller: CameraOverlayController(),
        config: .constant(.default)
    )
}
