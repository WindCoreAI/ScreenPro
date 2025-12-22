# Implementation Plan: Basic Screenshot Capture

**Branch**: `002-basic-capture` | **Date**: 2025-12-22 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-basic-capture/spec.md`

## Summary

Implement core screenshot functionality including area, window, and fullscreen capture using ScreenCaptureKit. This builds on the Milestone 1 foundation (AppCoordinator, SettingsManager, StorageService, PermissionManager) to deliver the primary capture capabilities with selection UI, multi-monitor support, and proper file/clipboard output.

## Technical Context

**Language/Version**: Swift 5.9+ with strict concurrency checking enabled
**Primary Dependencies**: ScreenCaptureKit, AppKit, SwiftUI, Core Graphics, Core Image
**Storage**: FileManager (user-configured save location), NSPasteboard (clipboard)
**Testing**: XCTest (integration tests for capture workflows)
**Target Platform**: macOS 14.0+ (Sonoma) - required for full ScreenCaptureKit screenshot API
**Project Type**: Single macOS application
**Performance Goals**: Capture < 50ms, Quick Access display < 200ms, Selection UI at 60fps
**Constraints**: App Sandbox, < 50MB memory idle, < 300MB during editing
**Scale/Scope**: Single-user desktop app, 1-4 connected displays

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Verification |
|-----------|--------|--------------|
| I. Native macOS First | PASS | Using ScreenCaptureKit (not deprecated CGWindowListCreateImage), SwiftUI+AppKit |
| II. Privacy by Default | PASS | All capture processing on-device, no data transmission |
| III. UX Excellence | PASS | Selection UI follows HIG, keyboard-accessible, < 200ms overlay target |
| IV. Performance Standards | PASS | Targeting < 50ms capture, < 16ms tool response |
| V. Testing Discipline | PASS | Will include integration tests for capture workflows |
| VI. Accessibility Compliance | PASS | Escape for cancel, VoiceOver labels, focus indicators |
| VII. Security Boundaries | PASS | App Sandbox, screen recording permission on-demand |

**Gate Status**: PASSED - No violations, proceed to Phase 0.

### Post-Design Re-Check (Phase 1 Complete)

| Principle | Status | Verification |
|-----------|--------|--------------|
| I. Native macOS First | PASS | SCScreenshotManager API, no deprecated APIs |
| II. Privacy by Default | PASS | All processing on-device, no network calls |
| III. UX Excellence | PASS | Selection overlay with crosshair/dimensions, Escape to cancel |
| IV. Performance Standards | PASS | Single-frame API for screenshots, hardware-accelerated |
| V. Testing Discipline | PASS | Integration + unit test files specified |
| VI. Accessibility Compliance | PASS | Keyboard navigation, VoiceOver labels in contracts |
| VII. Security Boundaries | PASS | Screen recording permission checked before capture |

**Post-Design Gate**: PASSED - Ready for Phase 2 task generation.

## Project Structure

### Documentation (this feature)

```text
specs/002-basic-capture/
├── plan.md              # This file
├── research.md          # Phase 0 output - ScreenCaptureKit patterns
├── data-model.md        # Phase 1 output - CaptureResult, entities
├── quickstart.md        # Phase 1 output - Build & run guide
├── contracts/           # Phase 1 output - CaptureService protocol
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
ScreenPro/
├── Core/
│   ├── AppCoordinator.swift          # (exists) Update with capture integration
│   └── Services/
│       ├── SettingsManager.swift     # (exists) Used for capture settings
│       ├── StorageService.swift      # (exists) Used for file/clipboard output
│       └── PermissionManager.swift   # (exists) Used for permission checks
│
├── Features/
│   ├── Capture/
│   │   ├── CaptureService.swift              # NEW - Core capture logic
│   │   ├── CaptureResult.swift               # NEW - Capture result model
│   │   ├── MultiMonitorSupport.swift         # NEW - Display management
│   │   ├── SelectionOverlay/
│   │   │   ├── SelectionWindow.swift         # NEW - NSWindow subclass
│   │   │   ├── SelectionOverlayView.swift    # NEW - SwiftUI selection UI
│   │   │   ├── CrosshairView.swift           # NEW - Crosshair component
│   │   │   ├── DimensionsView.swift          # NEW - Dimensions display
│   │   │   └── InstructionsView.swift        # NEW - Help text
│   │   └── WindowPicker/
│   │       ├── WindowPickerController.swift  # NEW - Window selection
│   │       └── WindowHighlightView.swift     # NEW - Window highlight
│   └── MenuBar/
│       └── MenuBarView.swift                 # (exists) Connect to capture actions

ScreenProTests/
├── Integration/
│   └── CaptureIntegrationTests.swift   # NEW - Capture workflow tests
└── Unit/
    └── CaptureServiceTests.swift       # NEW - CaptureService unit tests
```

**Structure Decision**: Feature-based module structure under `Features/Capture/` following existing pattern from Milestone 1. New capture components integrate with existing Core services.

## Complexity Tracking

> No constitution violations. All patterns follow established guidelines.
