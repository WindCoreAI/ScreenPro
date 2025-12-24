# Contracts: Screen Recording

**Feature**: 005-screen-recording
**Date**: 2025-12-23

## Overview

This directory contains Swift protocol definitions that define the public API contracts for the Screen Recording feature. These protocols serve as:

1. **Design documentation** - Defining the interface before implementation
2. **Testability contracts** - Enabling mock implementations for unit testing
3. **Dependency injection** - Allowing alternative implementations

## Contract Files

| File | Purpose |
|------|---------|
| `RecordingServiceProtocol.swift` | Main recording service interface for start/pause/resume/stop operations |
| `GIFEncoderProtocol.swift` | GIF encoding operations interface |
| `OverlayControllerProtocol.swift` | Click and keystroke overlay controller interfaces |

## Usage

### Dependency Injection

Services should depend on protocols rather than concrete implementations:

```swift
@MainActor
final class AppCoordinator: ObservableObject {
    private let recordingService: any RecordingServiceProtocol

    init(recordingService: any RecordingServiceProtocol = RecordingService()) {
        self.recordingService = recordingService
    }
}
```

### Testing with Mocks

```swift
@MainActor
final class MockRecordingService: RecordingServiceProtocol {
    @Published private(set) var state: RecordingState = .idle
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var recordingRegion: RecordingRegion?

    var startRecordingCalled = false
    var stopRecordingCalled = false

    func startRecording(region: RecordingRegion, format: RecordingFormat) async throws {
        startRecordingCalled = true
        state = .recording
    }

    func pauseRecording() {
        state = .paused
    }

    func resumeRecording() {
        state = .recording
    }

    func stopRecording() async throws -> RecordingResult {
        stopRecordingCalled = true
        state = .idle
        return RecordingResult(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/test.mp4"),
            duration: duration,
            format: .video(VideoConfig()),
            timestamp: Date()
        )
    }

    func cancelRecording() {
        state = .idle
    }
}
```

## Key Design Decisions

1. **@MainActor isolation**: Recording service and overlay controllers must run on main thread for UI updates
2. **Async/await**: Recording operations use Swift concurrency for clean async flow
3. **ObservableObject**: Recording service publishes state for SwiftUI binding
4. **Error types**: Custom error enums with LocalizedError for user-facing messages

## Dependencies

These contracts depend on:
- `ScreenCaptureKit` - For `SCDisplay`, `SCWindow` types in `RecordingRegion`
- `Foundation` - Core types
- `CoreGraphics` - For `CGImage` in GIF encoding
- `AppKit` - For window management in overlays
- `Combine` - For `ObservableObject` (through SwiftUI)

The data model types (`RecordingState`, `RecordingFormat`, `VideoConfig`, etc.) are defined in `data-model.md`.
