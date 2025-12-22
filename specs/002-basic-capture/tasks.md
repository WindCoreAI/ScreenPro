# Tasks: Basic Screenshot Capture

**Input**: Design documents from `/specs/002-basic-capture/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Integration and unit tests are specified per Constitution (Testing Discipline principle).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Based on plan.md structure:
- Source: `ScreenPro/` at repository root
- Features: `ScreenPro/Features/Capture/`
- Tests: `ScreenProTests/`

---

## Phase 1: Setup

**Purpose**: Project structure and feature directory initialization

- [x] T001 Create Capture feature directory structure at ScreenPro/Features/Capture/
- [x] T002 [P] Create SelectionOverlay subdirectory at ScreenPro/Features/Capture/SelectionOverlay/
- [x] T003 [P] Create WindowPicker subdirectory at ScreenPro/Features/Capture/WindowPicker/
- [x] T004 [P] Create test directories at ScreenProTests/Integration/ and ScreenProTests/Unit/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core types and infrastructure that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 Create CaptureMode enum and CaptureConfig struct in ScreenPro/Features/Capture/CaptureTypes.swift
- [x] T006 [P] Create CaptureResult struct in ScreenPro/Features/Capture/CaptureResult.swift
- [x] T007 [P] Create CaptureError enum in ScreenPro/Features/Capture/CaptureError.swift
- [x] T008 Create DisplayInfo struct and DisplayManager class in ScreenPro/Features/Capture/MultiMonitorSupport.swift
- [x] T009 Create CaptureServiceProtocol and stub CaptureService class in ScreenPro/Features/Capture/CaptureService.swift
- [x] T010 Implement content discovery (refreshAvailableContent) in CaptureService using SCShareableContent
- [x] T011 Implement stream configuration helper (createStreamConfiguration) in CaptureService with Retina support
- [x] T012 Implement image cropping helper (cropImage) in CaptureService with Y-axis coordinate flip
- [x] T013 Implement save and copyToClipboard methods in CaptureService using StorageService
- [x] T014 [P] Create CaptureServiceTests stub in ScreenProTests/Unit/CaptureServiceTests.swift

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Area Screenshot Capture (Priority: P1) 🎯 MVP

**Goal**: Capture user-selected rectangular region with crosshair, dimensions, and corner handles

**Independent Test**: Trigger area capture, select region, verify captured image matches selection dimensions

### Implementation for User Story 1

- [x] T015 [P] [US1] Create SelectionWindow NSWindow subclass in ScreenPro/Features/Capture/SelectionOverlay/SelectionWindow.swift
- [x] T016 [P] [US1] Create CrosshairView SwiftUI component in ScreenPro/Features/Capture/SelectionOverlay/CrosshairView.swift
- [x] T017 [P] [US1] Create DimensionsView SwiftUI component in ScreenPro/Features/Capture/SelectionOverlay/DimensionsView.swift
- [x] T018 [P] [US1] Create InstructionsView SwiftUI component in ScreenPro/Features/Capture/SelectionOverlay/InstructionsView.swift
- [x] T019 [US1] Create SelectionOverlayView SwiftUI view combining crosshair, dimensions, selection rect, and instructions in ScreenPro/Features/Capture/SelectionOverlay/SelectionOverlayView.swift
- [x] T020 [US1] Implement drag gesture handling with startPoint/currentPoint tracking in SelectionOverlayView
- [x] T021 [US1] Implement selection rectangle rendering with border and corner handles in SelectionOverlayView
- [x] T022 [US1] Implement screen-to-view coordinate conversion in SelectionOverlayView
- [x] T023 [US1] Add Escape key handling for cancellation in SelectionWindow
- [x] T024 [US1] Add minimum selection validation (5x5 pixels) in SelectionOverlayView
- [x] T025 [US1] Implement captureArea method in CaptureService using SCScreenshotManager
- [x] T026 [US1] Implement beginAreaSelection flow in AppCoordinator creating SelectionWindow per screen
- [x] T027 [US1] Implement handleAreaSelected completion in AppCoordinator triggering capture and cleanup
- [x] T028 [US1] Update MenuBarView to connect area capture action to AppCoordinator.captureArea()
- [x] T029 [US1] Integration test for area capture workflow in ScreenProTests/Integration/CaptureIntegrationTests.swift

**Checkpoint**: Area capture fully functional - can select region and capture to file/clipboard

---

## Phase 4: User Story 2 - Window Screenshot Capture (Priority: P1)

**Goal**: Capture specific application window with hover highlight and click selection

**Independent Test**: Trigger window capture, hover over window, click to capture, verify window image captured

### Implementation for User Story 2

- [x] T030 [P] [US2] Create WindowHighlightView overlay window in ScreenPro/Features/Capture/WindowPicker/WindowHighlightView.swift
- [x] T031 [P] [US2] Create WindowPickerOverlay NSWindow for mouse tracking in ScreenPro/Features/Capture/WindowPicker/WindowPickerOverlay.swift
- [x] T032 [US2] Create WindowPickerController managing highlight and selection in ScreenPro/Features/Capture/WindowPicker/WindowPickerController.swift
- [x] T033 [US2] Implement window filtering (exclude self, system windows, <50x50) in CaptureService.refreshAvailableContent
- [x] T034 [US2] Implement pickWindow async method in WindowPickerController with continuation
- [x] T035 [US2] Implement window highlighting on mouse hover in WindowPickerController
- [x] T036 [US2] Add Escape key handling for cancellation in WindowPickerOverlay
- [x] T037 [US2] Implement captureWindow method in CaptureService using desktopIndependentWindow filter
- [x] T038 [US2] Implement beginWindowSelection flow in AppCoordinator using WindowPickerController
- [x] T039 [US2] Update MenuBarView to connect window capture action to AppCoordinator.captureWindow()
- [x] T040 [US2] Integration test for window capture workflow in ScreenProTests/Integration/CaptureIntegrationTests.swift

**Checkpoint**: Window capture fully functional - can select and capture any application window

---

## Phase 5: User Story 3 - Fullscreen Screenshot Capture (Priority: P1)

**Goal**: Capture entire display with single action (no selection UI)

**Independent Test**: Trigger fullscreen capture, verify captured image matches display resolution

### Implementation for User Story 3

- [x] T041 [US3] Implement captureDisplay method in CaptureService using display filter with SCScreenshotManager
- [x] T042 [US3] Implement performFullscreenCapture flow in AppCoordinator calling captureDisplay
- [x] T043 [US3] Update MenuBarView to connect fullscreen capture action to AppCoordinator.captureFullscreen()
- [x] T044 [US3] Unit test for captureDisplay with mock SCDisplay in ScreenProTests/Unit/CaptureServiceTests.swift

**Checkpoint**: Fullscreen capture fully functional - instant capture of entire display

---

## Phase 6: User Story 4 - Capture Audio Feedback (Priority: P2)

**Goal**: Play macOS "Grab" sound on successful capture (configurable)

**Independent Test**: Enable sound in settings, capture screenshot, verify sound plays

### Implementation for User Story 4

- [x] T045 [US4] Implement playCaptureSound helper method in CaptureService using NSSound(named: "Grab")
- [x] T046 [US4] Add playCaptureSound call after successful capture in captureArea, captureWindow, captureDisplay
- [x] T047 [US4] Verify settings integration with settingsManager.settings.playCaptureSound

**Checkpoint**: Audio feedback works with all capture modes when enabled

---

## Phase 7: User Story 5 - Multi-Monitor Support (Priority: P2)

**Goal**: Proper capture behavior across multiple connected displays

**Independent Test**: On multi-monitor setup, capture from each display and verify correct output

### Implementation for User Story 5

- [x] T048 [US5] Implement display(containing:) method in DisplayManager for cursor-based display detection
- [x] T049 [US5] Implement display(for:) method in DisplayManager for rect intersection matching
- [x] T050 [US5] Update beginAreaSelection to create SelectionWindow for each NSScreen
- [x] T051 [US5] Update captureDisplay to use displayContaining(cursor) when display is nil
- [x] T052 [US5] Update window filtering to include windows from all displays
- [x] T053 [US5] Unit test for DisplayManager coordinate calculations in ScreenProTests/Unit/CaptureServiceTests.swift

**Checkpoint**: All capture modes work correctly on multi-monitor setups

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Error handling, notifications, cleanup

- [x] T054 Implement handleCaptureError in AppCoordinator with user notification
- [x] T055 Implement handleCaptureResult in AppCoordinator with save + clipboard + notification
- [x] T056 Add showNotification helper in AppCoordinator for capture feedback
- [x] T057 [P] Add accessibility labels to all UI components (VoiceOver support)
- [x] T058 [P] Add focus indicators to selection overlay interactive elements
- [x] T059 Remove placeholder implementations from AppCoordinator capture methods
- [x] T060 Run quickstart.md validation - verify all features work as documented

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase completion
  - US1, US2, US3 are all P1 priority but can proceed in sequence
  - US4, US5 are P2 priority and depend on at least one capture mode working
- **Polish (Phase 8)**: Depends on at least US1, US2, US3 being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational - Independent from US1
- **User Story 3 (P1)**: Can start after Foundational - Independent from US1/US2
- **User Story 4 (P2)**: Depends on at least one capture method existing (US1, US2, or US3)
- **User Story 5 (P2)**: Depends on DisplayManager from Foundational and capture methods from US1-3

### Within Each User Story

- UI components marked [P] can be built in parallel
- Integration tasks depend on component completion
- AppCoordinator integration depends on CaptureService methods
- Tests depend on implementation completion

### Parallel Opportunities

- T002, T003, T004 can run in parallel (directory creation)
- T006, T007, T014 can run in parallel (independent types/tests)
- T015, T016, T017, T018 can run in parallel (independent UI components)
- T030, T031 can run in parallel (window picker components)

---

## Parallel Example: User Story 1 UI Components

```bash
# Launch all UI components for User Story 1 together:
Task: "Create SelectionWindow NSWindow subclass in ScreenPro/Features/Capture/SelectionOverlay/SelectionWindow.swift"
Task: "Create CrosshairView SwiftUI component in ScreenPro/Features/Capture/SelectionOverlay/CrosshairView.swift"
Task: "Create DimensionsView SwiftUI component in ScreenPro/Features/Capture/SelectionOverlay/DimensionsView.swift"
Task: "Create InstructionsView SwiftUI component in ScreenPro/Features/Capture/SelectionOverlay/InstructionsView.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1-3: All Capture Modes)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (Area Capture)
4. **STOP and VALIDATE**: Test area capture independently
5. Complete Phase 4: User Story 2 (Window Capture)
6. Complete Phase 5: User Story 3 (Fullscreen Capture)
7. **DEMO**: All three P1 capture modes working

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Basic MVP (area capture works!)
3. Add User Story 2 → Test independently → Enhanced MVP (window capture)
4. Add User Story 3 → Test independently → Complete MVP (fullscreen)
5. Add User Story 4 → Audio feedback polish
6. Add User Story 5 → Multi-monitor support
7. Complete Polish → Production ready

### Suggested MVP Scope

**Minimum**: Phase 1 + Phase 2 + Phase 3 (Area Capture only)
- This delivers one fully working capture mode
- Can be tested and demonstrated end-to-end

**Recommended MVP**: Phase 1-5 (All three capture modes)
- Matches the Milestone 2 deliverables
- Provides complete core capture functionality

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Test on actual hardware for screen recording permission flow
- Multi-monitor testing requires physical multi-monitor setup
