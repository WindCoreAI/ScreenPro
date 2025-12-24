# Quickstart: Advanced Features

**Branch**: `006-advanced-features` | **Date**: 2025-12-23

This guide provides the minimal steps to implement each advanced feature.

---

## Prerequisites

Before implementing these features, ensure:

1. ScreenPro builds and runs (Milestone 5 complete)
2. Xcode 15+ installed
3. macOS 14.0+ deployment target set
4. Screen Recording permission granted in System Settings

---

## 1. Scrolling Capture - Minimal Implementation

### Step 1: Create ScrollingCaptureService

```swift
// Features/ScrollingCapture/ScrollingCaptureService.swift

@MainActor
final class ScrollingCaptureService: ObservableObject {
    @Published private(set) var isCapturing = false
    @Published private(set) var frames: [CapturedFrame] = []

    func startCapture(region: CGRect) async throws {
        isCapturing = true
        frames.removeAll()
        try await captureFrame(region: region)
    }

    func captureFrame(region: CGRect) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { return }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(region.width * 2)
        config.height = Int(region.height * 2)

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        frames.append(CapturedFrame(image: image, scrollOffset: 0, timestamp: Date()))
    }

    func finishCapture() async throws -> CGImage {
        isCapturing = false
        // TODO: Implement stitching
        return frames.first!.image
    }
}
```

### Step 2: Wire to Menu

Add to `MenuBarView.swift`:
```swift
Button("Scrolling Capture") {
    Task { await coordinator.startScrollingCapture() }
}
```

---

## 2. OCR Text Recognition - Minimal Implementation

### Step 1: Create TextRecognitionService

```swift
// Features/TextRecognition/TextRecognitionService.swift

@MainActor
final class TextRecognitionService: ObservableObject {
    @Published private(set) var isProcessing = false

    func recognizeText(in image: CGImage) async throws -> String {
        isProcessing = true
        defer { isProcessing = false }

        return try await Task.detached {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])

            let text = request.results?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n") ?? ""

            return text
        }.value
    }

    func recognizeAndCopy(from image: CGImage) async throws {
        let text = try await recognizeText(in: image)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
```

### Step 2: Add to Quick Access

In `QuickAccessContentView.swift`, add OCR button that calls:
```swift
Task {
    try await textRecognitionService.recognizeAndCopy(from: captureImage)
}
```

---

## 3. Self-Timer - Minimal Implementation

### Step 1: Create SelfTimerController

```swift
// Features/CaptureEnhancements/SelfTimerController.swift

@MainActor
final class SelfTimerController: ObservableObject {
    @Published private(set) var remainingSeconds = 0
    private var timer: Timer?
    private var completion: (() -> Void)?

    func startCountdown(seconds: Int, completion: @escaping () -> Void) {
        self.completion = completion
        remainingSeconds = seconds
        showCountdownWindow()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        remainingSeconds -= 1
        NSSound(named: "Tink")?.play()

        if remainingSeconds <= 0 {
            timer?.invalidate()
            NSSound(named: "Pop")?.play()
            completion?()
        }
    }

    func cancel() {
        timer?.invalidate()
        remainingSeconds = 0
    }
}
```

### Step 2: Add Timer Options to Menu

```swift
Menu("Self-Timer") {
    Button("3 seconds") { startTimedCapture(3) }
    Button("5 seconds") { startTimedCapture(5) }
    Button("10 seconds") { startTimedCapture(10) }
}
```

---

## 4. Screen Freeze - Minimal Implementation

### Step 1: Create ScreenFreezeController

```swift
// Features/CaptureEnhancements/ScreenFreezeController.swift

@MainActor
final class ScreenFreezeController: ObservableObject {
    @Published private(set) var isFrozen = false
    private var frozenWindow: NSWindow?

    func freeze(displayID: CGDirectDisplayID) async throws {
        // Capture current screen
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else { return }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

        // Display as overlay window
        let window = NSWindow(contentRect: display.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .statusBar
        window.contentView = NSImageView(image: NSImage(cgImage: image, size: display.frame.size))
        window.orderFront(nil)

        frozenWindow = window
        isFrozen = true
    }

    func unfreeze() {
        frozenWindow?.close()
        frozenWindow = nil
        isFrozen = false
    }
}
```

---

## 5. Magnifier - Minimal Implementation

### Step 1: Create MagnifierView

```swift
// Features/CaptureEnhancements/MagnifierView.swift

struct MagnifierView: View {
    let sourceImage: CGImage
    let cursorPosition: CGPoint
    let zoomLevel: Int = 8

    var body: some View {
        Canvas { context, size in
            // Crop region around cursor
            let cropSize = 20
            let cropRect = CGRect(
                x: cursorPosition.x - CGFloat(cropSize/2),
                y: cursorPosition.y - CGFloat(cropSize/2),
                width: CGFloat(cropSize),
                height: CGFloat(cropSize)
            )

            if let cropped = sourceImage.cropping(to: cropRect) {
                let image = Image(cropped, scale: 1, label: Text("Magnifier"))
                context.draw(image, in: CGRect(origin: .zero, size: size))
            }
        }
        .frame(width: 160, height: 160)
        .border(Color.white, width: 2)
    }
}
```

### Step 2: Add to Selection Overlay

Display magnifier near cursor during area selection.

---

## 6. Background Tool - Minimal Implementation

### Step 1: Create BackgroundToolView

```swift
// Features/Background/BackgroundToolView.swift

struct BackgroundToolView: View {
    let sourceImage: NSImage
    @State private var padding: CGFloat = 40
    @State private var color1 = Color.blue
    @State private var color2 = Color.purple

    var body: some View {
        VStack {
            // Preview
            ZStack {
                LinearGradient(colors: [color1, color2], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(nsImage: sourceImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(padding)
                    .shadow(radius: 20)
            }
            .frame(width: 400, height: 300)

            // Controls
            HStack {
                ColorPicker("", selection: $color1)
                ColorPicker("", selection: $color2)
                Slider(value: $padding, in: 0...100)
                Button("Export") { export() }
            }
        }
    }

    func export() {
        // Render to NSImage and save
    }
}
```

---

## 7. Camera Overlay - Minimal Implementation

### Step 1: Create CameraOverlayController

```swift
// Features/Recording/CameraOverlay/CameraOverlayController.swift

@MainActor
final class CameraOverlayController: ObservableObject {
    @Published private(set) var isCapturing = false
    private var captureSession: AVCaptureSession?

    func startCapture() async throws {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            throw CameraOverlayError.deviceNotFound
        }

        session.addInput(input)
        session.startRunning()
        captureSession = session
        isCapturing = true
    }

    func stopCapture() {
        captureSession?.stopRunning()
        captureSession = nil
        isCapturing = false
    }
}
```

### Step 2: Display Preview Window

Create floating window with camera preview during recording.

---

## Verification Checklist

After implementing each feature, verify:

- [ ] Feature accessible from menu bar
- [ ] Keyboard shortcut works (if configured)
- [ ] Output appears in Quick Access Overlay
- [ ] Cancel/Escape properly cleans up
- [ ] No console errors during operation
- [ ] Memory stable after repeated use

---

## Next Steps

After minimal implementations work:

1. Run `/speckit.tasks` to generate detailed implementation tasks
2. Add comprehensive error handling
3. Implement settings UI for each feature
4. Add integration tests
5. Optimize performance to meet targets
