# Tasks: Annotation Editor

**Input**: Design documents from `/specs/004-annotation-editor/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Integration and unit tests are included per constitution requirement (V. Testing Discipline).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: macOS app following existing structure
- **Source**: `ScreenPro/Features/Annotation/`
- **Tests**: `ScreenProTests/Unit/`, `ScreenProTests/Integration/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure for Annotation feature

- [ ] T001 Create Annotation feature directory structure: `ScreenPro/Features/Annotation/{Models,Views,Toolbar,Tools,Rendering}/`
- [ ] T002 [P] Create AnnotationColor model in `ScreenPro/Features/Annotation/Models/AnnotationColor.swift` per contracts
- [ ] T003 [P] Create AnnotationTool enum in `ScreenPro/Features/Annotation/Tools/AnnotationTool.swift` per contracts
- [ ] T004 [P] Create ToolConfiguration struct in `ScreenPro/Features/Annotation/Tools/AnnotationTool.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T005 Create Annotation protocol in `ScreenPro/Features/Annotation/Models/Annotation.swift` with base properties and render/hitTest/copy methods
- [ ] T006 Create AnnotationDocument class in `ScreenPro/Features/Annotation/Models/AnnotationDocument.swift` with baseImage, annotations array, UndoManager
- [ ] T007 [P] Implement AnnotationDocument addAnnotation/removeAnnotation with undo support in `ScreenPro/Features/Annotation/Models/AnnotationDocument.swift`
- [ ] T008 [P] Implement AnnotationDocument selectAnnotation/deselectAll in `ScreenPro/Features/Annotation/Models/AnnotationDocument.swift`
- [ ] T009 Create AnnotationCanvasView in `ScreenPro/Features/Annotation/Views/AnnotationCanvasView.swift` with SwiftUI Canvas wrapper
- [ ] T010 Create AnnotationsLayer in `ScreenPro/Features/Annotation/Views/AnnotationsLayer.swift` to render annotations via CGContext
- [ ] T011 Create AnnotationToolbar in `ScreenPro/Features/Annotation/Toolbar/AnnotationToolbar.swift` with tool buttons
- [ ] T012 [P] Create ToolButton in `ScreenPro/Features/Annotation/Toolbar/ToolButton.swift` with SF Symbol icons
- [ ] T013 [P] Create ColorPickerButton in `ScreenPro/Features/Annotation/Toolbar/ColorPickerButton.swift` with preset colors
- [ ] T014 [P] Create StrokeWidthPicker in `ScreenPro/Features/Annotation/Toolbar/StrokeWidthPicker.swift`
- [ ] T015 Create AnnotationEditorWindow in `ScreenPro/Features/Annotation/AnnotationEditorWindow.swift` as NSWindow hosting SwiftUI
- [ ] T016 Create AnnotationRenderer in `ScreenPro/Features/Annotation/Rendering/AnnotationRenderer.swift` with CGContext rendering base
- [ ] T017 Update AppCoordinator state machine to support `.annotating(UUID)` state in `ScreenPro/Core/AppCoordinator.swift`
- [ ] T018 Add keyboard shortcut handling for tool selection in AnnotationCanvasView
- [ ] T019 Implement zoom and pan with ScrollView in `ScreenPro/Features/Annotation/Views/AnnotationCanvasView.swift`

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Add Arrow Annotations to Screenshots (Priority: P1) 🎯 MVP

**Goal**: Enable users to add arrows to point out specific UI elements in screenshots

**Independent Test**: Capture screenshot → open editor → select arrow tool → drag to draw → verify arrow renders in export

### Tests for User Story 1

- [ ] T020 [P] [US1] Unit test for ArrowAnnotation rendering in `ScreenProTests/Unit/AnnotationRenderingTests.swift`
- [ ] T021 [P] [US1] Unit test for arrow hit testing in `ScreenProTests/Unit/AnnotationRenderingTests.swift`

### Implementation for User Story 1

- [ ] T022 [P] [US1] Create ArrowAnnotation struct in `ScreenPro/Features/Annotation/Models/Annotation.swift` with startPoint, endPoint, style, color, strokeWidth
- [ ] T023 [P] [US1] Create ArrowStyle enum with HeadStyle (none, open, filled, circle) and LineStyle (straight, curved) in `ScreenPro/Features/Annotation/Models/Annotation.swift`
- [ ] T024 [US1] Implement ArrowAnnotation render method with arrowhead geometry calculation in `ScreenPro/Features/Annotation/Models/Annotation.swift`
- [ ] T025 [US1] Create ArrowToolHandler in `ScreenPro/Features/Annotation/Tools/ArrowToolHandler.swift` with drag gesture handling
- [ ] T026 [US1] Implement arrow preview during drag in ArrowToolHandler
- [ ] T027 [US1] Add arrow rendering to AnnotationRenderer in `ScreenPro/Features/Annotation/Rendering/AnnotationRenderer.swift`
- [ ] T028 [US1] Connect ArrowToolHandler to AnnotationCanvasView
- [ ] T029 [US1] Implement arrow color/strokeWidth from ToolConfiguration
- [ ] T030 [US1] Create ExportRenderer in `ScreenPro/Features/Annotation/Rendering/ExportRenderer.swift` with basic CGImage composition
- [ ] T031 [US1] Implement AnnotationDocument export(format:) method for PNG/JPEG/TIFF/HEIC

**Checkpoint**: User Story 1 complete - can draw arrows and export images with arrows

---

## Phase 4: User Story 2 - Blur Sensitive Information (Priority: P1)

**Goal**: Enable users to blur or pixelate sensitive regions for privacy

**Independent Test**: Open screenshot → select blur tool → drag over text → export → verify text is unreadable

### Tests for User Story 2

- [ ] T032 [P] [US2] Unit test for BlurRenderer gaussian blur in `ScreenProTests/Unit/BlurRendererTests.swift`
- [ ] T033 [P] [US2] Unit test for BlurRenderer pixelate effect in `ScreenProTests/Unit/BlurRendererTests.swift`
- [ ] T034 [P] [US2] Unit test verifying blur is irreversible on export in `ScreenProTests/Unit/BlurRendererTests.swift`

### Implementation for User Story 2

- [ ] T035 [P] [US2] Create BlurAnnotation struct in `ScreenPro/Features/Annotation/Models/Annotation.swift` with bounds, blurType, intensity
- [ ] T036 [P] [US2] Create BlurType enum (gaussian, pixelate) in `ScreenPro/Features/Annotation/Models/Annotation.swift`
- [ ] T037 [US2] Create BlurRenderer in `ScreenPro/Features/Annotation/Rendering/BlurRenderer.swift` with CIGaussianBlur
- [ ] T038 [US2] Implement CIPixellate effect in BlurRenderer
- [ ] T039 [US2] Implement BlurAnnotation render method (placeholder rectangle) in `ScreenPro/Features/Annotation/Models/Annotation.swift`
- [ ] T040 [US2] Create BlurToolHandler in `ScreenPro/Features/Annotation/Tools/BlurToolHandler.swift` with drag gesture for region selection
- [ ] T041 [US2] Implement blur region preview during drag in BlurToolHandler
- [ ] T042 [US2] Implement renderWithBlur(scale:) in AnnotationDocument that applies CIFilter before compositing
- [ ] T043 [US2] Update ExportRenderer to use renderWithBlur for destructive blur application
- [ ] T044 [US2] Add blur intensity slider to toolbar when blur tool is selected
- [ ] T045 [US2] Add pixelate tool button to toolbar

**Checkpoint**: User Story 2 complete - can blur/pixelate and export with permanent privacy masking

---

## Phase 5: User Story 3 - Add Text Labels to Screenshots (Priority: P1)

**Goal**: Enable users to add text annotations with styling options

**Independent Test**: Open screenshot → select text tool → click canvas → type text → export → verify text renders clearly

### Tests for User Story 3

- [ ] T046 [P] [US3] Unit test for TextAnnotation rendering with Core Text in `ScreenProTests/Unit/AnnotationRenderingTests.swift`
- [ ] T047 [P] [US3] Unit test for TextAnnotation bounds calculation in `ScreenProTests/Unit/AnnotationRenderingTests.swift`

### Implementation for User Story 3

- [ ] T048 [P] [US3] Create TextAnnotation struct in `ScreenPro/Features/Annotation/Models/Annotation.swift` with text, font, textColor, backgroundColor, padding
- [ ] T049 [P] [US3] Create AnnotationFont struct with name, size, weight in `ScreenPro/Features/Annotation/Models/Annotation.swift`
- [ ] T050 [US3] Implement TextAnnotation render method with Core Text CTLine in `ScreenPro/Features/Annotation/Models/Annotation.swift`
- [ ] T051 [US3] Create TextToolHandler in `ScreenPro/Features/Annotation/Tools/TextToolHandler.swift` with click-to-place behavior
- [ ] T052 [US3] Implement inline text editing TextField in TextToolHandler
- [ ] T053 [US3] Implement text bounds calculation from string size in TextAnnotation
- [ ] T054 [US3] Add text rendering to AnnotationRenderer in `ScreenPro/Features/Annotation/Rendering/AnnotationRenderer.swift`
- [ ] T055 [US3] Add font size picker to toolbar when text tool selected
- [ ] T056 [US3] Implement text background rendering with padding

**Checkpoint**: User Story 3 complete - can add styled text labels and export

---

## Phase 6: User Story 4 - Draw Shapes to Highlight Areas (Priority: P2)

**Goal**: Enable users to draw rectangles, ellipses, and lines to highlight areas

**Independent Test**: Open screenshot → select rectangle tool → drag to draw → verify shape renders with stroke/fill

### Tests for User Story 4

- [ ] T057 [P] [US4] Unit test for ShapeAnnotation rectangle rendering in `ScreenProTests/Unit/AnnotationRenderingTests.swift`
- [ ] T058 [P] [US4] Unit test for ShapeAnnotation ellipse rendering in `ScreenProTests/Unit/AnnotationRenderingTests.swift`

### Implementation for User Story 4

- [ ] T059 [P] [US4] Create ShapeAnnotation struct in `ScreenPro/Features/Annotation/Models/Annotation.swift` with shapeType, fillColor, strokeColor, strokeWidth, cornerRadius
- [ ] T060 [P] [US4] Create ShapeType enum (rectangle, ellipse, line) in `ScreenPro/Features/Annotation/Models/Annotation.swift`
- [ ] T061 [US4] Implement ShapeAnnotation render method for all shape types in `ScreenPro/Features/Annotation/Models/Annotation.swift`
- [ ] T062 [US4] Create ShapeToolHandler in `ScreenPro/Features/Annotation/Tools/ShapeToolHandler.swift` with drag gesture
- [ ] T063 [US4] Implement shape preview during drag in ShapeToolHandler
- [ ] T064 [US4] Add fill toggle button to toolbar when shape tool selected
- [ ] T065 [US4] Add shape rendering to AnnotationRenderer
- [ ] T066 [US4] Implement Shift-drag for constrained proportions (square/circle)

**Checkpoint**: User Story 4 complete - can draw shapes with stroke and optional fill

---

## Phase 7: User Story 5 - Undo and Redo Annotation Actions (Priority: P2)

**Goal**: Enable users to undo and redo annotation operations

**Independent Test**: Add annotation → Cmd+Z → annotation removed → Cmd+Shift+Z → annotation restored

### Tests for User Story 5

- [ ] T067 [P] [US5] Unit test for undo after addAnnotation in `ScreenProTests/Unit/AnnotationDocumentTests.swift`
- [ ] T068 [P] [US5] Unit test for redo after undo in `ScreenProTests/Unit/AnnotationDocumentTests.swift`
- [ ] T069 [P] [US5] Unit test for multiple sequential undos in `ScreenProTests/Unit/AnnotationDocumentTests.swift`

### Implementation for User Story 5

- [ ] T070 [US5] Implement updateAnnotation with undo support in AnnotationDocument
- [ ] T071 [US5] Implement clearAnnotations with undo support in AnnotationDocument
- [ ] T072 [US5] Add undo/redo methods that call undoManager in AnnotationDocument
- [ ] T073 [US5] Wire Cmd+Z to undo action in AnnotationEditorWindow
- [ ] T074 [US5] Wire Cmd+Shift+Z to redo action in AnnotationEditorWindow
- [ ] T075 [US5] Add undo/redo buttons to toolbar with enabled state bound to canUndo/canRedo
- [ ] T076 [US5] Add VoiceOver labels to undo/redo buttons per accessibility requirements

**Checkpoint**: User Story 5 complete - full undo/redo support for all operations

---

## Phase 8: User Story 6 - Save and Copy Annotated Images (Priority: P2)

**Goal**: Enable users to save annotated images to disk or copy to clipboard

**Independent Test**: Create annotations → Cmd+S → verify file saved with annotations → Cmd+Shift+C → paste in Preview → verify annotations

### Tests for User Story 6

- [ ] T077 [P] [US6] Integration test for save workflow in `ScreenProTests/Integration/AnnotationIntegrationTests.swift`
- [ ] T078 [P] [US6] Integration test for copy to clipboard in `ScreenProTests/Integration/AnnotationIntegrationTests.swift`

### Implementation for User Story 6

- [ ] T079 [US6] Implement save action in AnnotationEditorWindow using StorageService
- [ ] T080 [US6] Implement copy to clipboard using NSPasteboard with rendered CGImage
- [ ] T081 [US6] Wire Cmd+S to save action in AnnotationEditorWindow
- [ ] T082 [US6] Wire Cmd+Shift+C to copy action in AnnotationEditorWindow
- [ ] T083 [US6] Implement unsaved changes prompt on window close
- [ ] T084 [US6] Add save/copy buttons to toolbar with appropriate SF Symbols
- [ ] T085 [US6] Implement format selection respecting SettingsManager.defaultImageFormat
- [ ] T086 [US6] Implement cancel/close with Escape key

**Checkpoint**: User Story 6 complete - can save to disk and copy to clipboard

---

## Phase 9: User Story 7 - Use Highlighter Tool for Emphasis (Priority: P3)

**Goal**: Enable users to highlight areas with semi-transparent marker strokes

**Independent Test**: Select highlighter tool → draw strokes → verify semi-transparent yellow overlay doesn't obscure content

### Tests for User Story 7

- [ ] T087 [P] [US7] Unit test for HighlighterAnnotation multiply blend mode in `ScreenProTests/Unit/AnnotationRenderingTests.swift`

### Implementation for User Story 7

- [ ] T088 [P] [US7] Create HighlighterAnnotation struct in `ScreenPro/Features/Annotation/Models/Annotation.swift` with points array, color, strokeWidth
- [ ] T089 [US7] Implement HighlighterAnnotation render method with multiply blend mode at 0.4 alpha
- [ ] T090 [US7] Create HighlighterToolHandler in `ScreenPro/Features/Annotation/Tools/HighlighterToolHandler.swift` with continuous drag tracking
- [ ] T091 [US7] Collect points during drag into HighlighterAnnotation
- [ ] T092 [US7] Calculate bounds from points array in HighlighterAnnotation
- [ ] T093 [US7] Add highlighter rendering to AnnotationRenderer with proper blend mode

**Checkpoint**: User Story 7 complete - can highlight with semi-transparent strokes

---

## Phase 10: User Story 8 - Add Numbered Callouts (Priority: P3)

**Goal**: Enable users to add numbered circles for step-by-step annotations

**Independent Test**: Select counter tool → click 3 times → verify circles numbered 1, 2, 3

### Tests for User Story 8

- [ ] T094 [P] [US8] Unit test for CounterAnnotation number sequencing in `ScreenProTests/Unit/AnnotationRenderingTests.swift`

### Implementation for User Story 8

- [ ] T095 [P] [US8] Create CounterAnnotation struct in `ScreenPro/Features/Annotation/Models/Annotation.swift` with number, position, color, size
- [ ] T096 [US8] Implement CounterAnnotation render method with circle background and centered number text
- [ ] T097 [US8] Create CounterToolHandler in `ScreenPro/Features/Annotation/Tools/CounterToolHandler.swift` with click-to-place behavior
- [ ] T098 [US8] Implement auto-incrementing counter state in CounterToolHandler
- [ ] T099 [US8] Add counter rendering to AnnotationRenderer
- [ ] T100 [US8] Ensure deleted counters don't affect existing counter numbers

**Checkpoint**: User Story 8 complete - can add numbered callouts

---

## Phase 11: User Story 9 - Crop the Screenshot (Priority: P3)

**Goal**: Enable users to crop the screenshot before annotation or export

**Independent Test**: Select crop tool → drag region → confirm → verify canvas resizes

### Tests for User Story 9

- [ ] T101 [P] [US9] Unit test for crop applying to AnnotationDocument in `ScreenProTests/Unit/AnnotationDocumentTests.swift`

### Implementation for User Story 9

- [ ] T102 [US9] Create CropToolHandler in `ScreenPro/Features/Annotation/Tools/CropToolHandler.swift` with drag region selection
- [ ] T103 [US9] Implement crop preview overlay showing selected region
- [ ] T104 [US9] Implement confirm/cancel crop actions
- [ ] T105 [US9] Implement crop application to baseImage in AnnotationDocument
- [ ] T106 [US9] Update canvas size after crop in AnnotationDocument
- [ ] T107 [US9] Implement Shift-drag for constrained aspect ratio crop
- [ ] T108 [US9] Add crop to undo stack for reversibility

**Checkpoint**: User Story 9 complete - can crop screenshots

---

## Phase 12: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T109 [P] Create SelectionHandles view in `ScreenPro/Features/Annotation/Views/SelectionHandles.swift` for resize/move
- [ ] T110 [P] Implement annotation selection with click gesture
- [ ] T111 Implement annotation move by dragging selected annotation
- [ ] T112 Implement annotation resize via SelectionHandles drag
- [ ] T113 Implement Delete key to remove selected annotation
- [ ] T114 [P] Add VoiceOver accessibility labels to all toolbar buttons per contracts/AnnotationEditorProtocol.swift
- [ ] T115 [P] Add focus indicators to interactive elements for keyboard navigation
- [ ] T116 Implement z-order management (annotations render in creation order)
- [ ] T117 Integration test for full annotation workflow in `ScreenProTests/Integration/AnnotationIntegrationTests.swift`
- [ ] T118 Performance validation: verify < 16ms tool response for 4K images
- [ ] T119 Memory validation: verify < 300MB usage with 8K images
- [ ] T120 Run quickstart.md validation steps

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-11)**: All depend on Foundational phase completion
  - P1 stories (US1, US2, US3) can proceed in parallel after Foundation
  - P2 stories (US4, US5, US6) depend on Foundation, may use P1 patterns
  - P3 stories (US7, US8, US9) depend on Foundation, may use P1/P2 patterns
- **Polish (Phase 12)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - Core MVP
- **User Story 2 (P1)**: Can start after Foundational - Uses ExportRenderer from US1
- **User Story 3 (P1)**: Can start after Foundational - Independent
- **User Story 4 (P2)**: Can start after Foundational - Independent
- **User Story 5 (P2)**: Can start after Foundational - Builds on UndoManager setup
- **User Story 6 (P2)**: Depends on US1 ExportRenderer - Final export workflow
- **User Story 7 (P3)**: Can start after Foundational - Independent
- **User Story 8 (P3)**: Can start after Foundational - Independent
- **User Story 9 (P3)**: Can start after Foundational - Modifies document state

### Within Each User Story

- Tests written and verified to FAIL before implementation
- Models before tool handlers
- Tool handlers before integration
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel (T002-T004)
- All Foundational tasks marked [P] can run in parallel (T007-T008, T012-T014)
- Once Foundational completes, P1 user stories can start in parallel
- Tests for each user story marked [P] can run in parallel
- Models within a story marked [P] can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "Unit test for ArrowAnnotation rendering in ScreenProTests/Unit/AnnotationRenderingTests.swift"
Task: "Unit test for arrow hit testing in ScreenProTests/Unit/AnnotationRenderingTests.swift"

# Launch models for User Story 1 together:
Task: "Create ArrowAnnotation struct in ScreenPro/Features/Annotation/Models/Annotation.swift"
Task: "Create ArrowStyle enum in ScreenPro/Features/Annotation/Models/Annotation.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (Arrow annotations + basic export)
4. **STOP and VALIDATE**: Test arrow drawing and export independently
5. Deploy/demo if ready - users can annotate with arrows

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add User Story 1 (Arrows) → Test → Demo (MVP!)
3. Add User Story 2 (Blur) → Test → Demo (privacy feature!)
4. Add User Story 3 (Text) → Test → Demo (core tools complete!)
5. Add User Story 4-6 → Test → Demo (shapes, undo, save/copy)
6. Add User Story 7-9 → Test → Demo (highlighter, counter, crop)
7. Polish phase → Full annotation editor complete

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (Arrows)
   - Developer B: User Story 2 (Blur)
   - Developer C: User Story 3 (Text)
3. Stories complete and integrate independently
4. Next wave: US4, US5, US6

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Constitution requires: accessibility labels, < 16ms tool response, < 300MB memory
