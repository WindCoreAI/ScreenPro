# Research: Advanced Features

**Branch**: `006-advanced-features` | **Date**: 2025-12-23

This document captures technical research decisions for implementing the seven advanced features.

---

## 1. Scrolling Capture - Image Stitching

### Decision: Use VNTranslationalImageRegistrationRequest

**Rationale**: Vision framework provides `VNTranslationalImageRegistrationRequest` which computes the translation needed to align two images. This is purpose-built for image registration and eliminates the need for custom feature matching algorithms.

**Alternatives Considered**:

| Alternative | Rejected Because |
|-------------|-----------------|
| OpenCV (via Swift bridging) | External dependency violates Constitution I (Native macOS First) |
| Custom feature matching with SIFT/ORB | Complex implementation; Vision already provides this |
| Simple pixel comparison | Insufficient accuracy for varied content |

**Implementation Approach**:
1. Capture frames at regular intervals during scrolling
2. Detect scroll movement via mouse position delta or accessibility API
3. Use VNTranslationalImageRegistrationRequest to find overlap between consecutive frames
4. Calculate crop regions to remove duplicated overlap areas
5. Composite frames using Core Graphics with gradient blending at seams

**Performance Considerations**:
- Process stitching on background thread (Task.detached with .userInitiated priority)
- Limit preview updates to avoid blocking main thread
- Maximum 50 frames caps memory usage (~150MB for large captures)

---

## 2. OCR Text Recognition

### Decision: Use VNRecognizeTextRequest with accurate recognition

**Rationale**: Vision framework's `VNRecognizeTextRequest` provides on-device OCR supporting 20+ languages with no network dependency. Aligns with Constitution II (Privacy by Default).

**Alternatives Considered**:

| Alternative | Rejected Because |
|-------------|-----------------|
| Tesseract OCR | External dependency; Vision has better macOS integration |
| Cloud OCR APIs (Google, AWS) | Violates privacy requirements; requires network |
| Apple's older Character Recognition | Deprecated in favor of VNRecognizeTextRequest |

**Implementation Approach**:
1. Set `recognitionLevel = .accurate` for best results (vs .fast)
2. Enable `usesLanguageCorrection = true` for improved accuracy
3. Configure `recognitionLanguages` for English, Chinese, Japanese, Korean
4. Extract bounding boxes from observations for overlay visualization
5. Filter results by confidence threshold (0.5) for uncertain text indication

**Language Support**:
- Primary: en-US, zh-Hans, zh-Hant, ja, ko
- Vision framework handles mixed-language documents automatically

---

## 3. Self-Timer Capture

### Decision: Use NSWindow overlay with Timer-based countdown

**Rationale**: Simple, predictable implementation using standard macOS patterns. Timer provides accurate timing; NSWindow overlay ensures visibility across all screens.

**Alternatives Considered**:

| Alternative | Rejected Because |
|-------------|-----------------|
| CADisplayLink | Overkill for 1-second intervals |
| DispatchSourceTimer | Timer is simpler for this use case |
| Notification-based countdown | Less precise timing control |

**Implementation Approach**:
1. Present full-screen overlay window at .screenSaver level
2. Display large countdown number with circular background
3. Use Timer.scheduledTimer with 1-second repeats
4. Play system sounds: "Tink" for countdown ticks, "Pop" for capture
5. Support Escape key to cancel countdown

**Audio Feedback**:
- Use NSSound with system sounds (no custom audio files needed)
- Respect macOS "Reduce Motion" preference for countdown animation

---

## 4. Screen Freeze

### Decision: Capture full-screen image and display as overlay window

**Rationale**: Capturing the current screen content and displaying it as a borderless window creates an effective "freeze" without modifying actual screen rendering.

**Alternatives Considered**:

| Alternative | Rejected Because |
|-------------|-----------------|
| CGDisplayCapture (exclusive mode) | Would block all screen updates including cursor |
| Modify WindowServer rendering | Requires SIP disable; not sandbox compatible |
| Pause applications individually | Impractical; can't control all apps |

**Implementation Approach**:
1. Use ScreenCaptureKit to capture current display content
2. Create NSWindow at .statusBar level with captured image
3. Set window to ignore mouse events except for our selection overlay
4. Layer selection overlay on top of frozen image
5. Dispose of window on capture completion or cancel

**Multi-Monitor Support**:
- Detect which monitor triggered the freeze
- Only freeze the originating monitor
- Other monitors continue updating normally

---

## 5. Magnifier Tool

### Decision: Real-time pixel sampling with CALayer rendering

**Rationale**: Using CGImage.cropping to sample pixels around cursor and displaying in a CALayer provides smooth 60fps updates with minimal CPU overhead.

**Alternatives Considered**:

| Alternative | Rejected Because |
|-------------|-----------------|
| Continuous ScreenCaptureKit captures | Too expensive for 60fps updates |
| NSCursor with custom image | Can't show magnified content |
| Metal shader for zoom | Overkill; CALayer is sufficient |

**Implementation Approach**:
1. Capture screen once when selection mode begins (or use frozen image)
2. On cursor move, crop 20x20 pixel region centered on cursor
3. Scale to 160x160 (8x magnification) using nearestNeighbor interpolation
4. Display in floating panel positioned near cursor (offset to avoid overlap)
5. Show crosshair overlay and coordinate text

**Positioning Logic**:
- Default: 20px below and right of cursor
- Flip to left side when approaching right screen edge
- Flip above cursor when approaching bottom screen edge
- Ensure magnifier stays within screen bounds

---

## 6. Background Tool

### Decision: SwiftUI-based editor with Core Graphics export

**Rationale**: SwiftUI provides excellent real-time preview capabilities; Core Graphics ensures high-quality export at 2x resolution.

**Alternatives Considered**:

| Alternative | Rejected Because |
|-------------|-----------------|
| AppKit-only implementation | Less flexible for preview UI |
| Metal-based rendering | Overkill for static image composition |
| ImageMagick | External dependency |

**Implementation Approach**:
1. Present modal editor window from Quick Access or Annotation Editor
2. Provide style picker: solid, gradient, mesh gradient
3. Use SwiftUI color pickers for customization
4. Calculate canvas size based on selected aspect ratio
5. Render final image using NSGraphicsContext at 2x scale

**Aspect Ratio Presets**:
| Preset | Ratio | Use Case |
|--------|-------|----------|
| Auto | Match image | Default |
| 1:1 | 1.0 | Instagram square |
| 4:3 | 1.33 | Classic photo |
| 16:9 | 1.78 | Twitter, YouTube thumbnail |
| 9:16 | 0.56 | Instagram story, TikTok |

---

## 7. Camera Overlay

### Decision: AVCaptureSession with picture-in-picture compositing

**Rationale**: AVCaptureSession provides efficient camera capture; compositor layer overlays webcam during recording export.

**Alternatives Considered**:

| Alternative | Rejected Because |
|-------------|-----------------|
| ScreenCaptureKit camera capture | Not designed for isolated camera streams |
| Separate camera window recording | Requires complex window management |
| Real-time video mixing | Higher CPU usage than post-capture compositing |

**Implementation Approach**:
1. Initialize AVCaptureSession with built-in camera
2. Display preview in draggable/resizable NSWindow during recording
3. Store camera frames alongside screen recording frames
4. During export, composite camera frames onto screen recording
5. Support circular mask using CGImage masking

**Shape Options**:
- Circle: Apply CGPath clip mask
- Rounded rectangle: Use cornerRadius
- User can toggle between shapes in overlay controls

**Compositing Strategy**:
- Record screen and camera to separate tracks
- Merge during AVAssetExportSession processing
- Position based on user-configured corner/offset

---

## Common Infrastructure

### Settings Integration

All features require new settings in SettingsManager:

```swift
// ScrollingCapture
var scrollingCaptureMaxFrames: Int = 50
var scrollingCaptureOverlapRatio: CGFloat = 0.2

// OCR
var ocrLanguages: [String] = ["en-US", "zh-Hans", "zh-Hant", "ja", "ko"]
var ocrCopyToClipboardAutomatically: Bool = true

// Self-Timer
var selfTimerDuration: Int = 5  // 3, 5, or 10

// Magnifier
var magnifierEnabled: Bool = true
var magnifierZoomLevel: Int = 8

// Background Tool
var defaultBackgroundStyle: BackgroundStyle = .gradient
var defaultBackgroundColors: [Color] = [.blue, .purple]

// Camera Overlay
var cameraOverlayEnabled: Bool = false
var cameraOverlayPosition: OverlayPosition = .bottomRight
var cameraOverlayShape: OverlayShape = .circle
var cameraOverlaySize: CGFloat = 150
```

### Menu Bar Integration

Add new menu items to MenuBarView:

- Scrolling Capture (shortcut configurable)
- OCR Capture (shortcut configurable)
- Self-Timer submenu (3s, 5s, 10s)
- Screen Freeze toggle

### Quick Access Integration

All capture features route results through existing Quick Access Overlay:

- Scrolling capture → Quick Access with stitched image
- OCR capture → Quick Access with source image (text in clipboard)
- Self-timer capture → Quick Access with captured image
- Screen freeze capture → Quick Access with captured image
- Background tool accessible from Quick Access "Beautify" action

---

## Dependencies Summary

| Feature | Primary Framework | Additional |
|---------|------------------|------------|
| Scrolling Capture | ScreenCaptureKit, Vision | Core Graphics |
| OCR | Vision | - |
| Self-Timer | AppKit, SwiftUI | - |
| Screen Freeze | ScreenCaptureKit, AppKit | - |
| Magnifier | Core Graphics, AppKit | - |
| Background Tool | SwiftUI, Core Graphics | - |
| Camera Overlay | AVFoundation, AVKit | Core Image |

All dependencies are Apple-native frameworks. No external packages required.
