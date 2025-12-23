# Implementation Plan: Quick Access Overlay

**Branch**: `003-quick-access-overlay` | **Date**: 2025-12-22 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-quick-access-overlay/spec.md`

## Summary

Implement the Quick Access Overlay - a floating thumbnail window that appears after screenshot capture, providing quick actions (Copy, Save, Annotate, Dismiss) and drag-and-drop functionality. The overlay queues multiple captures, supports keyboard navigation, and integrates with the existing AppCoordinator capture flow.

## Technical Context

**Language/Version**: Swift 5.9+ with strict concurrency checking enabled
**Primary Dependencies**: SwiftUI (views), AppKit (NSWindow, NSPasteboard, NSDraggingSource), Core Graphics (thumbnail generation)
**Storage**: In-memory queue (no persistence - captures discarded on dismiss)
**Testing**: XCTest for unit/integration tests
**Target Platform**: macOS 14.0+ (Sonoma)
**Project Type**: Native macOS application (single project)
**Performance Goals**: <200ms overlay appearance, 60fps interactions, <50MB memory with 5 captures
**Constraints**: <200ms from capture complete to overlay visible, thumbnail generation must not block main thread
**Scale/Scope**: Queue supports 10+ captures, 5 visible at once

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Requirement | Status | Notes |
|-----------|-------------|--------|-------|
| I. Native macOS First | Use Apple frameworks only | PASS | AppKit NSWindow, SwiftUI views, Core Graphics thumbnails |
| II. Privacy by Default | All processing on-device | PASS | No cloud operations, in-memory only |
| III. UX Excellence | Quick Access <200ms, keyboard accessible | PASS | Primary focus of this feature |
| IV. Performance Standards | <200ms overlay, <50MB memory | PASS | Targets align with constitution |
| V. Testing Discipline | Integration tests for happy path | PASS | Will include tests for capture→overlay flow |
| VI. Accessibility Compliance | VoiceOver, keyboard navigation | PASS | Keyboard shortcuts, accessible labels required |
| VII. Security Boundaries | App Sandbox compliance | PASS | No new permissions required |

**Gate Status**: PASS - All constitutional principles satisfied

## Project Structure

### Documentation (this feature)

```text
specs/003-quick-access-overlay/
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
│   ├── AppCoordinator.swift       # UPDATE: Add QuickAccess integration
│   └── Services/
│       └── SettingsManager.swift  # EXISTING: Already has QuickAccess settings
│
├── Features/
│   ├── Capture/
│   │   └── CaptureResult.swift    # EXISTING: Source for CaptureItem
│   │
│   └── QuickAccess/               # NEW: Feature module
│       ├── QuickAccessWindowController.swift  # Main controller
│       ├── QuickAccessWindow.swift            # NSWindow subclass
│       ├── QuickAccessContentView.swift       # SwiftUI content
│       ├── QuickAccessItemView.swift          # Individual capture view
│       ├── DraggableThumbnail.swift           # Drag source view
│       ├── CaptureItem.swift                  # Queue item model
│       └── CaptureQueue.swift                 # Queue manager
│
└── Core/Extensions/
    └── VisualEffectView.swift     # NEW: NSVisualEffectView wrapper

ScreenProTests/
├── QuickAccess/
│   ├── CaptureQueueTests.swift
│   ├── CaptureItemTests.swift
│   └── QuickAccessIntegrationTests.swift
```

**Structure Decision**: Feature module pattern following existing codebase structure (Features/Capture, Features/Settings). QuickAccess module owns all overlay-related code. Integration with AppCoordinator via existing `handleCaptureResult` method modification.

## Complexity Tracking

> No constitution violations - section intentionally empty.

## Integration Points

### Existing Code to Modify

1. **AppCoordinator.swift**
   - Add `quickAccessController` property
   - Modify `handleCaptureResult()` to route to Quick Access when enabled
   - Add `openAnnotationEditor(for:)` method (placeholder for Milestone 4)

2. **Settings (already exists)**
   - `showQuickAccess: Bool` - already defined
   - `quickAccessPosition: QuickAccessPosition` - already defined
   - `autoDismissDelay: TimeInterval` - already defined

### Dependencies on Existing Code

- `CaptureResult` - provides image, timestamp, dimensions
- `CaptureService` - `save()`, `copyToClipboard()` methods
- `SettingsManager` - access to Quick Access settings
- `StorageService` - file operations for save action

---

## Post-Design Constitution Re-Check

*Verified after Phase 1 design artifacts completed.*

| Principle | Status | Design Verification |
|-----------|--------|---------------------|
| I. Native macOS First | PASS | Uses NSWindow, SwiftUI, CGContext - no external deps |
| II. Privacy by Default | PASS | All processing local, no network calls |
| III. UX Excellence | PASS | <200ms target, keyboard nav in design |
| IV. Performance Standards | PASS | Async thumbnails, memory-limited queue |
| V. Testing Discipline | PASS | Integration tests specified in quickstart.md |
| VI. Accessibility Compliance | PASS | Keyboard shortcuts, will add VoiceOver labels |
| VII. Security Boundaries | PASS | No new permissions, sandbox compliant |

**Final Gate Status**: PASS - Ready for task generation

---

## Generated Artifacts

| Artifact | Path | Purpose |
|----------|------|---------|
| Specification | [spec.md](./spec.md) | Requirements and user stories |
| Research | [research.md](./research.md) | Technical decisions and patterns |
| Data Model | [data-model.md](./data-model.md) | Entity definitions and relationships |
| Contracts | [contracts/QuickAccessProtocols.swift](./contracts/QuickAccessProtocols.swift) | Swift protocol definitions |
| Quick Start | [quickstart.md](./quickstart.md) | Implementation guide |

## Next Steps

Run `/speckit.tasks` to generate the detailed task breakdown for implementation.
