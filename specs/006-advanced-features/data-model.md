# Data Model: Advanced Features

**Branch**: `006-advanced-features` | **Date**: 2025-12-23

This document defines the data entities for the seven advanced features.

---

## Entity Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Advanced Features                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────┐    ┌─────────────────────┐    ┌──────────────────┐ │
│  │ ScrollingCapture    │    │ TextRecognition     │    │ CaptureEnhance   │ │
│  ├─────────────────────┤    ├─────────────────────┤    ├──────────────────┤ │
│  │ - CapturedFrame     │    │ - RecognizedText    │    │ - TimerConfig    │ │
│  │ - StitchConfig      │    │ - RecognitionResult │    │ - FreezeState    │ │
│  │ - ScrollDirection   │    │ - LanguageOption    │    │ - MagnifierState │ │
│  └─────────────────────┘    └─────────────────────┘    └──────────────────┘ │
│                                                                              │
│  ┌─────────────────────┐    ┌─────────────────────┐                         │
│  │ BackgroundTool      │    │ CameraOverlay       │                         │
│  ├─────────────────────┤    ├─────────────────────┤                         │
│  │ - BackgroundConfig  │    │ - OverlayConfig     │                         │
│  │ - BackgroundStyle   │    │ - OverlayPosition   │                         │
│  │ - AspectRatioPreset │    │ - OverlayShape      │                         │
│  └─────────────────────┘    └─────────────────────┘                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Scrolling Capture Entities

### ScrollDirection

Represents the direction(s) to capture during scrolling.

| Field | Type | Description |
|-------|------|-------------|
| vertical | case | Capture vertical scrolling content |
| horizontal | case | Capture horizontal scrolling content |
| both | case | Capture in both directions |

### CapturedFrame

Represents a single captured frame during scrolling capture.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | UUID | Yes | Unique identifier |
| image | CGImage | Yes | The captured frame image data |
| scrollOffset | CGFloat | Yes | Scroll position when captured |
| timestamp | Date | Yes | When the frame was captured |

**Validation Rules**:
- image must not be nil
- scrollOffset is relative to first frame (starts at 0)
- timestamp must be later than previous frame

### StitchConfig

Configuration for the scrolling capture behavior.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| direction | ScrollDirection | Yes | .vertical | Scroll direction to capture |
| captureInterval | TimeInterval | No | 0.15 | Seconds between frame captures |
| overlapRatio | CGFloat | No | 0.2 | Expected overlap between frames (0.1-0.5) |
| maxFrames | Int | No | 50 | Maximum frames to capture |

**Validation Rules**:
- captureInterval must be >= 0.05 and <= 0.5
- overlapRatio must be >= 0.1 and <= 0.5
- maxFrames must be >= 5 and <= 100

---

## 2. Text Recognition Entities

### RecognizedText

Represents a single recognized text block.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | UUID | Yes | Unique identifier |
| text | String | Yes | The recognized text content |
| confidence | Float | Yes | Recognition confidence (0.0-1.0) |
| boundingBox | CGRect | Yes | Normalized bounding box (Vision coordinates) |

**Validation Rules**:
- text must not be empty
- confidence must be between 0.0 and 1.0
- boundingBox values must be normalized (0.0-1.0)

### RecognitionResult

Aggregated result from text recognition.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| texts | [RecognizedText] | Yes | Individual text blocks |
| fullText | String | Yes | All text concatenated with newlines |
| processingTime | TimeInterval | No | How long recognition took |
| sourceImageSize | CGSize | Yes | Size of source image for coordinate conversion |

**State Transitions**:
- Initial → Processing → Complete
- Initial → Processing → Failed (on error)

### LanguageOption

Supported recognition languages.

| Field | Type | Description |
|-------|------|-------------|
| english | case | en-US recognition |
| chineseSimplified | case | zh-Hans recognition |
| chineseTraditional | case | zh-Hant recognition |
| japanese | case | ja recognition |
| korean | case | ko recognition |

---

## 3. Capture Enhancement Entities

### TimerConfig

Configuration for self-timer capture.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| duration | Int | Yes | 5 | Countdown seconds (3, 5, or 10) |
| playSound | Bool | No | true | Play countdown audio cues |
| captureMode | CaptureMode | Yes | - | What to capture after countdown |

**Validation Rules**:
- duration must be one of: 3, 5, 10
- captureMode from existing CaptureTypes

### TimerState

Runtime state for self-timer countdown.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| isCountingDown | Bool | Yes | Whether countdown is active |
| remainingSeconds | Int | Yes | Seconds left in countdown |
| startTime | Date | No | When countdown started |

**State Transitions**:
- Idle → CountingDown (on start)
- CountingDown → Idle (on cancel)
- CountingDown → Capturing (on complete)
- Capturing → Idle (after capture)

### FreezeState

Runtime state for screen freeze.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| isFrozen | Bool | Yes | Whether screen is frozen |
| frozenImage | CGImage | No | The frozen screen content |
| frozenDisplayID | CGDirectDisplayID | No | Which display is frozen |

**State Transitions**:
- Normal → Frozen (on freeze initiation)
- Frozen → Normal (on capture or cancel)

### MagnifierState

Runtime state for magnifier display.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| isVisible | Bool | Yes | Whether magnifier is shown |
| cursorPosition | CGPoint | Yes | Current cursor screen position |
| zoomLevel | Int | No | Magnification factor (default 8) |

---

## 4. Background Tool Entities

### BackgroundStyle

Type of background to apply.

| Field | Type | Description |
|-------|------|-------------|
| solid | case | Single color background |
| gradient | case | Linear gradient with two colors |
| mesh | case | Mesh gradient with multiple colors |

### AspectRatioPreset

Predefined aspect ratio options.

| Field | Type | Ratio | Description |
|-------|------|-------|-------------|
| auto | case | nil | Match source image ratio |
| square | case | 1.0 | 1:1 square |
| standard | case | 1.33 | 4:3 standard photo |
| widescreen | case | 1.78 | 16:9 widescreen |
| portrait | case | 0.56 | 9:16 vertical |
| twitter | case | 1.78 | Twitter/X optimal |
| instagram | case | 1.0 | Instagram feed |

### BackgroundConfig

Complete configuration for background styling.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| style | BackgroundStyle | Yes | .gradient | Background type |
| primaryColor | Color | Yes | .blue | First/main color |
| secondaryColor | Color | No | .purple | Second color for gradients |
| padding | CGFloat | Yes | 40 | Padding around image in points |
| cornerRadius | CGFloat | No | 12 | Image corner rounding |
| shadowEnabled | Bool | No | true | Apply drop shadow |
| shadowRadius | CGFloat | No | 20 | Shadow blur radius |
| aspectRatio | AspectRatioPreset | Yes | .auto | Canvas aspect ratio |

**Validation Rules**:
- padding must be >= 0 and <= 200
- cornerRadius must be >= 0 and <= 50
- shadowRadius must be >= 0 and <= 50

---

## 5. Camera Overlay Entities

### OverlayPosition

Where the camera overlay appears.

| Field | Type | Description |
|-------|------|-------------|
| topLeft | case | Top-left corner |
| topRight | case | Top-right corner |
| bottomLeft | case | Bottom-left corner |
| bottomRight | case | Bottom-right corner |
| custom(CGPoint) | case | User-defined position |

### OverlayShape

Shape of the camera overlay.

| Field | Type | Description |
|-------|------|-------------|
| circle | case | Circular mask |
| roundedRect | case | Rounded rectangle |

### OverlayConfig

Configuration for camera overlay during recording.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| enabled | Bool | Yes | false | Whether overlay is active |
| position | OverlayPosition | Yes | .bottomRight | Overlay position |
| shape | OverlayShape | Yes | .circle | Overlay shape |
| size | CGFloat | Yes | 150 | Diameter/width in points |
| borderWidth | CGFloat | No | 2 | Border stroke width |
| borderColor | Color | No | .white | Border color |

**Validation Rules**:
- size must be >= 50 and <= 400
- borderWidth must be >= 0 and <= 10

### CameraState

Runtime state for camera capture.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| isCapturing | Bool | Yes | Whether camera is active |
| currentFrame | CVPixelBuffer | No | Latest camera frame |
| deviceID | String | No | Active camera device identifier |

---

## Entity Relationships

```
CaptureService (existing)
    │
    ├── extends with → ScrollingCaptureService
    │       └── uses → CapturedFrame, StitchConfig
    │
    ├── extends with → TextRecognitionService
    │       └── produces → RecognitionResult
    │
    └── extends with → CaptureEnhancements
            ├── SelfTimerController → TimerConfig, TimerState
            ├── ScreenFreezeController → FreezeState
            └── MagnifierView → MagnifierState

RecordingService (existing)
    │
    └── extends with → CameraOverlayController
            └── uses → OverlayConfig, CameraState

AnnotationEditor (existing)
    │
    └── extends with → BackgroundToolView
            └── uses → BackgroundConfig

QuickAccessOverlay (existing)
    │
    └── receives output from all features
```

---

## Storage Considerations

| Entity | Persistence | Location |
|--------|-------------|----------|
| CapturedFrame | Transient | In-memory during capture |
| RecognizedText | Transient | Clipboard on copy |
| BackgroundConfig | UserDefaults | Via SettingsManager |
| OverlayConfig | UserDefaults | Via SettingsManager |
| All *State entities | Transient | Controller properties |

No new SwiftData models required. All runtime state is transient. User preferences stored in existing SettingsManager via UserDefaults.
