# Implementation Plan: Annotation Editor

**Branch**: `004-annotation-editor` | **Date**: 2025-12-22 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-annotation-editor/spec.md`

## Summary

Implement a full-featured image markup editor with drawing tools (arrows, shapes, text), privacy tools (blur, pixelate), highlighting tools (highlighter, counter), crop functionality, undo/redo support, and multi-format export. The editor opens from the Quick Access Overlay (Milestone 3) or directly after capture, allowing users to annotate screenshots before saving or sharing.

## Technical Context

**Language/Version**: Swift 5.9+ with strict concurrency checking enabled
**Primary Dependencies**: SwiftUI, AppKit (NSWindow, NSImage), Core Graphics, Core Image, Core Text
**Storage**: In-memory during editing, export to FileManager via StorageService, clipboard via NSPasteboard
**Testing**: XCTest (integration tests for annotation workflows, unit tests for annotation rendering)
**Target Platform**: macOS 14.0+ (Sonoma)
**Project Type**: Single macOS application
**Performance Goals**: Annotation tool response < 16ms (60fps), undo/redo < 100ms, export < 2s for 4K
**Constraints**: App Sandbox, < 300MB memory during editing, blur must be irreversible on export
**Scale/Scope**: Single-user desktop app, images up to 8K resolution

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Verification |
|-----------|--------|--------------|
| I. Native macOS First | PASS | Using Core Graphics/Core Image for rendering, Core Text for text, SwiftUI+AppKit for UI |
| II. Privacy by Default | PASS | All annotation processing on-device, blur permanently applied on export |
| III. UX Excellence | PASS | Toolbar follows HIG patterns, keyboard shortcuts, non-destructive editing until export |
| IV. Performance Standards | PASS | Targeting < 16ms tool response, < 100ms undo, < 2s export |
| V. Testing Discipline | PASS | Will include integration tests for annotation workflows |
| VI. Accessibility Compliance | PASS | All toolbar buttons labeled, keyboard navigation, VoiceOver support |
| VII. Security Boundaries | PASS | App Sandbox, no network operations, clipboard for copy only |

**Gate Status**: PASSED - No violations, proceed to Phase 0.

### Post-Design Re-Check (Phase 1 Complete)

| Principle | Status | Verification |
|-----------|--------|--------------|
| I. Native macOS First | PASS | Core Graphics, Core Image, Core Text, SwiftUI+AppKit only |
| II. Privacy by Default | PASS | All rendering on-device, blur destructively applied on export |
| III. UX Excellence | PASS | Toolbar with keyboard shortcuts (V, A, R, T, etc.), selection handles, undo/redo |
| IV. Performance Standards | PASS | CGContext rendering, UndoManager closures, background export |
| V. Testing Discipline | PASS | Integration + unit tests specified for workflows and rendering |
| VI. Accessibility Compliance | PASS | AnnotationEditorAccessibility enum with VoiceOver labels |
| VII. Security Boundaries | PASS | App Sandbox, no network, clipboard for copy only |

**Post-Design Gate**: PASSED - Ready for Phase 2 task generation via `/speckit.tasks`.

## Project Structure

### Documentation (this feature)

```text
specs/004-annotation-editor/
├── plan.md              # This file
├── research.md          # Phase 0 output - Core Graphics patterns, blur techniques
├── data-model.md        # Phase 1 output - Annotation types, AnnotationDocument
├── quickstart.md        # Phase 1 output - Build & run guide
├── contracts/           # Phase 1 output - AnnotationService protocol
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
ScreenPro/
├── Core/
│   ├── AppCoordinator.swift          # (exists) Add annotating state transitions
│   └── Services/
│       ├── SettingsManager.swift     # (exists) Used for image format settings
│       └── StorageService.swift      # (exists) Used for save operations
│
├── Features/
│   ├── Annotation/
│   │   ├── Models/
│   │   │   ├── Annotation.swift              # NEW - Base protocol + annotation types
│   │   │   ├── AnnotationDocument.swift      # NEW - Document model with undo support
│   │   │   └── AnnotationColor.swift         # NEW - Color model for annotations
│   │   ├── Views/
│   │   │   ├── AnnotationCanvasView.swift    # NEW - Drawing canvas
│   │   │   ├── AnnotationsLayer.swift        # NEW - Renders all annotations
│   │   │   ├── AnnotationView.swift          # NEW - Single annotation renderer
│   │   │   ├── SelectionHandles.swift        # NEW - Resize/move handles
│   │   │   └── CurrentAnnotationView.swift   # NEW - In-progress annotation
│   │   ├── Toolbar/
│   │   │   ├── AnnotationToolbar.swift       # NEW - Main toolbar
│   │   │   ├── ToolButton.swift              # NEW - Tool selection button
│   │   │   ├── ColorPickerButton.swift       # NEW - Color picker popover
│   │   │   └── StrokeWidthPicker.swift       # NEW - Stroke width selector
│   │   ├── Tools/
│   │   │   ├── AnnotationTool.swift          # NEW - Tool enum + configuration
│   │   │   ├── ArrowToolHandler.swift        # NEW - Arrow drawing logic
│   │   │   ├── ShapeToolHandler.swift        # NEW - Shape drawing logic
│   │   │   ├── TextToolHandler.swift         # NEW - Text input handling
│   │   │   ├── BlurToolHandler.swift         # NEW - Blur region creation
│   │   │   ├── HighlighterToolHandler.swift  # NEW - Highlighter strokes
│   │   │   ├── CounterToolHandler.swift      # NEW - Numbered circles
│   │   │   └── CropToolHandler.swift         # NEW - Crop functionality
│   │   ├── Rendering/
│   │   │   ├── AnnotationRenderer.swift      # NEW - Core Graphics rendering
│   │   │   ├── BlurRenderer.swift            # NEW - Core Image blur effects
│   │   │   └── ExportRenderer.swift          # NEW - Final image composition
│   │   └── AnnotationEditorWindow.swift      # NEW - NSWindow + SwiftUI hosting
│   │
│   ├── Capture/
│   │   └── CaptureResult.swift               # (exists) Input to annotation editor
│   │
│   └── QuickAccess/                          # (Milestone 3) Will trigger editor open
│
ScreenProTests/
├── Integration/
│   └── AnnotationIntegrationTests.swift      # NEW - Full annotation workflow tests
└── Unit/
    ├── AnnotationRenderingTests.swift        # NEW - Annotation rendering tests
    ├── AnnotationDocumentTests.swift         # NEW - Undo/redo tests
    └── BlurRendererTests.swift               # NEW - Blur effect tests
```

**Structure Decision**: Feature-based module structure under `Features/Annotation/` following existing pattern. Sub-organized into Models, Views, Toolbar, Tools, and Rendering for clear separation of concerns. Integrates with existing CaptureResult and StorageService.

## Complexity Tracking

> No constitution violations. All patterns follow established guidelines.
