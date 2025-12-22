# Research: Basic Screenshot Capture

**Feature**: 002-basic-capture
**Date**: 2025-12-22

## Overview

This document captures research findings for implementing screenshot capture using ScreenCaptureKit on macOS 14+. All patterns follow the Constitution's Native macOS First principle.

---

## 1. Screenshot Capture API Selection

**Decision**: Use `SCScreenshotManager.captureImage()` as the primary screenshot API for macOS 14+.

**Rationale**:
- Purpose-built for single-frame capture with full ScreenCaptureKit feature set
- No user notification displayed during capture (privacy advantage)
- Hardware-accelerated processing reduces CPU overhead
- Async/await pattern for responsive UI
- Consistent with Constitution requirement to use ScreenCaptureKit over deprecated APIs

**Alternatives Considered**:
- `CGWindowListCreateImage`: Deprecated, explicitly prohibited by Constitution
- `AVCaptureSession`: Designed for camera/microphone, not screen content
- `SCStream` for single frame: Unnecessary overhead for still captures
- Direct `IOSurface` APIs: Lower-level, loses ScreenCaptureKit's privacy safeguards

---

## 2. Content Filter Patterns

**Decision**: Use three distinct SCContentFilter patterns based on capture mode.

### Area Capture
**Approach**: Capture full display, then crop to selected region in post-processing.

**Rationale**: ScreenCaptureKit has no native rectangular region API. Capturing display and cropping is the recommended pattern.

**Pattern**:
```
SCContentFilter(display: display, excludingWindows: [])
→ Capture full display
→ Crop CGImage to selected rect using coordinate conversion
```

### Window Capture
**Approach**: Use desktop-independent window filter for single window capture.

**Pattern**:
```
SCContentFilter(desktopIndependentWindow: window)
→ Captures window regardless of which monitor it's on
→ No child/popup windows included
→ Follows window if user moves it between monitors
```

### Fullscreen Capture
**Approach**: Use display-based filter with empty exclusions for complete display capture.

**Pattern**:
```
SCContentFilter(display: display, excludingWindows: [])
→ Captures entire display
→ Includes all visible windows in layer order
```

**Alternatives Considered**:
- Custom rectangle API: Does not exist in ScreenCaptureKit
- Window-based filter for area: Cannot specify arbitrary regions
- SCContentSharingPicker: Good UX but removes programmatic control

---

## 3. Stream Configuration for Screenshots

**Decision**: Configure for native resolution with scale factor handling.

### Resolution Settings
```
configuration.width = Int(display.width * scaleFactor)
configuration.height = Int(display.height * scaleFactor)
configuration.scalesToFit = false
configuration.pixelFormat = kCVPixelFormatType_32BGRA
configuration.colorSpaceName = CGColorSpace.sRGB
```

### Cursor Handling
```
configuration.showsCursor = settingsManager.settings.includeCursor
```

**Rationale**:
- Native resolution prevents scaling artifacts
- Scale factor handling required for Retina displays (typically 2.0x)
- BGRA format optimal for CGImage conversion and clipboard
- sRGB color space for standard display compatibility

**Alternatives Considered**:
- Fixed resolution: Loses quality on high-DPI displays
- YUV420 format: Better for video encoding, not optimal for screenshots
- Ignoring scale factor: Produces half-resolution images on Retina

---

## 4. Coordinate Conversion

**Decision**: Use explicit coordinate conversion between screen and image coordinates with Y-axis flip.

### Screen → Image Conversion
```swift
func convertToImageCoordinates(_ rect: CGRect, in displayFrame: CGRect, imageSize: CGSize) -> CGRect {
    let scaleX = imageSize.width / displayFrame.width
    let scaleY = imageSize.height / displayFrame.height

    return CGRect(
        x: (rect.origin.x - displayFrame.origin.x) * scaleX,
        y: (displayFrame.height - rect.origin.y - rect.height) * scaleY,  // Flip Y
        width: rect.width * scaleX,
        height: rect.height * scaleY
    )
}
```

**Rationale**:
- macOS screen coordinates have origin at bottom-left
- CGImage coordinates have origin at top-left
- Y-axis flip required for correct cropping
- Scale factors account for Retina displays

**Key Frame Metadata**:
- `contentRect`: Portion of frame containing actual content
- `contentScale`: Scale applied to captured content
- `scaleFactor`: Source display's scale factor

---

## 5. Multi-Monitor Support

**Decision**: Query `SCShareableContent` for available displays/windows, create selection overlays per screen.

### Content Discovery
```swift
let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
let displays = content.displays
let windows = content.windows
```

### Display Selection
- For area capture: Show overlay on screen containing cursor
- For fullscreen: Capture main display (or display with cursor)
- For window: Show all windows from all displays in picker

### Coordinate System
- Screen coordinates are global (negative X/Y possible for monitors left/above primary)
- Each SCDisplay provides origin + width/height
- Use global coordinates when handling multi-monitor selections

**Alternatives Considered**:
- Accessibility API for window discovery: Deprecated, privacy concerns
- Caching display list indefinitely: Must refresh on hot-plug events
- Single-monitor assumption: Fails for professional users

---

## 6. Window Filtering and Discovery

**Decision**: Use `SCShareableContent` with bundle ID matching for app filtering.

### Window Discovery Pattern
```swift
let windows = content.windows.filter { window in
    guard let app = window.owningApplication else { return false }
    guard window.frame.width > 50 && window.frame.height > 50 else { return false }
    guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return false }
    return true
}
```

### Filtering Criteria
- Exclude windows smaller than 50x50 pixels (system elements)
- Exclude app's own windows (prevent self-capture)
- Require owning application (filter system-level windows)
- Only on-screen windows (not minimized/hidden)

**Rationale**:
- 50x50 minimum filters menu bar extras, tooltips
- Self-exclusion prevents capturing capture UI
- On-screen only simplifies user selection

---

## 7. Performance Optimization

**Decision**: Use `SCScreenshotManager` for single-frame capture, leverage hardware acceleration.

### Screenshot Performance
- Use `SCScreenshotManager.captureImage()` for still captures
- Single-frame more efficient than stream + wait
- Hardware-accelerated with ~50% lower CPU than legacy APIs

### Target Performance
- Capture time: < 50ms (excluding user selection)
- Selection UI: 60fps for smooth crosshair/dimensions
- Memory: < 50MB idle (menu bar only)

### Avoid Performance Killers
1. Creating streams for single screenshots (use SCScreenshotManager)
2. Polling SCShareableContent continuously (refresh only on content change)
3. Processing images synchronously (use async/await)
4. Unnecessary resolution changes (capture at native resolution)

---

## 8. Selection Overlay Architecture

**Decision**: Use NSWindow subclass with SwiftUI content for selection overlay.

### Window Configuration
```swift
SelectionWindow: NSWindow
- level: .screenSaver (above all content)
- styleMask: .borderless
- isOpaque: false
- backgroundColor: .clear
- ignoresMouseEvents: false
- acceptsMouseMovedEvents: true
- collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary]
```

### Content Structure
```
SelectionOverlayView (SwiftUI)
├── Dimmed background (Color.black.opacity(0.3))
├── Selection rectangle (clear cutout with border)
├── Crosshair lines (extending to edges)
├── Dimensions display (W × H)
├── Instructions text
└── Corner handles
```

**Rationale**:
- NSWindow required for borderless fullscreen overlay
- SwiftUI provides declarative UI for selection components
- Level .screenSaver ensures overlay above all content
- .fullScreenAuxiliary allows interaction with fullscreen apps

---

## 9. Window Picker Architecture

**Decision**: Use transparent overlay windows with mouse tracking for window selection.

### Highlight Mechanism
```swift
WindowPickerOverlay: NSWindow
- Nearly transparent (0.01 alpha)
- Tracks mouse movement
- Finds topmost window at cursor position
- Posts notification to highlight window
```

### Window Highlight
```swift
NSWindow (highlight border)
- Positioned at target window's frame
- Blue border (3px) with rounded corners
- Semi-transparent blue fill
- ignoresMouseEvents: true
```

**Rationale**:
- Transparent overlay captures mouse events without obscuring content
- Separate highlight window allows visual feedback
- Border + tint provides clear indication of selected window

---

## 10. Audio Feedback

**Decision**: Use system "Grab" sound via NSSound.

### Implementation
```swift
NSSound(named: "Grab")?.play()
```

**Rationale**:
- "Grab" is the standard macOS screenshot sound
- Respects system sound settings
- Controlled by user preference (playCaptureSound setting)

---

## Summary: Architecture Decisions

| Component | Decision | Rationale |
|-----------|----------|-----------|
| Screenshot API | SCScreenshotManager | Purpose-built, hardware-accelerated |
| Area Capture | Capture display → crop | No native rectangle API |
| Window Capture | desktopIndependentWindow filter | Follows window across monitors |
| Fullscreen | Display filter | Complete display capture |
| Coordinates | Explicit Y-flip conversion | Screen vs image origin difference |
| Multi-Monitor | SCShareableContent query | Authoritative content source |
| Window Filter | Size + bundle ID matching | Clean, predictable results |
| Selection UI | NSWindow + SwiftUI | Borderless overlay with modern UI |
| Performance | Single-frame API, async | < 50ms capture target |

---

## Sources

- [What's new in ScreenCaptureKit - WWDC23](https://developer.apple.com/videos/play/wwdc2023/10136/)
- [Meet ScreenCaptureKit - WWDC22](https://developer.apple.com/videos/play/wwdc2022/10156/)
- [Take ScreenCaptureKit to the next level - WWDC22](https://developer.apple.com/videos/play/wwdc2022/10155/)
- [ScreenCaptureKit Documentation](https://developer.apple.com/documentation/screencapturekit/)
- [SCShareableContent Documentation](https://developer.apple.com/documentation/screencapturekit/scshareablecontent)
- [Recording to disk using ScreenCaptureKit - Nonstrict](https://nonstrict.eu/blog/2023/recording-to-disk-with-screencapturekit/)
