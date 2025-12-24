# Tasks: Advanced Features

**Input**: Design documents from `/specs/006-advanced-features/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/internal-api.md

**Tests**: Integration tests are included based on constitution requirement (Testing Discipline - happy path tests for each feature).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **macOS app**: `ScreenPro/` for source, `ScreenProTests/` for tests
- Feature modules under `ScreenPro/Features/`
- Core services under `ScreenPro/Core/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create new feature module directories and shared infrastructure

- [x] T001 Create ScrollingCapture feature directory structure in ScreenPro/Features/ScrollingCapture/
- [x] T002 [P] Create TextRecognition feature directory structure in ScreenPro/Features/TextRecognition/
- [x] T003 [P] Create CaptureEnhancements feature directory structure in ScreenPro/Features/CaptureEnhancements/
- [x] T004 [P] Create Background feature directory structure in ScreenPro/Features/Background/
- [x] T005 [P] Create CameraOverlay sub-module directory in ScreenPro/Features/Recording/CameraOverlay/
- [x] T006 [P] Create Integration and Unit test directories in ScreenProTests/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Extend SettingsManager and shared error types that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T007 Add scrolling capture settings (maxFrames, overlapRatio) to ScreenPro/Core/Services/SettingsManager.swift
- [x] T008 [P] Add OCR settings (languages, copyToClipboard) to ScreenPro/Core/Services/SettingsManager.swift
- [x] T009 [P] Add self-timer settings (defaultDuration) to ScreenPro/Core/Services/SettingsManager.swift
- [x] T010 [P] Add magnifier settings (enabled, zoomLevel) to ScreenPro/Core/Services/SettingsManager.swift
- [x] T011 [P] Add background tool settings (style, padding) to ScreenPro/Core/Services/SettingsManager.swift
- [x] T012 [P] Add camera overlay settings (enabled, position, shape, size) to ScreenPro/Core/Services/SettingsManager.swift
- [x] T013 Create ScrollingCaptureError enum in ScreenPro/Features/ScrollingCapture/ScrollingCaptureError.swift
- [x] T014 [P] Create TextRecognitionError enum in ScreenPro/Features/TextRecognition/TextRecognitionError.swift
- [x] T015 [P] Create ScreenFreezeError enum in ScreenPro/Features/CaptureEnhancements/ScreenFreezeError.swift
- [x] T016 [P] Create CameraOverlayError enum in ScreenPro/Features/Recording/CameraOverlay/CameraOverlayError.swift
- [x] T017 Add advanced features settings tab in ScreenPro/Features/Settings/AdvancedFeaturesSettingsTab.swift
- [x] T018 Wire AdvancedFeaturesSettingsTab into SettingsView in ScreenPro/Features/Settings/SettingsView.swift

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Scrolling Capture (Priority: P1) MVP

**Goal**: Users can capture long scrollable content (webpages, documents) and stitch into a single image

**Independent Test**: Initiate scrolling capture on a long webpage, scroll through content, confirm stitched output contains all content without visible seams

### Tests for User Story 1

- [ ] T019 [P] [US1] Integration test for scrolling capture workflow in ScreenProTests/Integration/ScrollingCaptureTests.swift
- [ ] T020 [P] [US1] Unit test for ImageStitcher in ScreenProTests/Unit/ImageStitcherTests.swift

### Models for User Story 1

- [x] T021 [P] [US1] Create ScrollDirection enum in ScreenPro/Features/ScrollingCapture/Models/ScrollDirection.swift
- [x] T022 [P] [US1] Create CapturedFrame struct in ScreenPro/Features/ScrollingCapture/Models/CapturedFrame.swift
- [x] T023 [P] [US1] Create StitchConfig struct in ScreenPro/Features/ScrollingCapture/Models/StitchConfig.swift

### Implementation for User Story 1

- [x] T024 [US1] Implement ImageStitcher using VNTranslationalImageRegistrationRequest in ScreenPro/Features/ScrollingCapture/ImageStitcher.swift
- [x] T025 [US1] Implement ScrollingCaptureService with frame capture and scroll monitoring in ScreenPro/Features/ScrollingCapture/ScrollingCaptureService.swift
- [x] T026 [US1] Create ScrollingPreviewView for live stitched preview in ScreenPro/Features/ScrollingCapture/ScrollingPreviewView.swift
- [x] T027 [US1] Add startScrollingCapture() method to AppCoordinator in ScreenPro/Core/AppCoordinator.swift
- [x] T028 [US1] Add Scrolling Capture menu item to MenuBarView in ScreenPro/Features/MenuBar/MenuBarView.swift
- [x] T029 [US1] Integrate scrolling capture output with QuickAccessOverlay in ScreenPro/Features/QuickAccess/QuickAccessWindowController.swift

**Checkpoint**: Scrolling capture fully functional - can test independently

---

## Phase 4: User Story 2 - OCR Text Recognition (Priority: P1)

**Goal**: Users can extract text from any screen region and copy to clipboard

**Independent Test**: Capture region containing text, verify extracted text matches visible content and is in clipboard

### Tests for User Story 2

- [ ] T030 [P] [US2] Integration test for OCR workflow in ScreenProTests/Integration/TextRecognitionTests.swift

### Models for User Story 2

- [x] T031 [P] [US2] Create RecognizedText struct in ScreenPro/Features/TextRecognition/Models/RecognizedText.swift
- [x] T032 [P] [US2] Create RecognitionResult struct in ScreenPro/Features/TextRecognition/Models/RecognitionResult.swift
- [x] T033 [P] [US2] Create LanguageOption enum in ScreenPro/Features/TextRecognition/Models/LanguageOption.swift

### Implementation for User Story 2

- [x] T034 [US2] Implement TextRecognitionService using VNRecognizeTextRequest in ScreenPro/Features/TextRecognition/TextRecognitionService.swift
- [x] T035 [US2] Create TextRecognitionOverlay view for bounding box display in ScreenPro/Features/TextRecognition/TextRecognitionOverlay.swift
- [x] T036 [US2] Add startOCRCapture() method to AppCoordinator in ScreenPro/Core/AppCoordinator.swift
- [x] T037 [US2] Add OCR Capture menu item to MenuBarView in ScreenPro/Features/MenuBar/MenuBarView.swift
- [x] T038 [US2] Add extractTextAction() to QuickAccessContentView for OCR from captured images in ScreenPro/Features/QuickAccess/QuickAccessContentView.swift

**Checkpoint**: OCR capture fully functional - can test independently

---

## Phase 5: User Story 3 - Self-Timer Capture (Priority: P2)

**Goal**: Users can set a countdown timer (3/5/10 seconds) before capture triggers

**Independent Test**: Set 5-second timer, open context menu during countdown, verify menu is captured after timer completes

### Tests for User Story 3

- [ ] T039 [P] [US3] Integration test for self-timer workflow in ScreenProTests/Integration/SelfTimerTests.swift

### Models for User Story 3

- [x] T040 [P] [US3] Create TimerConfig struct in ScreenPro/Features/CaptureEnhancements/Models/TimerConfig.swift
- [x] T041 [P] [US3] Create TimerState struct in ScreenPro/Features/CaptureEnhancements/Models/TimerState.swift

### Implementation for User Story 3

- [x] T042 [US3] Implement SelfTimerController with Timer-based countdown in ScreenPro/Features/CaptureEnhancements/SelfTimerController.swift
- [x] T043 [US3] Create CountdownView with large number display in ScreenPro/Features/CaptureEnhancements/CountdownView.swift
- [x] T044 [US3] Add startTimedCapture(seconds:) method to AppCoordinator in ScreenPro/Core/AppCoordinator.swift
- [x] T045 [US3] Add Self-Timer submenu (3s, 5s, 10s) to MenuBarView in ScreenPro/Features/MenuBar/MenuBarView.swift
- [x] T046 [US3] Add audio cues (Tink for countdown, Pop for capture) in SelfTimerController

**Checkpoint**: Self-timer fully functional - can test independently

---

## Phase 6: User Story 4 - Screen Freeze (Priority: P2)

**Goal**: Users can freeze the screen display to capture dynamic content precisely

**Independent Test**: Play a video, freeze screen, verify frozen frame is captured accurately

### Models for User Story 4

- [x] T047 [P] [US4] Create FreezeState struct in ScreenPro/Features/CaptureEnhancements/Models/FreezeState.swift

### Implementation for User Story 4

- [x] T048 [US4] Implement ScreenFreezeController with display capture and overlay window in ScreenPro/Features/CaptureEnhancements/ScreenFreezeController.swift
- [x] T049 [US4] Add toggleScreenFreeze() method to AppCoordinator in ScreenPro/Core/AppCoordinator.swift
- [x] T050 [US4] Add Screen Freeze menu item to MenuBarView in ScreenPro/Features/MenuBar/MenuBarView.swift
- [x] T051 [US4] Integrate freeze mode with existing SelectionOverlay in ScreenPro/Features/Capture/SelectionOverlay/SelectionOverlayView.swift
- [x] T052 [US4] Add multi-monitor support (freeze only triggering display) to ScreenFreezeController

**Checkpoint**: Screen freeze fully functional - can test independently

---

## Phase 7: User Story 5 - Magnifier Tool (Priority: P2)

**Goal**: Users get pixel-level precision with 8x magnifier during area selection

**Independent Test**: Initiate area capture, verify magnified view appears near cursor showing individual pixels

### Tests for User Story 5

- [ ] T053 [P] [US5] Unit test for magnifier positioning logic in ScreenProTests/Unit/MagnifierTests.swift

### Models for User Story 5

- [x] T054 [P] [US5] Create MagnifierState struct in ScreenPro/Features/CaptureEnhancements/Models/MagnifierState.swift

### Implementation for User Story 5

- [x] T055 [US5] Implement MagnifierView with 8x zoom and coordinate display in ScreenPro/Features/CaptureEnhancements/MagnifierView.swift
- [x] T056 [US5] Add magnifier positioning logic (stay in screen bounds, flip near edges) to MagnifierView
- [x] T057 [US5] Integrate MagnifierView with SelectionOverlayView in ScreenPro/Features/Capture/SelectionOverlay/SelectionOverlayView.swift
- [x] T058 [US5] Add magnifier toggle based on settings in SelectionOverlayView

**Checkpoint**: Magnifier fully functional - can test independently

---

## Phase 8: User Story 6 - Background Tool (Priority: P3)

**Goal**: Users can add stylish backgrounds to screenshots for social media sharing

**Independent Test**: Open background tool, apply gradient background, set Twitter aspect ratio, export at 2x resolution

### Tests for User Story 6

- [ ] T059 [P] [US6] Integration test for background tool in ScreenProTests/Integration/BackgroundToolTests.swift

### Models for User Story 6

- [x] T060 [P] [US6] Create BackgroundStyle enum in ScreenPro/Features/Background/Models/BackgroundStyle.swift
- [x] T061 [P] [US6] Create AspectRatioPreset enum in ScreenPro/Features/Background/Models/AspectRatioPreset.swift
- [x] T062 [P] [US6] Create BackgroundConfig struct in ScreenPro/Features/Background/Models/BackgroundConfig.swift

### Implementation for User Story 6

- [x] T063 [US6] Implement BackgroundToolView with live preview in ScreenPro/Features/Background/BackgroundToolView.swift
- [x] T064 [US6] Add background style picker (solid, gradient, mesh) to BackgroundToolView
- [x] T065 [US6] Add aspect ratio presets (Twitter, Instagram, 16:9, 1:1, etc.) to BackgroundToolView
- [x] T066 [US6] Add padding, corner radius, shadow controls to BackgroundToolView
- [x] T067 [US6] Implement export at 2x resolution using Core Graphics in BackgroundToolView
- [x] T068 [US6] Add openBackgroundTool(for:) method to AppCoordinator in ScreenPro/Core/AppCoordinator.swift
- [x] T069 [US6] Add beautifyAction() to QuickAccessContentView to open background tool in ScreenPro/Features/QuickAccess/QuickAccessContentView.swift

**Checkpoint**: Background tool fully functional - can test independently

---

## Phase 9: User Story 7 - Camera Overlay (Priority: P3)

**Goal**: Users can include webcam feed as PiP overlay during screen recordings

**Independent Test**: Start recording with camera overlay enabled, verify webcam appears in corner, export shows composited video

### Models for User Story 7

- [x] T070 [P] [US7] Create OverlayPosition enum in ScreenPro/Features/Recording/CameraOverlay/Models/OverlayPosition.swift
- [x] T071 [P] [US7] Create OverlayShape enum in ScreenPro/Features/Recording/CameraOverlay/Models/OverlayShape.swift
- [x] T072 [P] [US7] Create OverlayConfig struct in ScreenPro/Features/Recording/CameraOverlay/Models/OverlayConfig.swift
- [x] T073 [P] [US7] Create CameraState struct in ScreenPro/Features/Recording/CameraOverlay/Models/CameraState.swift

### Implementation for User Story 7

- [x] T074 [US7] Implement CameraOverlayController with AVCaptureSession in ScreenPro/Features/Recording/CameraOverlay/CameraOverlayController.swift
- [x] T075 [US7] Create CameraOverlayView with draggable/resizable preview in ScreenPro/Features/Recording/CameraOverlay/CameraOverlayView.swift
- [x] T076 [US7] Add camera overlay toggle to RecordingControlsView in ScreenPro/Features/Recording/RecordingControlsView.swift
- [x] T077 [US7] Integrate camera overlay with RecordingService in ScreenPro/Features/Recording/RecordingService.swift
- [x] T078 [US7] Implement video compositing (overlay camera onto screen recording) during export in RecordingService
- [x] T079 [US7] Add camera permission request in PermissionManager in ScreenPro/Core/Services/PermissionManager.swift
- [x] T080 [US7] Add toggleCameraOverlay() method to AppCoordinator in ScreenPro/Core/AppCoordinator.swift

**Checkpoint**: Camera overlay fully functional - can test independently

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T081 [P] Add keyboard shortcuts for all new capture modes in ShortcutManager in ScreenPro/Core/Services/ShortcutManager.swift
- [x] T082 [P] Add accessible labels to all new UI controls for VoiceOver support
- [x] T083 [P] Add Reduce Motion support to countdown animations in CountdownView
- [ ] T084 Verify all features work with multi-monitor configurations
- [ ] T085 Performance optimization: ensure magnifier updates at 60fps
- [ ] T086 Performance optimization: ensure screen freeze activates within 200ms
- [ ] T087 Performance optimization: ensure OCR completes within 2 seconds
- [ ] T088 Memory optimization: verify scrolling capture stays under 300MB for 50 frames
- [ ] T089 Run quickstart.md validation for all features

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-9)**: All depend on Foundational phase completion
  - US1 (Scrolling Capture) and US2 (OCR) are both P1 - can run in parallel
  - US3, US4, US5 are P2 - can run in parallel after foundation
  - US6, US7 are P3 - can run in parallel after foundation
- **Polish (Phase 10)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (Scrolling Capture)**: Independent after foundation
- **User Story 2 (OCR)**: Independent after foundation
- **User Story 3 (Self-Timer)**: Independent after foundation
- **User Story 4 (Screen Freeze)**: Independent after foundation; shares SelectionOverlay integration
- **User Story 5 (Magnifier)**: Independent after foundation; shares SelectionOverlay integration
- **User Story 6 (Background Tool)**: Independent after foundation; extends QuickAccess
- **User Story 7 (Camera Overlay)**: Independent after foundation; extends RecordingService

### Within Each User Story

1. Models first (marked [P] - can run in parallel)
2. Core service implementation
3. UI/View implementation
4. AppCoordinator integration
5. Menu/QuickAccess integration
6. Tests can run after implementation

### Parallel Opportunities

**Phase 1 (Setup)**: T002-T006 all parallelizable (different directories)

**Phase 2 (Foundational)**: T008-T016 all parallelizable (different settings/error types)

**User Stories**: After foundation completes:
- All 7 user stories can run in parallel if team capacity allows
- Within each story, model tasks marked [P] can run in parallel

---

## Parallel Example: User Story 1 (Scrolling Capture)

```bash
# Launch all models together:
Task: "Create ScrollDirection enum in ScreenPro/Features/ScrollingCapture/Models/ScrollDirection.swift"
Task: "Create CapturedFrame struct in ScreenPro/Features/ScrollingCapture/Models/CapturedFrame.swift"
Task: "Create StitchConfig struct in ScreenPro/Features/ScrollingCapture/Models/StitchConfig.swift"

# Then sequentially: ImageStitcher → ScrollingCaptureService → ScrollingPreviewView → Integration
```

## Parallel Example: Foundation Settings

```bash
# Launch all settings tasks together:
Task: "Add OCR settings to SettingsManager"
Task: "Add self-timer settings to SettingsManager"
Task: "Add magnifier settings to SettingsManager"
Task: "Add background tool settings to SettingsManager"
Task: "Add camera overlay settings to SettingsManager"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL)
3. Complete Phase 3: Scrolling Capture (US1)
4. Complete Phase 4: OCR (US2)
5. **STOP and VALIDATE**: Both P1 stories functional
6. Deploy/demo MVP

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 (Scrolling) → Test → Demo
3. Add US2 (OCR) → Test → Demo (MVP Complete!)
4. Add US3 (Self-Timer) → Test → Demo
5. Add US4 (Screen Freeze) → Test → Demo
6. Add US5 (Magnifier) → Test → Demo
7. Add US6 (Background Tool) → Test → Demo
8. Add US7 (Camera Overlay) → Test → Demo
9. Polish → Final Release

### Parallel Team Strategy

With 3+ developers after foundation:
- Developer A: US1 (Scrolling) + US4 (Screen Freeze)
- Developer B: US2 (OCR) + US5 (Magnifier)
- Developer C: US3 (Self-Timer) + US6 (Background) + US7 (Camera)

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Tests included per constitution (Testing Discipline - happy path)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
