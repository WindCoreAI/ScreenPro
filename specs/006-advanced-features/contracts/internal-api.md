# Internal API Contracts: Advanced Features

**Branch**: `006-advanced-features` | **Date**: 2025-12-23

This document defines the internal service APIs for the seven advanced features. These are Swift protocols and method signatures that define the contracts between components.

---

## 1. ScrollingCaptureService

### Protocol Definition

```swift
@MainActor
protocol ScrollingCaptureServiceProtocol: ObservableObject {
    // State
    var isCapturing: Bool { get }
    var frames: [CapturedFrame] { get }
    var previewImage: CGImage? { get }

    // Actions
    func startCapture(region: CGRect, direction: ScrollDirection) async throws
    func captureFrame() async throws
    func finishCapture() async throws -> CGImage
    func cancelCapture()
}
```

### Method Contracts

#### startCapture(region:direction:)

**Preconditions**:
- region must be within screen bounds
- Screen Recording permission granted
- isCapturing == false

**Postconditions**:
- isCapturing == true
- frames contains initial frame
- Scroll monitoring active

**Errors**:
- `.permissionDenied` if screen recording not authorized
- `.invalidRegion` if region is empty or off-screen

#### finishCapture()

**Preconditions**:
- isCapturing == true
- frames.count >= 1

**Postconditions**:
- isCapturing == false
- Returns stitched CGImage
- frames cleared

**Errors**:
- `.noFrames` if no frames captured
- `.stitchingFailed` if image composition fails

---

## 2. TextRecognitionService

### Protocol Definition

```swift
@MainActor
protocol TextRecognitionServiceProtocol: ObservableObject {
    // State
    var isProcessing: Bool { get }

    // Actions
    func recognizeText(in image: CGImage) async throws -> RecognitionResult
    func recognizeAndCopy(from image: CGImage) async throws
}
```

### Method Contracts

#### recognizeText(in:)

**Preconditions**:
- image is valid CGImage

**Postconditions**:
- Returns RecognitionResult with extracted texts
- processingTime reflects actual duration

**Errors**:
- `.recognitionFailed` if Vision framework fails
- `.noTextFound` if image contains no recognizable text

**Performance**:
- Must complete within 2 seconds for typical screenshots (<4K resolution)

#### recognizeAndCopy(from:)

**Preconditions**:
- image is valid CGImage

**Postconditions**:
- Recognized text copied to NSPasteboard.general
- Pasteboard contains .string type

---

## 3. SelfTimerController

### Protocol Definition

```swift
@MainActor
protocol SelfTimerControllerProtocol: ObservableObject {
    // State
    var isCountingDown: Bool { get }
    var remainingSeconds: Int { get }

    // Actions
    func startCountdown(seconds: Int, completion: @escaping () -> Void)
    func cancel()
}
```

### Method Contracts

#### startCountdown(seconds:completion:)

**Preconditions**:
- seconds is one of: 3, 5, 10
- isCountingDown == false

**Postconditions**:
- isCountingDown == true
- Countdown window visible at screen center
- completion called after countdown reaches 0

**Side Effects**:
- Audio cue played each second
- Final audio cue on completion

#### cancel()

**Preconditions**:
- isCountingDown == true

**Postconditions**:
- isCountingDown == false
- Countdown window dismissed
- completion NOT called

---

## 4. ScreenFreezeController

### Protocol Definition

```swift
@MainActor
protocol ScreenFreezeControllerProtocol: ObservableObject {
    // State
    var isFrozen: Bool { get }
    var frozenImage: CGImage? { get }

    // Actions
    func freeze(display: CGDirectDisplayID) async throws
    func unfreeze()
    func captureFromFrozen(region: CGRect) -> CGImage?
}
```

### Method Contracts

#### freeze(display:)

**Preconditions**:
- display is valid display ID
- Screen Recording permission granted
- isFrozen == false

**Postconditions**:
- isFrozen == true
- frozenImage contains display content
- Freeze overlay window visible

**Performance**:
- Must complete within 200ms

**Errors**:
- `.permissionDenied` if screen recording not authorized
- `.displayNotFound` if display ID invalid

#### captureFromFrozen(region:)

**Preconditions**:
- isFrozen == true
- frozenImage != nil
- region within frozenImage bounds

**Postconditions**:
- Returns cropped image from frozen content

---

## 5. MagnifierView

### Protocol Definition

```swift
protocol MagnifierViewProtocol {
    // Configuration
    var zoomLevel: Int { get set }
    var isEnabled: Bool { get set }

    // Actions
    func updatePosition(cursor: CGPoint, screenBounds: CGRect)
    func setSourceImage(_ image: CGImage)
}
```

### Behavior Contracts

#### updatePosition(cursor:screenBounds:)

**Preconditions**:
- cursor is in screen coordinates
- screenBounds is valid

**Postconditions**:
- Magnifier positioned near cursor
- Magnifier stays within screenBounds
- Content shows 8x zoom of cursor area

**Performance**:
- Must complete within 16ms (60fps)

---

## 6. BackgroundToolView

### Protocol Definition

```swift
protocol BackgroundToolViewProtocol {
    // Input
    var sourceImage: NSImage { get }
    var config: BackgroundConfig { get set }

    // Actions
    func renderPreview() -> NSImage
    func export() async throws -> NSImage
}
```

### Method Contracts

#### renderPreview()

**Preconditions**:
- sourceImage is valid

**Postconditions**:
- Returns preview image at screen resolution
- Applies current config settings

**Performance**:
- Must complete within 50ms for real-time preview

#### export()

**Preconditions**:
- sourceImage is valid
- config has valid values

**Postconditions**:
- Returns final image at 2x resolution
- All styling applied (background, padding, shadow, corner radius)
- Aspect ratio matches config.aspectRatio

---

## 7. CameraOverlayController

### Protocol Definition

```swift
@MainActor
protocol CameraOverlayControllerProtocol: ObservableObject {
    // State
    var isCapturing: Bool { get }
    var currentFrame: CVPixelBuffer? { get }
    var overlayConfig: OverlayConfig { get set }

    // Actions
    func startCapture() async throws
    func stopCapture()
    func getFrameForCompositing() -> CGImage?
}
```

### Method Contracts

#### startCapture()

**Preconditions**:
- Camera permission granted
- Camera device available
- isCapturing == false

**Postconditions**:
- isCapturing == true
- Camera preview window visible
- Frames updating at capture rate

**Errors**:
- `.permissionDenied` if camera not authorized
- `.deviceNotFound` if no camera available

#### getFrameForCompositing()

**Preconditions**:
- isCapturing == true
- currentFrame != nil

**Postconditions**:
- Returns CGImage suitable for video compositing
- Image sized according to overlayConfig.size

---

## Integration Points

### AppCoordinator Extensions

```swift
extension AppCoordinator {
    // New capture modes
    func startScrollingCapture()
    func startOCRCapture()
    func startTimedCapture(seconds: Int)
    func toggleScreenFreeze()

    // Settings
    func openBackgroundTool(for image: NSImage)
    func toggleCameraOverlay()
}
```

### QuickAccessOverlay Extensions

```swift
extension QuickAccessContentView {
    // New actions
    func beautifyAction() // Opens BackgroundTool
    func extractTextAction() // Triggers OCR
}
```

### SettingsManager Extensions

```swift
extension SettingsManager {
    // Scrolling Capture
    var scrollingCaptureMaxFrames: Int { get set }
    var scrollingCaptureOverlapRatio: CGFloat { get set }

    // OCR
    var ocrLanguages: [String] { get set }
    var ocrCopyToClipboardAutomatically: Bool { get set }

    // Self-Timer
    var selfTimerDefaultDuration: Int { get set }

    // Magnifier
    var magnifierEnabled: Bool { get set }
    var magnifierZoomLevel: Int { get set }

    // Background Tool
    var defaultBackgroundStyle: BackgroundStyle { get set }
    var defaultBackgroundPadding: CGFloat { get set }

    // Camera Overlay
    var cameraOverlayEnabled: Bool { get set }
    var cameraOverlayPosition: OverlayPosition { get set }
    var cameraOverlayShape: OverlayShape { get set }
    var cameraOverlaySize: CGFloat { get set }
}
```

---

## Error Definitions

```swift
enum ScrollingCaptureError: LocalizedError {
    case permissionDenied
    case invalidRegion
    case noFrames
    case stitchingFailed
    case maxFramesReached
}

enum TextRecognitionError: LocalizedError {
    case recognitionFailed
    case noTextFound
    case invalidImage
}

enum ScreenFreezeError: LocalizedError {
    case permissionDenied
    case displayNotFound
    case captureTimeout
}

enum CameraOverlayError: LocalizedError {
    case permissionDenied
    case deviceNotFound
    case captureSessionFailed
}
```

---

## Threading Model

| Service | Main Thread | Background |
|---------|-------------|------------|
| ScrollingCaptureService | State updates | Frame stitching |
| TextRecognitionService | State updates | Vision processing |
| SelfTimerController | All | - |
| ScreenFreezeController | All | - |
| MagnifierView | All | - |
| BackgroundToolView | Preview | Export rendering |
| CameraOverlayController | State updates | Frame capture |

All services marked `@MainActor` handle thread safety automatically. Background work uses `Task.detached(priority: .userInitiated)` for CPU-intensive operations.
