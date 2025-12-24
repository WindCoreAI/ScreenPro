# Implementation Plan: Screen Recording

**Branch**: `005-screen-recording` | **Date**: 2025-12-23 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/005-screen-recording/spec.md`

## Summary

Implement comprehensive screen recording functionality for ScreenPro, including video recording (MP4/H.264), animated GIF creation, microphone and system audio capture, recording controls UI, and visual overlays for mouse clicks and keystrokes. This builds upon the existing CaptureService architecture and integrates with the established SettingsManager and StorageService.

## Technical Context

**Language/Version**: Swift 5.9+ with strict concurrency checking enabled
**Primary Dependencies**: ScreenCaptureKit, AVFoundation, ImageIO, AppKit, SwiftUI, Core Graphics
**Storage**: FileManager for recordings, UserDefaults for settings (via existing SettingsManager)
**Testing**: XCTest for unit tests, integration tests for recording workflows
**Target Platform**: macOS 14.0+ (Sonoma)
**Project Type**: Native macOS application (single project)
**Performance Goals**: Real-time encoding without frame drops at 30/60fps, GIF encoding at 2s/s minimum
**Constraints**: <100ms audio latency, stable memory for 30+ minute recordings, <500ms control response
**Scale/Scope**: Single-user desktop app, recordings up to 4K resolution, 60fps

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Native macOS First | ✅ PASS | Using ScreenCaptureKit, AVFoundation, ImageIO - all Apple frameworks |
| II. Privacy by Default | ✅ PASS | All processing on-device, no cloud uploads without explicit action |
| III. UX Excellence | ✅ PASS | Recording controls follow "invisible until needed" pattern |
| IV. Performance Standards | ✅ PASS | Targets align: real-time encoding, <100ms audio latency |
| V. Testing Discipline | ✅ PASS | Integration tests planned for recording workflows |
| VI. Accessibility Compliance | ✅ PASS | Recording controls will have VoiceOver labels, keyboard accessible |
| VII. Security Boundaries | ✅ PASS | Mic permission only when enabled, screen recording permission required |

**Gate Result**: PASS - Proceed to Phase 0

### Post-Phase 1 Re-check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Native macOS First | ✅ PASS | Research confirmed: ScreenCaptureKit, AVFoundation, ImageIO only |
| II. Privacy by Default | ✅ PASS | All processing on-device per research decisions |
| III. UX Excellence | ✅ PASS | Floating controls window, <500ms response targets |
| IV. Performance Standards | ✅ PASS | Bitrate tables defined, memory management addressed |
| V. Testing Discipline | ✅ PASS | Test checklist in quickstart.md |
| VI. Accessibility Compliance | ✅ PASS | Overlay accessibility documented in research.md |
| VII. Security Boundaries | ✅ PASS | Permission flow detailed in research.md |

**Post-Phase 1 Gate Result**: PASS - Ready for `/speckit.tasks`

## Project Structure

### Documentation (this feature)

```text
specs/005-screen-recording/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (internal Swift protocols)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
ScreenPro/
├── Core/
│   ├── AppCoordinator.swift          # Update with recording state
│   ├── Services/
│   │   ├── SettingsManager.swift     # Already has recording settings
│   │   └── StorageService.swift      # May need recording history support
│   └── Extensions/
│       └── AVAudioPCMBuffer+CMSampleBuffer.swift  # New helper
├── Features/
│   ├── Recording/                     # NEW - Main feature module
│   │   ├── RecordingService.swift    # Core recording logic
│   │   ├── GIFEncoder.swift          # Animated GIF creation
│   │   ├── RecordingControlsView.swift
│   │   ├── RecordingControlsWindow.swift
│   │   ├── ClickOverlayController.swift
│   │   ├── KeystrokeOverlayController.swift
│   │   └── Models/
│   │       ├── RecordingConfig.swift
│   │       ├── RecordingResult.swift
│   │       └── RecordingRegion.swift
│   └── MenuBar/
│       └── MenuBarView.swift         # Update with recording menu items
└── Tests/
    ├── Unit/
    │   ├── GIFEncoderTests.swift
    │   └── RecordingConfigTests.swift
    └── Integration/
        └── RecordingServiceTests.swift
```

**Structure Decision**: Native macOS single project structure following existing feature-based organization. New Recording module mirrors the established Capture and Annotation module patterns.

## Complexity Tracking

> No violations detected - all implementations use native Apple frameworks as required by Constitution.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |
