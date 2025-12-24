import SwiftUI
import AppKit

// MARK: - TextRecognitionOverlay (T035)

/// Overlay view displaying bounding boxes for recognized text.
struct TextRecognitionOverlay: View {
    let result: RecognitionResult
    let imageSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            let scale = min(
                geometry.size.width / imageSize.width,
                geometry.size.height / imageSize.height
            )
            let scaledWidth = imageSize.width * scale
            let scaledHeight = imageSize.height * scale
            let offsetX = (geometry.size.width - scaledWidth) / 2
            let offsetY = (geometry.size.height - scaledHeight) / 2

            ZStack {
                ForEach(result.texts) { text in
                    let rect = text.imageRect(for: imageSize)
                    let scaledRect = CGRect(
                        x: offsetX + rect.origin.x * scale,
                        y: offsetY + rect.origin.y * scale,
                        width: rect.width * scale,
                        height: rect.height * scale
                    )

                    Rectangle()
                        .stroke(
                            text.isHighConfidence ? Color.blue : Color.orange,
                            lineWidth: 2
                        )
                        .background(
                            (text.isHighConfidence ? Color.blue : Color.orange)
                                .opacity(0.1)
                        )
                        .frame(width: scaledRect.width, height: scaledRect.height)
                        .position(
                            x: scaledRect.midX,
                            y: scaledRect.midY
                        )
                }
            }
        }
    }
}

// MARK: - TextRecognitionResultView (T082)

/// View displaying the OCR result with copy action.
/// Includes VoiceOver accessibility labels (T082).
struct TextRecognitionResultView: View {
    let result: RecognitionResult
    let onCopy: () -> Void
    let onDismiss: () -> Void

    @State private var isCopied = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "text.viewfinder")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)

                Text("Text Recognition")
                    .font(.headline)

                Spacer()

                // Stats
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(result.texts.count) blocks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1fs", result.processingTime))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(result.texts.count) text blocks recognized in \(String(format: "%.1f", result.processingTime)) seconds")
            }
            .padding(.horizontal)

            // Text content
            ScrollView {
                Text(result.fullText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .accessibilityLabel("Recognized text: \(result.fullText)")
            }
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .frame(maxHeight: 200)
            .padding(.horizontal)
            .accessibilityLabel("Text content area")
            .accessibilityHint("Contains recognized text that can be selected")

            // Action buttons
            HStack(spacing: 16) {
                Button("Dismiss") {
                    onDismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.bordered)
                .accessibilityLabel("Dismiss OCR results")
                .accessibilityHint("Press to close this panel")

                Button(isCopied ? "Copied!" : "Copy to Clipboard") {
                    onCopy()
                    withAnimation {
                        isCopied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            isCopied = false
                        }
                    }
                }
                .keyboardShortcut("c", modifiers: .command)
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(isCopied ? "Text copied to clipboard" : "Copy text to clipboard")
                .accessibilityHint("Press to copy all recognized text")
            }
            .padding(.bottom)
        }
        .frame(width: 400, height: 350)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(16)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Text recognition results panel")
    }
}

// MARK: - OCRResultWindow

/// Window for displaying OCR results.
@MainActor
final class OCRResultWindow: NSWindow {
    init(
        result: RecognitionResult,
        onCopy: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "Text Recognition"
        self.level = .floating
        self.isReleasedWhenClosed = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear

        let contentView = TextRecognitionResultView(
            result: result,
            onCopy: onCopy,
            onDismiss: onDismiss
        )
        self.contentView = NSHostingView(rootView: contentView)

        center()
    }
}

#Preview {
    TextRecognitionResultView(
        result: RecognitionResult(
            texts: [
                RecognizedText(text: "Hello, World!", confidence: 0.95, boundingBox: .zero),
                RecognizedText(text: "This is a test.", confidence: 0.88, boundingBox: .zero)
            ],
            processingTime: 0.5,
            sourceImageSize: CGSize(width: 800, height: 600)
        ),
        onCopy: {},
        onDismiss: {}
    )
}
