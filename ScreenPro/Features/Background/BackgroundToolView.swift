import SwiftUI
import AppKit

// MARK: - BackgroundToolView (T063-T067)

/// Full-featured background tool for adding stylish backgrounds to screenshots.
struct BackgroundToolView: View {
    let sourceImage: NSImage
    @Binding var config: BackgroundConfig
    let onExport: (NSImage) -> Void
    let onDismiss: () -> Void

    var body: some View {
        HSplitView {
            // Preview area
            previewArea
                .frame(minWidth: 400)

            // Controls sidebar
            controlsSidebar
                .frame(width: 280)
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    // MARK: - Preview Area

    private var previewArea: some View {
        VStack {
            Text("Preview")
                .font(.headline)
                .padding(.top)

            GeometryReader { geometry in
                let preview = generatePreview(in: geometry.size)
                ZStack {
                    // Checker pattern for transparency
                    CheckerboardView()
                        .opacity(0.1)

                    // Preview
                    preview
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geometry.size.width - 40, maxHeight: geometry.size.height - 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Controls Sidebar

    private var controlsSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Style picker (T064)
                styleSection

                // Aspect ratio (T065)
                aspectRatioSection

                // Padding and styling (T066)
                paddingSection
                cornerRadiusSection
                shadowSection

                Spacer()

                // Export button (T067)
                exportSection
            }
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Style Section (T064)

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Background Style")
                .font(.headline)

            Picker("Style", selection: $config.style) {
                ForEach(BackgroundStyle.allCases) { style in
                    Label(style.displayName, systemImage: style.icon)
                        .tag(style)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if config.style == .gradient {
                Picker("Preset", selection: $config.gradientPreset) {
                    ForEach(GradientPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
            }

            if config.style == .solid || config.gradientPreset == .custom {
                ColorPicker("Primary Color", selection: $config.primaryColor)

                if config.style == .gradient {
                    ColorPicker("Secondary Color", selection: $config.secondaryColor)
                }
            }
        }
    }

    // MARK: - Aspect Ratio Section (T065)

    private var aspectRatioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aspect Ratio")
                .font(.headline)

            Picker("Ratio", selection: $config.aspectRatio) {
                ForEach(AspectRatioPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
        }
    }

    // MARK: - Padding Section (T066, T082)

    private var paddingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Padding: \(Int(config.padding))px")
                .font(.headline)

            Slider(value: $config.padding, in: 0...200, step: 10)
                .accessibilityLabel("Padding")
                .accessibilityValue("\(Int(config.padding)) pixels")
                .accessibilityHint("Adjust space around the screenshot")
        }
    }

    private var cornerRadiusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Corner Radius: \(Int(config.cornerRadius))px")
                .font(.headline)

            Slider(value: $config.cornerRadius, in: 0...50, step: 4)
                .accessibilityLabel("Corner radius")
                .accessibilityValue("\(Int(config.cornerRadius)) pixels")
                .accessibilityHint("Adjust roundness of screenshot corners")
        }
    }

    private var shadowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shadow")
                .font(.headline)

            HStack {
                Text("Radius: \(Int(config.shadowRadius))")
                    .font(.caption)
                Slider(value: $config.shadowRadius, in: 0...100, step: 5)
                    .accessibilityLabel("Shadow radius")
                    .accessibilityValue("\(Int(config.shadowRadius)) pixels")
                    .accessibilityHint("Adjust shadow blur size")
            }

            HStack {
                Text("Opacity: \(Int(config.shadowOpacity * 100))%")
                    .font(.caption)
                Slider(value: $config.shadowOpacity, in: 0...1, step: 0.1)
                    .accessibilityLabel("Shadow opacity")
                    .accessibilityValue("\(Int(config.shadowOpacity * 100)) percent")
                    .accessibilityHint("Adjust shadow darkness")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Shadow settings")
    }

    // MARK: - Export Section (T067, T082)

    private var exportSection: some View {
        VStack(spacing: 12) {
            Picker("Export Scale", selection: $config.exportScale) {
                Text("1x").tag(CGFloat(1.0))
                Text("2x").tag(CGFloat(2.0))
                Text("3x").tag(CGFloat(3.0))
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Export scale")
            .accessibilityHint("Choose resolution multiplier for export")

            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.bordered)
                .accessibilityLabel("Cancel background editing")
                .accessibilityHint("Press to discard changes and close")

                Button("Export") {
                    let exportedImage = renderExportImage()
                    onExport(exportedImage)
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Export image with background")
                .accessibilityHint("Press to save the styled screenshot")
            }
        }
    }

    // MARK: - Rendering

    /// Generates a preview image for display.
    private func generatePreview(in availableSize: CGSize) -> Image {
        let previewImage = renderBackgroundImage(scale: 1.0)
        return Image(nsImage: previewImage)
    }

    /// Renders the final export image at the configured scale.
    private func renderExportImage() -> NSImage {
        return renderBackgroundImage(scale: config.exportScale)
    }

    /// Renders the composite image with background.
    private func renderBackgroundImage(scale: CGFloat) -> NSImage {
        // Calculate dimensions
        let sourceSize = sourceImage.size
        let padding = config.padding * scale
        let totalWidth = sourceSize.width * scale + padding * 2
        let totalHeight = sourceSize.height * scale + padding * 2

        // Apply aspect ratio if not freeform
        var canvasSize = CGSize(width: totalWidth, height: totalHeight)
        if config.aspectRatio != .freeform {
            let ratio = config.aspectRatio.aspectRatio
            if ratio > 0 {
                // Fit the content within the aspect ratio
                if totalWidth / totalHeight > ratio {
                    canvasSize.height = totalWidth / ratio
                } else {
                    canvasSize.width = totalHeight * ratio
                }
            }
        }

        // Create the output image
        let outputImage = NSImage(size: canvasSize)
        outputImage.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            outputImage.unlockFocus()
            return sourceImage
        }

        // Draw background
        drawBackground(in: context, size: canvasSize)

        // Calculate centered position for screenshot
        let imageRect = CGRect(
            x: (canvasSize.width - sourceSize.width * scale) / 2,
            y: (canvasSize.height - sourceSize.height * scale) / 2,
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )

        // Draw shadow
        if config.shadowRadius > 0 && config.shadowOpacity > 0 {
            context.saveGState()
            context.setShadow(
                offset: CGSize(width: 0, height: -config.shadowRadius * 0.3 * scale),
                blur: config.shadowRadius * scale,
                color: NSColor.black.withAlphaComponent(config.shadowOpacity).cgColor
            )

            // Draw a rounded rect for shadow
            let shadowPath = NSBezierPath(
                roundedRect: imageRect,
                xRadius: config.cornerRadius * scale,
                yRadius: config.cornerRadius * scale
            )
            NSColor.white.setFill()
            shadowPath.fill()
            context.restoreGState()
        }

        // Draw screenshot with rounded corners
        let clipPath = NSBezierPath(
            roundedRect: imageRect,
            xRadius: config.cornerRadius * scale,
            yRadius: config.cornerRadius * scale
        )
        clipPath.addClip()
        sourceImage.draw(in: imageRect)

        outputImage.unlockFocus()
        return outputImage
    }

    /// Draws the background based on style.
    private func drawBackground(in context: CGContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)

        switch config.style {
        case .solid:
            NSColor(config.primaryColor).setFill()
            rect.fill()

        case .gradient:
            let colors = config.gradientPreset == .custom
                ? [NSColor(config.primaryColor).cgColor, NSColor(config.secondaryColor).cgColor]
                : config.gradientPreset.colors.map { NSColor($0).cgColor }

            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: nil
            )!

            context.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

        case .mesh:
            // Simplified mesh gradient - use gradient as fallback
            let colors = config.gradientPreset.colors.map { NSColor($0).cgColor }
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: nil
            )!

            context.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
    }
}

// MARK: - CheckerboardView

/// Checkerboard pattern for transparency indication.
struct CheckerboardView: View {
    var body: some View {
        GeometryReader { geometry in
            let size: CGFloat = 10
            let rows = Int(geometry.size.height / size) + 1
            let cols = Int(geometry.size.width / size) + 1

            Canvas { context, _ in
                for row in 0..<rows {
                    for col in 0..<cols {
                        let isWhite = (row + col) % 2 == 0
                        let rect = CGRect(
                            x: CGFloat(col) * size,
                            y: CGFloat(row) * size,
                            width: size,
                            height: size
                        )
                        context.fill(
                            Path(rect),
                            with: .color(isWhite ? .white : .gray)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - BackgroundToolWindow

/// Window for the background tool.
@MainActor
final class BackgroundToolWindow: NSWindow {
    init(
        sourceImage: NSImage,
        onExport: @escaping (NSImage) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        self.title = "Background Tool"
        self.isReleasedWhenClosed = false

        var config = BackgroundConfig.default
        let contentView = BackgroundToolView(
            sourceImage: sourceImage,
            config: Binding(get: { config }, set: { config = $0 }),
            onExport: onExport,
            onDismiss: onDismiss
        )
        self.contentView = NSHostingView(rootView: contentView)

        center()
    }
}

#Preview {
    let sampleImage = NSImage(size: NSSize(width: 400, height: 300))
    sampleImage.lockFocus()
    NSColor.blue.setFill()
    NSRect(x: 0, y: 0, width: 400, height: 300).fill()
    sampleImage.unlockFocus()

    return BackgroundToolView(
        sourceImage: sampleImage,
        config: .constant(.default),
        onExport: { _ in },
        onDismiss: {}
    )
}
