# Quickstart: Screen Recording

**Feature**: 005-screen-recording
**Date**: 2025-12-23

## Overview

This guide provides a quick reference for implementing and testing the Screen Recording feature.

---

## Prerequisites

Before starting implementation:

1. **Permissions**: Ensure screen recording permission is granted (handled by existing `PermissionManager`)
2. **Settings**: Recording settings already exist in `SettingsManager`
3. **Dependencies**: No external packages needed - uses native Apple frameworks only

---

## Key Files to Create

| File | Priority | Description |
|------|----------|-------------|
| `Features/Recording/RecordingService.swift` | P0 | Core recording logic |
| `Features/Recording/GIFEncoder.swift` | P0 | GIF creation |
| `Features/Recording/RecordingControlsView.swift` | P0 | SwiftUI controls UI |
| `Features/Recording/RecordingControlsWindow.swift` | P0 | NSWindow for controls |
| `Features/Recording/Models/RecordingConfig.swift` | P0 | Configuration types |
| `Features/Recording/Models/RecordingResult.swift` | P0 | Result type |
| `Features/Recording/ClickOverlayController.swift` | P1 | Click visualization |
| `Features/Recording/KeystrokeOverlayController.swift` | P2 | Keystroke display |

---

## Quick Implementation Patterns

### 1. Recording Service Skeleton

```swift
import ScreenCaptureKit
import AVFoundation

@MainActor
final class RecordingService: NSObject, ObservableObject, RecordingServiceProtocol {
    @Published private(set) var state: RecordingState = .idle
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var recordingRegion: RecordingRegion?

    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?

    func startRecording(region: RecordingRegion, format: RecordingFormat) async throws {
        guard state == .idle else { throw RecordingError.alreadyRecording }
        state = .starting
        // Setup stream and writer...
        state = .recording
    }

    func stopRecording() async throws -> RecordingResult {
        guard state == .recording || state == .paused else { throw RecordingError.notRecording }
        state = .stopping
        // Finalize and return result...
        state = .idle
        return result
    }
}
```

### 2. GIF Encoder Pattern

```swift
import ImageIO
import UniformTypeIdentifiers

enum GIFEncoder: GIFEncoderProtocol {
    static func encode(frames: [CGImage], frameDelay: Double, loopCount: Int, to url: URL) throws {
        guard !frames.isEmpty else { throw GIFEncoderError.noFrames }

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.gif.identifier as CFString,
            frames.count,
            nil
        ) else { throw GIFEncoderError.failedToCreateDestination }

        // Set loop count
        let fileProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: loopCount
            ]
        ]
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)

        // Add each frame
        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay
            ]
        ]
        for frame in frames {
            CGImageDestinationAddImage(destination, frame, frameProperties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw GIFEncoderError.failedToFinalize
        }
    }
}
```

### 3. Floating Controls Window

```swift
final class RecordingControlsWindow: NSWindow {
    init(service: RecordingService, onStop: @escaping () -> Void) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 44),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]

        contentView = NSHostingView(
            rootView: RecordingControlsView(service: service, onStop: onStop)
        )

        centerOnScreen()
    }

    private func centerOnScreen() {
        guard let screen = NSScreen.main else { return }
        let x = screen.frame.midX - frame.width / 2
        let y = screen.frame.maxY - frame.height - 50
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
```

---

## Testing Checklist

### Unit Tests
- [ ] `VideoConfig` validation (valid frame rates, resolutions)
- [ ] `GIFConfig` validation (scale range, loop count)
- [ ] `RecordingState` transitions
- [ ] `GIFEncoder.reduceFrames` frame reduction logic

### Integration Tests
- [ ] Start recording → verify state changes to `.recording`
- [ ] Stop recording → verify MP4 file created and playable
- [ ] Pause/Resume → verify duration timer behavior
- [ ] GIF recording → verify animated GIF loops correctly
- [ ] Cancel recording → verify no file saved

### Manual Tests
- [ ] Record fullscreen → playback smooth
- [ ] Record window → only window content captured
- [ ] Record area → only selected area captured
- [ ] Microphone audio → voice audible in playback
- [ ] System audio → computer sounds captured
- [ ] Click visualization → rings appear at click locations
- [ ] Keystroke overlay → keys displayed correctly
- [ ] Long recording (10+ min) → no memory issues
- [ ] Multi-monitor → correct display recorded

---

## Common Gotchas

### 1. SCStream Delegate is nonisolated
```swift
// SCStreamDelegate methods are nonisolated
extension RecordingService: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        // Must dispatch back to MainActor
        Task { @MainActor in
            self.handleStreamError(error)
        }
    }
}
```

### 2. AVAssetWriter Session Start
```swift
// Start session at first frame's timestamp, not zero
if assetWriter?.status == .unknown {
    let startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    assetWriter?.startWriting()
    assetWriter?.startSession(atSourceTime: startTime)
}
```

### 3. GIF Frame Memory
```swift
// GIF frames are kept in memory - warn for long recordings
if gifFrames.count > 300 { // ~10 seconds at 30fps
    // Consider warning user about memory
}
```

### 4. Pause Timestamp Handling
```swift
// Track pause offset for seamless playback
private var pauseOffset: CMTime = .zero

func resumeRecording() {
    let now = CMClockGetTime(CMClockGetHostTimeClock())
    let pauseDuration = CMTimeSubtract(now, pauseStartTime)
    pauseOffset = CMTimeAdd(pauseOffset, pauseDuration)
}
```

---

## AppCoordinator Integration

Update `AppCoordinator` to include recording state:

```swift
@MainActor
final class AppCoordinator: ObservableObject {
    enum State {
        case idle
        case capturing(CaptureMode)
        case recording       // ADD THIS
        case annotating(CaptureResult)
        case uploading(CaptureResult)
    }

    private let recordingService: RecordingService  // ADD THIS

    func startRecording(region: RecordingRegion, format: RecordingFormat) async throws {
        state = .recording
        try await recordingService.startRecording(region: region, format: format)
    }
}
```

---

## Menu Bar Integration

Add recording options to `MenuBarView`:

```swift
// In MenuBarView
Menu("Record Screen") {
    Button("Record Fullscreen") { coordinator.recordFullscreen() }
    Button("Record Window...") { coordinator.recordWindow() }
    Button("Record Area...") { coordinator.recordArea() }
    Divider()
    Toggle("GIF Mode", isOn: $gifMode)
}
```

---

## Success Metrics Reference

| Metric | Target | How to Verify |
|--------|--------|---------------|
| Control response | <500ms | Time button click to state change |
| Video frame rate | 30/60fps stable | Frame timing in Instruments |
| GIF encoding speed | 2s content/s | Measure encoding time |
| Audio latency | <100ms | A/V sync check in playback |
| Memory (30 min) | Stable | Instruments memory graph |
