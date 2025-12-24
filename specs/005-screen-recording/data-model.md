# Data Model: Screen Recording

**Feature**: 005-screen-recording
**Date**: 2025-12-23

## Overview

This document defines the data entities, their attributes, relationships, and validation rules for the Screen Recording feature. All types are designed for use with Swift's strict concurrency model.

---

## Entity Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Recording Feature                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────┐         ┌─────────────────┐                   │
│  │ RecordingRegion │◄────────│ RecordingService│                   │
│  │ (enum)          │         │ (@MainActor)    │                   │
│  └─────────────────┘         └────────┬────────┘                   │
│                                       │                             │
│                              uses     │                             │
│                                       ▼                             │
│  ┌─────────────────┐         ┌─────────────────┐                   │
│  │ RecordingFormat │◄────────│ RecordingState  │                   │
│  │ (enum)          │         │ (enum)          │                   │
│  └────────┬────────┘         └─────────────────┘                   │
│           │                                                         │
│           │ contains                                                │
│           ▼                                                         │
│  ┌─────────────────┐         ┌─────────────────┐                   │
│  │ VideoConfig     │         │ GIFConfig       │                   │
│  │ (struct)        │         │ (struct)        │                   │
│  └─────────────────┘         └─────────────────┘                   │
│                                                                     │
│           produces                                                  │
│           ▼                                                         │
│  ┌─────────────────┐                                               │
│  │ RecordingResult │                                               │
│  │ (struct)        │                                               │
│  └─────────────────┘                                               │
│                                                                     │
│  ┌─────────────────┐         ┌─────────────────┐                   │
│  │ ClickEffect     │         │ KeyPress        │                   │
│  │ (struct)        │         │ (struct)        │                   │
│  └─────────────────┘         └─────────────────┘                   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Core Entities

### RecordingRegion

Defines what area of the screen to record.

```swift
/// The region of the screen to record
enum RecordingRegion {
    /// Record an entire display
    case display(SCDisplay)

    /// Record a specific window
    case window(SCWindow)

    /// Record a user-selected area on a display
    case area(CGRect, SCDisplay)
}
```

**Validation Rules**:
- For `.area`: rect must have positive width and height
- For `.area`: rect must be within the bounds of the associated display

---

### RecordingFormat

Specifies the output format for the recording.

```swift
/// The output format for recording
enum RecordingFormat {
    /// Video recording (MP4/H.264)
    case video(VideoConfig)

    /// Animated GIF recording
    case gif(GIFConfig)
}
```

---

### VideoConfig

Configuration settings for video recording.

```swift
/// Configuration for video recording
struct VideoConfig: Codable, Equatable {
    /// Output video resolution
    var resolution: Resolution = .r1080p

    /// Recording frame rate
    var frameRate: Int = 30

    /// Quality level (affects bitrate)
    var quality: Quality = .high

    /// Whether to capture system audio
    var includeSystemAudio: Bool = false

    /// Whether to capture microphone audio
    var includeMicrophone: Bool = false

    /// Whether to show click visualizations
    var showClicks: Bool = false

    /// Whether to show keystroke overlay
    var showKeystrokes: Bool = false

    /// Available video resolutions
    enum Resolution: String, CaseIterable, Codable {
        case r480p
        case r720p
        case r1080p
        case r4k

        var size: CGSize {
            switch self {
            case .r480p:  return CGSize(width: 854, height: 480)
            case .r720p:  return CGSize(width: 1280, height: 720)
            case .r1080p: return CGSize(width: 1920, height: 1080)
            case .r4k:    return CGSize(width: 3840, height: 2160)
            }
        }

        var displayName: String {
            switch self {
            case .r480p:  return "480p"
            case .r720p:  return "720p"
            case .r1080p: return "1080p"
            case .r4k:    return "4K"
            }
        }
    }

    /// Quality levels affecting bitrate
    enum Quality: String, CaseIterable, Codable {
        case low
        case medium
        case high
        case maximum

        var bitrateMultiplier: Double {
            switch self {
            case .low:     return 0.5
            case .medium:  return 0.75
            case .high:    return 1.0
            case .maximum: return 1.5
            }
        }
    }
}
```

**Validation Rules**:
- `frameRate`: Must be 15, 24, 30, or 60
- `includeMicrophone`: Requires microphone permission when true

---

### GIFConfig

Configuration settings for GIF recording.

```swift
/// Configuration for GIF recording
struct GIFConfig: Codable, Equatable {
    /// Capture frame rate (lower = smaller file)
    var frameRate: Int = 15

    /// Maximum colors in palette (GIF max is 256)
    var maxColors: Int = 256

    /// Number of times to loop (0 = infinite)
    var loopCount: Int = 0

    /// Scale factor for output size (1.0 = original, 0.5 = half)
    var scale: CGFloat = 1.0
}
```

**Validation Rules**:
- `frameRate`: Must be between 5 and 30
- `maxColors`: Must be between 2 and 256
- `loopCount`: Must be >= 0
- `scale`: Must be between 0.25 and 1.0

---

### RecordingState

The current state of the recording service.

```swift
/// Recording service state
enum RecordingState: Equatable {
    /// No recording in progress
    case idle

    /// Recording is starting (initializing capture)
    case starting

    /// Actively recording
    case recording

    /// Recording is paused
    case paused

    /// Recording is stopping (finalizing output)
    case stopping
}
```

**State Transitions**:
```
idle ──────► starting ──────► recording ◄────► paused
  ▲                              │                │
  │                              ▼                │
  └────────── stopping ◄─────────┴────────────────┘
```

---

### RecordingResult

The output of a completed recording.

```swift
/// Result of a completed recording
struct RecordingResult: Identifiable {
    /// Unique identifier for the recording
    let id: UUID

    /// File URL of the saved recording
    let url: URL

    /// Total duration in seconds
    let duration: TimeInterval

    /// The format used for this recording
    let format: RecordingFormat

    /// When the recording was created
    let timestamp: Date

    /// File size in bytes (computed lazily)
    var fileSize: Int64? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
    }
}
```

---

### ClickEffect

Visual effect shown when user clicks during recording.

```swift
/// A visual click indicator
struct ClickEffect: Identifiable {
    /// Unique identifier
    let id: UUID = UUID()

    /// Screen position of the click
    let position: CGPoint

    /// When the click occurred
    let timestamp: Date

    /// Type of click
    let clickType: ClickType

    /// Click types
    enum ClickType {
        case left
        case right

        var color: Color {
            switch self {
            case .left:  return .blue
            case .right: return .green
            }
        }
    }
}
```

---

### KeyPress

Captured keystroke for overlay display.

```swift
/// A captured keystroke
struct KeyPress: Identifiable {
    /// Unique identifier
    let id: UUID = UUID()

    /// The key character (already formatted)
    let key: String

    /// Active modifier flags
    let modifiers: NSEvent.ModifierFlags

    /// When the key was pressed
    let timestamp: Date

    /// Formatted display string with modifiers
    var displayString: String {
        var parts: [String] = []

        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }

        parts.append(key.uppercased())
        return parts.joined()
    }
}
```

---

## Errors

### RecordingError

Errors that can occur during recording operations.

```swift
/// Errors that can occur during recording
enum RecordingError: LocalizedError {
    /// No recording is currently in progress
    case notRecording

    /// A recording is already in progress
    case alreadyRecording

    /// Failed to create output file
    case cannotCreateFile(URL)

    /// Screen capture permission not granted
    case screenCaptureNotAuthorized

    /// Microphone permission not granted (when mic enabled)
    case microphoneNotAuthorized

    /// Encoding failed
    case encodingFailed(underlying: Error?)

    /// Disk space insufficient
    case insufficientDiskSpace

    /// GIF has no frames to encode
    case noFramesToEncode

    /// Unknown or unexpected error
    case unknown(underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .notRecording:
            return "No recording in progress"
        case .alreadyRecording:
            return "A recording is already in progress"
        case .cannotCreateFile(let url):
            return "Cannot create file at \(url.path)"
        case .screenCaptureNotAuthorized:
            return "Screen recording permission required"
        case .microphoneNotAuthorized:
            return "Microphone permission required"
        case .encodingFailed:
            return "Failed to encode recording"
        case .insufficientDiskSpace:
            return "Insufficient disk space"
        case .noFramesToEncode:
            return "No frames captured for GIF"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
```

---

## Relationships Summary

| Entity | Relates To | Relationship |
|--------|------------|--------------|
| RecordingService | RecordingRegion | Has one (during recording) |
| RecordingService | RecordingFormat | Has one (during recording) |
| RecordingService | RecordingState | Has one (current state) |
| RecordingService | RecordingResult | Produces one (on completion) |
| RecordingFormat | VideoConfig | Contains one (if video) |
| RecordingFormat | GIFConfig | Contains one (if GIF) |
| ClickOverlayController | ClickEffect | Has many (active effects) |
| KeystrokeOverlayController | KeyPress | Has many (recent keys) |

---

## Integration with Existing Models

### Settings Integration

The existing `Settings` struct in `SettingsManager.swift` already contains recording-related properties:

```swift
// Already exists in Settings struct:
var defaultVideoFormat: VideoFormat = .mp4
var videoQuality: VideoQuality = .high
var videoFPS: Int = 30
var recordMicrophone: Bool = false
var recordSystemAudio: Bool = false
var showClicks: Bool = false
var showKeystrokes: Bool = false
```

The `RecordingService` should read these defaults when creating `VideoConfig` or `GIFConfig`.

### CaptureType Integration

The existing `CaptureType` enum already includes `.video` and `.gif` cases, which `SettingsManager.generateFilename(for:)` uses for filename generation.

### StorageService Integration

Recordings should be saved using the existing `StorageService` patterns:
- Save to `settings.defaultSaveLocation`
- Use `SettingsManager.generateFilename(for: .video)` or `.gif`
