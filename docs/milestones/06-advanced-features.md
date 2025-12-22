# Milestone 6: Advanced Features

## Overview

**Goal**: Implement professional-grade features including scrolling capture, OCR, and capture enhancements.

**Prerequisites**: Milestone 5 completed

---

## Deliverables

| Deliverable | Description | Priority |
|-------------|-------------|----------|
| Scrolling Capture | Long page capture with stitching | P0 |
| OCR Text Recognition | Extract text from screenshots | P0 |
| Self-Timer | Delayed capture | P1 |
| Screen Freeze | Pause screen for capture | P1 |
| Magnifier | Pixel-level precision | P1 |
| Background Tool | Social media image styling | P2 |
| Camera Overlay | PiP webcam for recordings | P2 |

---

## Implementation Tasks

### 6.1 Implement Scrolling Capture

**File**: `Features/ScrollingCapture/ScrollingCaptureService.swift`

```swift
import ScreenCaptureKit
import Vision
import AppKit

@MainActor
final class ScrollingCaptureService: ObservableObject {
    // MARK: - Types

    enum ScrollDirection {
        case vertical
        case horizontal
        case both
    }

    struct Config {
        var direction: ScrollDirection = .vertical
        var captureInterval: TimeInterval = 0.15
        var overlapRatio: CGFloat = 0.2
        var maxFrames: Int = 50
    }

    struct CapturedFrame {
        let image: CGImage
        let scrollOffset: CGFloat
        let timestamp: Date
    }

    // MARK: - State

    @Published private(set) var isCapturing = false
    @Published private(set) var frames: [CapturedFrame] = []
    @Published private(set) var previewImage: CGImage?

    private var captureRegion: CGRect = .zero
    private var config = Config()
    private var captureTimer: Timer?
    private var lastScrollPosition: CGFloat = 0

    // MARK: - Public Methods

    func startCapture(region: CGRect, direction: ScrollDirection) async throws {
        isCapturing = true
        captureRegion = region
        config.direction = direction
        frames.removeAll()
        lastScrollPosition = 0

        // Capture initial frame
        try await captureFrame()

        // Start monitoring scroll
        startScrollMonitoring()
    }

    func captureFrame() async throws {
        guard let image = try await captureRegion(captureRegion) else { return }

        let frame = CapturedFrame(
            image: image,
            scrollOffset: lastScrollPosition,
            timestamp: Date()
        )

        frames.append(frame)

        // Update preview
        if frames.count > 1 {
            previewImage = try? await stitchFrames(frames)
        } else {
            previewImage = image
        }
    }

    func finishCapture() async throws -> CGImage {
        isCapturing = false
        stopScrollMonitoring()

        guard frames.count > 0 else {
            throw ScrollingCaptureError.noFrames
        }

        if frames.count == 1 {
            return frames[0].image
        }

        return try await stitchFrames(frames)
    }

    func cancelCapture() {
        isCapturing = false
        stopScrollMonitoring()
        frames.removeAll()
        previewImage = nil
    }

    // MARK: - Scroll Monitoring

    private func startScrollMonitoring() {
        captureTimer = Timer.scheduledTimer(withTimeInterval: config.captureInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isCapturing else { return }

                // Check if scrolled
                let currentScroll = self.getCurrentScrollPosition()
                let scrollDelta = abs(currentScroll - self.lastScrollPosition)

                if scrollDelta > 10 {  // Meaningful scroll
                    self.lastScrollPosition = currentScroll
                    try? await self.captureFrame()
                }

                // Check frame limit
                if self.frames.count >= self.config.maxFrames {
                    _ = try? await self.finishCapture()
                }
            }
        }
    }

    private func stopScrollMonitoring() {
        captureTimer?.invalidate()
        captureTimer = nil
    }

    private func getCurrentScrollPosition() -> CGFloat {
        // Use accessibility API or mouse position delta
        NSEvent.mouseLocation.y
    }

    // MARK: - Capture

    private func captureRegion(_ rect: CGRect) async throws -> CGImage? {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first(where: { $0.frame.intersects(rect) }) else {
            return nil
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        config.width = Int(rect.width * scale)
        config.height = Int(rect.height * scale)
        config.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        // Crop to selection
        let cropRect = CGRect(
            x: (rect.origin.x - display.frame.origin.x) * scale,
            y: (display.frame.height - rect.origin.y - rect.height) * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )

        return image.cropping(to: cropRect)
    }

    // MARK: - Stitching

    private func stitchFrames(_ frames: [CapturedFrame]) async throws -> CGImage {
        guard frames.count >= 2 else {
            return frames[0].image
        }

        return try await Task.detached(priority: .userInitiated) {
            try ImageStitcher.stitch(
                frames: frames.map(\.image),
                direction: self.config.direction,
                overlapRatio: self.config.overlapRatio
            )
        }.value
    }

    // MARK: - Errors

    enum ScrollingCaptureError: LocalizedError {
        case noFrames
        case stitchingFailed

        var errorDescription: String? {
            switch self {
            case .noFrames: return "No frames captured"
            case .stitchingFailed: return "Failed to stitch frames"
            }
        }
    }
}
```

---

### 6.2 Implement Image Stitcher

**File**: `Features/ScrollingCapture/ImageStitcher.swift`

```swift
import CoreGraphics
import Vision
import Accelerate

enum ImageStitcher {
    static func stitch(
        frames: [CGImage],
        direction: ScrollingCaptureService.ScrollDirection,
        overlapRatio: CGFloat
    ) throws -> CGImage {
        guard frames.count >= 2 else {
            return frames[0]
        }

        var stitchedImages: [CGImage] = [frames[0]]
        var totalOffset: CGFloat = 0

        for i in 1..<frames.count {
            let previous = stitchedImages.last!
            let current = frames[i]

            // Find overlap using feature matching
            let offset = try findOverlap(
                image1: previous,
                image2: current,
                direction: direction,
                expectedOverlap: overlapRatio
            )

            // Skip if no valid overlap found
            guard offset > 0 else { continue }

            // Stitch images
            let combined = try combineImages(
                image1: previous,
                image2: current,
                offset: offset,
                direction: direction
            )

            stitchedImages = [combined]
            totalOffset += offset
        }

        return stitchedImages[0]
    }

    private static func findOverlap(
        image1: CGImage,
        image2: CGImage,
        direction: ScrollingCaptureService.ScrollDirection,
        expectedOverlap: CGFloat
    ) throws -> CGFloat {
        // Use Vision framework for feature matching
        let request = VNTranslationalImageRegistrationRequest(
            targetedCGImage: image2,
            options: [:]
        )

        let handler = VNImageRequestHandler(cgImage: image1, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first as? VNImageTranslationAlignmentObservation else {
            return 0
        }

        let transform = observation.alignmentTransform

        switch direction {
        case .vertical:
            return abs(transform.ty)
        case .horizontal:
            return abs(transform.tx)
        case .both:
            return max(abs(transform.tx), abs(transform.ty))
        }
    }

    private static func combineImages(
        image1: CGImage,
        image2: CGImage,
        offset: CGFloat,
        direction: ScrollingCaptureService.ScrollDirection
    ) throws -> CGImage {
        let width: Int
        let height: Int

        switch direction {
        case .vertical:
            width = max(image1.width, image2.width)
            height = image1.height + image2.height - Int(offset)
        case .horizontal:
            width = image1.width + image2.width - Int(offset)
            height = max(image1.height, image2.height)
        case .both:
            width = image1.width + image2.width - Int(offset)
            height = image1.height + image2.height - Int(offset)
        }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw StitchingError.contextCreationFailed
        }

        // Draw first image
        let rect1: CGRect
        let rect2: CGRect

        switch direction {
        case .vertical:
            rect1 = CGRect(x: 0, y: Int(offset), width: image1.width, height: image1.height)
            rect2 = CGRect(x: 0, y: 0, width: image2.width, height: image2.height)
        case .horizontal:
            rect1 = CGRect(x: 0, y: 0, width: image1.width, height: image1.height)
            rect2 = CGRect(x: image1.width - Int(offset), y: 0, width: image2.width, height: image2.height)
        case .both:
            rect1 = CGRect(x: 0, y: Int(offset), width: image1.width, height: image1.height)
            rect2 = CGRect(x: image1.width - Int(offset), y: 0, width: image2.width, height: image2.height)
        }

        context.draw(image1, in: rect1)

        // Blend overlap region
        blendOverlap(context: context, image2: image2, rect: rect2, overlap: offset, direction: direction)

        guard let result = context.makeImage() else {
            throw StitchingError.compositionFailed
        }

        return result
    }

    private static func blendOverlap(
        context: CGContext,
        image2: CGImage,
        rect: CGRect,
        overlap: CGFloat,
        direction: ScrollingCaptureService.ScrollDirection
    ) {
        // For simplicity, just draw with slight transparency in overlap
        context.saveGState()
        context.setAlpha(1.0)
        context.draw(image2, in: rect)
        context.restoreGState()
    }

    enum StitchingError: LocalizedError {
        case contextCreationFailed
        case compositionFailed

        var errorDescription: String? {
            switch self {
            case .contextCreationFailed: return "Failed to create graphics context"
            case .compositionFailed: return "Failed to compose images"
            }
        }
    }
}
```

---

### 6.3 Implement OCR Text Recognition

**File**: `Features/TextRecognition/TextRecognitionService.swift`

```swift
import Vision
import AppKit

@MainActor
final class TextRecognitionService: ObservableObject {
    // MARK: - Types

    struct RecognizedText: Identifiable {
        let id = UUID()
        let text: String
        let confidence: Float
        let boundingBox: CGRect
    }

    struct RecognitionResult {
        let texts: [RecognizedText]
        let fullText: String
    }

    // MARK: - State

    @Published private(set) var isProcessing = false

    // MARK: - Recognition

    func recognizeText(in image: CGImage) async throws -> RecognitionResult {
        isProcessing = true
        defer { isProcessing = false }

        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "zh-Hans", "zh-Hant", "ja", "ko"]

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])

            guard let observations = request.results else {
                return RecognitionResult(texts: [], fullText: "")
            }

            let texts = observations.compactMap { observation -> RecognizedText? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return RecognizedText(
                    text: candidate.string,
                    confidence: candidate.confidence,
                    boundingBox: observation.boundingBox
                )
            }

            let fullText = texts.map(\.text).joined(separator: "\n")

            return RecognitionResult(texts: texts, fullText: fullText)
        }.value
    }

    func recognizeAndCopy(from image: CGImage) async throws {
        let result = try await recognizeText(in: image)

        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(result.fullText, forType: .string)
    }
}

// MARK: - Text Recognition Overlay

struct TextRecognitionOverlayView: View {
    let texts: [TextRecognitionService.RecognizedText]
    let imageSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            ForEach(texts) { text in
                let rect = convertBoundingBox(text.boundingBox, to: geometry.size)

                Rectangle()
                    .stroke(Color.blue, lineWidth: 1)
                    .background(Color.blue.opacity(0.1))
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
    }

    private func convertBoundingBox(_ box: CGRect, to size: CGSize) -> CGRect {
        // Vision bounding boxes are normalized with origin at bottom-left
        CGRect(
            x: box.origin.x * size.width,
            y: (1 - box.origin.y - box.height) * size.height,
            width: box.width * size.width,
            height: box.height * size.height
        )
    }
}
```

---

### 6.4 Implement Self-Timer Capture

**File**: `Features/Capture/SelfTimerController.swift`

```swift
import SwiftUI
import AppKit

@MainActor
final class SelfTimerController: ObservableObject {
    @Published private(set) var isCountingDown = false
    @Published private(set) var remainingSeconds: Int = 0

    private var countdownWindow: NSWindow?
    private var timer: Timer?
    private var completion: (() -> Void)?

    func startCountdown(seconds: Int, completion: @escaping () -> Void) {
        self.completion = completion
        remainingSeconds = seconds
        isCountingDown = true

        showCountdownWindow()
        startTimer()
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        countdownWindow?.close()
        countdownWindow = nil
        isCountingDown = false
        completion = nil
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        remainingSeconds -= 1

        if remainingSeconds <= 0 {
            timer?.invalidate()
            timer = nil
            countdownWindow?.close()
            countdownWindow = nil
            isCountingDown = false

            // Play sound
            NSSound(named: "Pop")?.play()

            completion?()
            completion = nil
        } else {
            updateCountdownWindow()

            // Play tick sound
            NSSound(named: "Tink")?.play()
        }
    }

    private func showCountdownWindow() {
        guard let screen = NSScreen.main else { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 150, height: 150),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.center()

        updateCountdownWindow()
        window.orderFront(nil)

        countdownWindow = window
    }

    private func updateCountdownWindow() {
        let view = CountdownView(seconds: remainingSeconds)
        countdownWindow?.contentView = NSHostingView(rootView: view)
    }
}

struct CountdownView: View {
    let seconds: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.7))

            Text("\(seconds)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 150, height: 150)
    }
}
```

---

### 6.5 Implement Background Tool

**File**: `Features/Background/BackgroundToolView.swift`

```swift
import SwiftUI

struct BackgroundConfig {
    var style: BackgroundStyle = .gradient
    var color1: Color = .blue
    var color2: Color = .purple
    var padding: CGFloat = 40
    var cornerRadius: CGFloat = 12
    var shadow: Bool = true
    var aspectRatio: AspectRatio = .auto

    enum BackgroundStyle: CaseIterable {
        case solid, gradient, mesh, image

        var displayName: String {
            switch self {
            case .solid: return "Solid"
            case .gradient: return "Gradient"
            case .mesh: return "Mesh"
            case .image: return "Image"
            }
        }
    }

    enum AspectRatio: CaseIterable {
        case auto, r1_1, r4_3, r16_9, r9_16, twitter, instagram

        var displayName: String {
            switch self {
            case .auto: return "Auto"
            case .r1_1: return "1:1"
            case .r4_3: return "4:3"
            case .r16_9: return "16:9"
            case .r9_16: return "9:16"
            case .twitter: return "Twitter"
            case .instagram: return "Instagram"
            }
        }

        var ratio: CGFloat? {
            switch self {
            case .auto: return nil
            case .r1_1: return 1.0
            case .r4_3: return 4.0 / 3.0
            case .r16_9: return 16.0 / 9.0
            case .r9_16: return 9.0 / 16.0
            case .twitter: return 16.0 / 9.0
            case .instagram: return 1.0
            }
        }
    }
}

struct BackgroundToolView: View {
    let sourceImage: NSImage
    @Binding var config: BackgroundConfig
    let onExport: (NSImage) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Preview
            GeometryReader { geometry in
                backgroundView
                    .overlay(
                        Image(nsImage: sourceImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(config.padding)
                            .cornerRadius(config.cornerRadius)
                            .shadow(radius: config.shadow ? 20 : 0)
                    )
                    .frame(
                        width: previewSize(in: geometry.size).width,
                        height: previewSize(in: geometry.size).height
                    )
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    )
            }

            Divider()

            // Controls
            HStack {
                // Style picker
                Picker("Style", selection: $config.style) {
                    ForEach(BackgroundConfig.BackgroundStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .frame(width: 100)

                // Colors
                if config.style == .gradient {
                    ColorPicker("", selection: $config.color1)
                        .labelsHidden()
                    ColorPicker("", selection: $config.color2)
                        .labelsHidden()
                } else if config.style == .solid {
                    ColorPicker("", selection: $config.color1)
                        .labelsHidden()
                }

                Spacer()

                // Padding
                HStack {
                    Text("Padding")
                    Slider(value: $config.padding, in: 0...100)
                        .frame(width: 100)
                }

                // Aspect ratio
                Picker("Ratio", selection: $config.aspectRatio) {
                    ForEach(BackgroundConfig.AspectRatio.allCases, id: \.self) { ratio in
                        Text(ratio.displayName).tag(ratio)
                    }
                }
                .frame(width: 100)

                Button("Export") {
                    if let rendered = renderFinal() {
                        onExport(rendered)
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch config.style {
        case .solid:
            Rectangle()
                .fill(config.color1)
        case .gradient:
            LinearGradient(
                colors: [config.color1, config.color2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .mesh:
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5, 0.5], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: [
                    config.color1, .purple, config.color2,
                    .orange, .white, .cyan,
                    config.color2, .mint, config.color1
                ]
            )
        case .image:
            Rectangle()
                .fill(config.color1)
        }
    }

    private func previewSize(in available: CGSize) -> CGSize {
        guard let ratio = config.aspectRatio.ratio else {
            // Auto - fit to image
            let imageRatio = sourceImage.size.width / sourceImage.size.height
            if imageRatio > available.width / available.height {
                return CGSize(
                    width: available.width * 0.9,
                    height: available.width * 0.9 / imageRatio
                )
            } else {
                return CGSize(
                    width: available.height * 0.9 * imageRatio,
                    height: available.height * 0.9
                )
            }
        }

        // Fixed ratio
        if ratio > available.width / available.height {
            return CGSize(
                width: available.width * 0.9,
                height: available.width * 0.9 / ratio
            )
        } else {
            return CGSize(
                width: available.height * 0.9 * ratio,
                height: available.height * 0.9
            )
        }
    }

    private func renderFinal() -> NSImage? {
        // Render at 2x for quality
        let scale: CGFloat = 2.0
        let outputSize = calculateOutputSize()

        let image = NSImage(size: outputSize)
        image.lockFocus()

        // Draw background
        let bgRect = NSRect(origin: .zero, size: outputSize)
        switch config.style {
        case .solid:
            NSColor(config.color1).setFill()
            bgRect.fill()
        case .gradient:
            let gradient = NSGradient(colors: [
                NSColor(config.color1),
                NSColor(config.color2)
            ])
            gradient?.draw(in: bgRect, angle: 45)
        default:
            NSColor(config.color1).setFill()
            bgRect.fill()
        }

        // Draw screenshot
        let imageRect = NSRect(
            x: config.padding,
            y: config.padding,
            width: outputSize.width - config.padding * 2,
            height: outputSize.height - config.padding * 2
        )

        if config.shadow {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
            shadow.shadowOffset = NSSize(width: 0, height: -10)
            shadow.shadowBlurRadius = 20
            shadow.set()
        }

        sourceImage.draw(in: imageRect)

        image.unlockFocus()
        return image
    }

    private func calculateOutputSize() -> NSSize {
        let imageSize = sourceImage.size
        let totalWidth = imageSize.width + config.padding * 2
        let totalHeight = imageSize.height + config.padding * 2

        if let ratio = config.aspectRatio.ratio {
            let currentRatio = totalWidth / totalHeight
            if currentRatio > ratio {
                return NSSize(width: totalWidth, height: totalWidth / ratio)
            } else {
                return NSSize(width: totalHeight * ratio, height: totalHeight)
            }
        }

        return NSSize(width: totalWidth, height: totalHeight)
    }
}
```

---

## File Structure After Milestone 6

```
ScreenPro/
├── Features/
│   ├── ScrollingCapture/
│   │   ├── ScrollingCaptureService.swift
│   │   ├── ImageStitcher.swift
│   │   └── ScrollingPreviewView.swift
│   ├── TextRecognition/
│   │   └── TextRecognitionService.swift
│   ├── Background/
│   │   └── BackgroundToolView.swift
│   ├── Capture/
│   │   ├── SelfTimerController.swift
│   │   └── ScreenFreezeController.swift
│   └── ...
```

---

## Testing Checklist

- [ ] Scrolling capture stitches multiple frames
- [ ] OCR extracts text accurately
- [ ] OCR supports multiple languages
- [ ] Self-timer counts down correctly
- [ ] Magnifier shows pixel-level detail
- [ ] Background tool applies styles
- [ ] Background tool exports at correct ratio
- [ ] All features work with multi-monitor

---

## Exit Criteria

| Criterion | Verification |
|-----------|--------------|
| Scrolling works | 10+ frames stitch |
| OCR accuracy | >95% for clear text |
| Timer works | 3-10 second delays |
| Background quality | Export at 2x |

---

## Next Steps

Proceed to [Milestone 7: Cloud & Polish](./07-cloud-polish.md).
