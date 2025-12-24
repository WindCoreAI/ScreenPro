import SwiftUI
import AppKit

// MARK: - ScrollingPreviewView (T026, T082)

/// View displaying live stitched preview during scrolling capture.
/// Includes VoiceOver accessibility labels (T082).
struct ScrollingPreviewView: View {
    @ObservedObject var captureService: ScrollingCaptureService
    let onFinish: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "scroll")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)

                Text("Scrolling Capture")
                    .font(.headline)

                Spacer()

                // Frame count badge
                Text("\(captureService.frames.count) frames")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
                    .accessibilityLabel("\(captureService.frames.count) frames captured")
            }
            .padding(.horizontal)

            // Preview area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))

                if let preview = captureService.previewImage {
                    Image(nsImage: NSImage(cgImage: preview, size: .zero))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(8)
                        .padding(8)
                        .accessibilityLabel("Stitched preview of captured content")
                } else if !captureService.frames.isEmpty {
                    // Show last captured frame if no preview yet
                    if let lastFrame = captureService.frames.last {
                        Image(nsImage: NSImage(cgImage: lastFrame.image, size: .zero))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(8)
                            .padding(8)
                            .accessibilityLabel("Last captured frame")
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)

                        Text("Scroll to capture content")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("No content captured yet. Scroll to capture content.")
                }
            }
            .frame(minHeight: 200)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Capture preview area")

            // Progress bar
            VStack(spacing: 4) {
                ProgressView(value: captureService.captureProgress)
                    .progressViewStyle(.linear)
                    .accessibilityLabel("Capture progress")
                    .accessibilityValue("\(Int(captureService.captureProgress * 100)) percent")

                HStack {
                    Text("Capturing...")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(Int(captureService.captureProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal)

            // Instructions
            Text("Scroll through the content you want to capture. Press Done when finished.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityLabel("Instructions: Scroll through the content you want to capture. Press Done when finished.")

            // Action buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.bordered)
                .accessibilityLabel("Cancel scrolling capture")
                .accessibilityHint("Press to cancel and discard captured frames")

                Button("Done") {
                    onFinish()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .disabled(captureService.frames.isEmpty)
                .accessibilityLabel("Finish scrolling capture")
                .accessibilityHint(captureService.frames.isEmpty ? "Disabled. Capture some content first." : "Press to finish and stitch captured frames")
            }
            .padding(.bottom)
        }
        .frame(width: 300, height: 400)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(16)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Scrolling capture panel")
    }
}

// MARK: - ScrollingCaptureWindow

/// Window for displaying the scrolling capture preview.
@MainActor
final class ScrollingCaptureWindow: NSWindow {
    init(
        captureService: ScrollingCaptureService,
        onFinish: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        // Configure window
        self.title = "Scrolling Capture"
        self.level = .floating
        self.isReleasedWhenClosed = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear

        // Set up SwiftUI content
        let contentView = ScrollingPreviewView(
            captureService: captureService,
            onFinish: onFinish,
            onCancel: onCancel
        )
        self.contentView = NSHostingView(rootView: contentView)

        // Position at bottom-right of main screen
        positionWindow()
    }

    private func positionWindow() {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let windowFrame = self.frame
        let padding: CGFloat = 20

        let origin = CGPoint(
            x: screenFrame.maxX - windowFrame.width - padding,
            y: screenFrame.minY + padding
        )

        self.setFrameOrigin(origin)
    }
}

#Preview {
    ScrollingPreviewView(
        captureService: ScrollingCaptureService(),
        onFinish: {},
        onCancel: {}
    )
}
