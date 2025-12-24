# Implementation Plan: Advanced Features

**Branch**: `006-advanced-features` | **Date**: 2025-12-23 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/006-advanced-features/spec.md`

## Summary

Implement seven professional-grade features for ScreenPro: scrolling capture with frame stitching, OCR text recognition using Vision framework, self-timer with countdown UI, screen freeze overlay, magnifier for pixel-precision selection, background styling tool for social media, and camera overlay for recordings. All features use native macOS frameworks (ScreenCaptureKit, Vision, AVFoundation, Core Graphics) with on-device processing.

## Technical Context

**Language/Version**: Swift 5.9+ with strict concurrency checking enabled
**Primary Dependencies**: ScreenCaptureKit (capture), Vision (OCR, image registration), AVFoundation (camera, recording), Core Graphics (image processing), Core Image (effects), ImageIO (export), SwiftUI + AppKit
**Storage**: In-memory during editing; FileManager for export via StorageService
**Testing**: XCTest for unit and integration tests
**Target Platform**: macOS 14.0+ (Sonoma) - Universal Binary (Apple Silicon + Intel)
**Project Type**: Single native macOS application
**Performance Goals**:
- Magnifier: 60fps updates during cursor movement
- Screen freeze: < 200ms activation
- OCR: < 2 seconds for typical screenshot
- Scrolling stitching: Real-time preview during scroll
**Constraints**:
- Memory: < 300MB with large images in annotation editor
- All processing on-device (no cloud services)
- App Sandbox compliant
**Scale/Scope**: Single-user desktop app, multi-monitor support required

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Verification |
|-----------|--------|--------------|
| I. Native macOS First | PASS | Uses ScreenCaptureKit, Vision, AVFoundation, Core Graphics - all Apple native frameworks |
| II. Privacy by Default | PASS | OCR via on-device Vision framework; camera captured locally; no cloud upload required |
| III. UX Excellence | PASS | All features integrate with existing Quick Access Overlay workflow; keyboard accessible |
| IV. Performance Standards | PASS | Targets defined: 60fps magnifier, <200ms freeze, <2s OCR, <50ms capture |
| V. Testing Discipline | PASS | Integration tests planned for each feature's happy path |
| VI. Accessibility Compliance | PASS | All controls will have accessible labels; keyboard navigation maintained |
| VII. Security Boundaries | PASS | App Sandbox maintained; camera permission requested only when enabled |

**Gate Result**: PASS - No violations. Ready for Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/006-advanced-features/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── internal-api.md  # Internal service contracts
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
ScreenPro/
├── Core/
│   ├── AppCoordinator.swift          # Central state machine (existing)
│   ├── Services/
│   │   ├── PermissionManager.swift   # Permission handling (existing)
│   │   ├── StorageService.swift      # File operations (existing)
│   │   └── SettingsManager.swift     # User preferences (existing)
│   └── Extensions/
│       └── VisualEffectView.swift    # AppKit helpers (existing)
├── Features/
│   ├── Capture/
│   │   ├── CaptureService.swift      # Core capture (existing, extend)
│   │   ├── SelectionOverlay/         # Selection UI (existing)
│   │   └── WindowPicker/             # Window selection (existing)
│   ├── ScrollingCapture/             # NEW FEATURE MODULE
│   │   ├── ScrollingCaptureService.swift
│   │   ├── ImageStitcher.swift
│   │   └── ScrollingPreviewView.swift
│   ├── TextRecognition/              # NEW FEATURE MODULE
│   │   ├── TextRecognitionService.swift
│   │   └── TextRecognitionOverlay.swift
│   ├── CaptureEnhancements/          # NEW FEATURE MODULE
│   │   ├── SelfTimerController.swift
│   │   ├── CountdownView.swift
│   │   ├── ScreenFreezeController.swift
│   │   └── MagnifierView.swift
│   ├── Background/                   # NEW FEATURE MODULE
│   │   ├── BackgroundToolView.swift
│   │   └── BackgroundConfig.swift
│   ├── Recording/
│   │   ├── RecordingService.swift    # Recording (existing, extend)
│   │   └── CameraOverlay/            # NEW SUB-MODULE
│   │       ├── CameraOverlayController.swift
│   │       └── CameraOverlayView.swift
│   ├── Annotation/                   # Annotation editor (existing)
│   ├── QuickAccess/                  # Quick Access Overlay (existing)
│   ├── Settings/                     # Settings UI (existing, extend)
│   └── MenuBar/                      # Menu bar (existing, extend)
└── Resources/
    └── Assets.xcassets               # App resources (existing)

ScreenProTests/
├── Integration/
│   ├── ScrollingCaptureTests.swift   # NEW
│   ├── TextRecognitionTests.swift    # NEW
│   ├── SelfTimerTests.swift          # NEW
│   └── BackgroundToolTests.swift     # NEW
└── Unit/
    ├── ImageStitcherTests.swift      # NEW
    └── MagnifierTests.swift          # NEW
```

**Structure Decision**: Extends existing feature-based module structure. New features added as separate modules under `Features/` following established patterns. Camera overlay added as sub-module of Recording since it extends that functionality.

## Complexity Tracking

> No constitution violations requiring justification.

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| 7 Features in One Milestone | Grouped by "advanced features" theme | All are capture enhancements; shared infrastructure (Quick Access integration, Settings) |
| Vision for Image Stitching | Use VNTranslationalImageRegistrationRequest | Native API for image alignment; avoids custom feature matching algorithms |
