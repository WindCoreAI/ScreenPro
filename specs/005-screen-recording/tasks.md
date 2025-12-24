# Tasks: Screen Recording

**Input**: Design documents from `/specs/005-screen-recording/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests are included based on the Testing Discipline principle in the constitution and quickstart.md testing checklist.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **macOS app**: `ScreenPro/` at repository root
- Feature modules in `ScreenPro/Features/Recording/`
- Core services in `ScreenPro/Core/Services/`
- Tests in `ScreenProTests/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create Recording feature module structure and shared models

- [x] T001 Create Recording feature directory structure: `ScreenPro/Features/Recording/` and `ScreenPro/Features/Recording/Models/`
- [x] T002 [P] Create RecordingState enum in `ScreenPro/Features/Recording/Models/RecordingState.swift`
- [x] T003 [P] Create RecordingRegion enum in `ScreenPro/Features/Recording/Models/RecordingRegion.swift`
- [x] T004 [P] Create VideoConfig struct with Resolution and Quality enums in `ScreenPro/Features/Recording/Models/VideoConfig.swift`
- [x] T005 [P] Create GIFConfig struct in `ScreenPro/Features/Recording/Models/GIFConfig.swift`
- [x] T006 [P] Create RecordingFormat enum in `ScreenPro/Features/Recording/Models/RecordingFormat.swift`
- [x] T007 [P] Create RecordingResult struct in `ScreenPro/Features/Recording/Models/RecordingResult.swift`
- [x] T008 [P] Create RecordingError enum with LocalizedError conformance in `ScreenPro/Features/Recording/Models/RecordingError.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T009 Create RecordingService skeleton implementing RecordingServiceProtocol in `ScreenPro/Features/Recording/RecordingService.swift`
- [x] T010 Implement SCStreamConfiguration helper method in RecordingService for stream setup
- [x] T011 Implement SCContentFilter creation method in RecordingService for display/window/area regions
- [x] T012 Add `.recording` case to AppCoordinator.State enum and add recordingService property in `ScreenPro/Core/AppCoordinator.swift`
- [x] T013 Add recording menu items to MenuBarView (Record Fullscreen, Record Window, Record Area) in `ScreenPro/Features/MenuBar/MenuBarView.swift`

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Record Screen to Video (Priority: P1) 🎯 MVP

**Goal**: Enable users to record their screen as a video file (MP4/H.264) with display, window, or area selection

**Independent Test**: Start recording fullscreen, perform actions, stop recording, verify MP4 file is created and plays back correctly

### Tests for User Story 1

- [x] T014 [P] [US1] Unit test for VideoConfig validation (frame rates, resolutions) in `ScreenProTests/Unit/VideoConfigTests.swift`
- [x] T015 [P] [US1] Integration test for start/stop recording workflow in `ScreenProTests/Integration/RecordingServiceTests.swift`

### Implementation for User Story 1

- [x] T016 [US1] Implement AVAssetWriter setup with H.264 encoding in RecordingService `ScreenPro/Features/Recording/RecordingService.swift`
- [x] T017 [US1] Implement AVAssetWriterInputPixelBufferAdaptor for efficient frame writing in RecordingService
- [x] T018 [US1] Implement SCStreamDelegate and SCStreamOutput protocols in RecordingService for frame capture
- [x] T019 [US1] Implement startRecording(region:format:) async method with video format handling
- [x] T020 [US1] Implement stopRecording() async method with AVAssetWriter finalization
- [x] T021 [US1] Implement handleVideoSample(_:) method for writing video frames to asset writer
- [x] T022 [US1] Implement bitrate calculation based on resolution and quality settings per research.md guidelines
- [x] T023 [US1] Add region selection reuse from existing CaptureService for area/window selection
- [x] T024 [US1] Wire up AppCoordinator.startRecording() to call RecordingService
- [x] T025 [US1] Add error handling for permission denied, disk space, and encoding failures

**Checkpoint**: User Story 1 complete - basic video recording works independently

---

## Phase 4: User Story 4 - Control Recording in Progress (Priority: P1) 🎯 MVP

**Goal**: Provide recording controls UI with timer, pause/resume, stop, and cancel functionality

**Independent Test**: Start recording, verify timer updates, pause and confirm timer stops, resume and confirm timer continues, stop successfully

### Tests for User Story 4

- [x] T026 [P] [US4] Unit test for RecordingState transitions in `ScreenProTests/Unit/RecordingStateTests.swift`
- [x] T027 [P] [US4] Unit test for duration timer formatting (MM:SS.T) in `ScreenProTests/Unit/RecordingControlsTests.swift`

### Implementation for User Story 4

- [x] T028 [P] [US4] Create RecordingControlsView SwiftUI component with timer, pause/resume, stop buttons in `ScreenPro/Features/Recording/RecordingControlsView.swift`
- [x] T029 [US4] Create RecordingControlsWindow NSWindow subclass with floating level in `ScreenPro/Features/Recording/RecordingControlsWindow.swift`
- [x] T030 [US4] Implement pulsing red dot animation for recording indicator in RecordingControlsView
- [x] T031 [US4] Implement duration timer with 100ms update interval in RecordingService
- [x] T032 [US4] Implement pauseRecording() method with SCStream pause and timestamp tracking
- [x] T033 [US4] Implement resumeRecording() method with pause offset adjustment for seamless video
- [x] T034 [US4] Implement cancelRecording() method with partial file cleanup
- [x] T035 [US4] Make RecordingControlsWindow draggable via isMovableByWindowBackground
- [x] T036 [US4] Add accessibility labels to all recording control buttons
- [x] T037 [US4] Show/hide RecordingControlsWindow from AppCoordinator when recording starts/stops

**Checkpoint**: User Stories 1 AND 4 complete - users can record video with full controls

---

## Phase 5: User Story 2 - Record Screen to GIF (Priority: P2)

**Goal**: Enable users to create animated GIF recordings for easy sharing

**Independent Test**: Start GIF recording, perform brief actions, stop, verify animated GIF loops correctly

### Tests for User Story 2

- [x] T038 [P] [US2] Unit test for GIFConfig validation (frame rate, scale, loop count) in `ScreenProTests/Unit/GIFConfigTests.swift`
- [x] T039 [P] [US2] Unit test for GIFEncoder.reduceFrames logic in `ScreenProTests/Unit/GIFEncoderTests.swift`
- [x] T040 [P] [US2] Integration test for GIF recording workflow in `ScreenProTests/Integration/GIFRecordingTests.swift`

### Implementation for User Story 2

- [x] T041 [US2] Create GIFEncoder with CGImageDestination encoding in `ScreenPro/Features/Recording/GIFEncoder.swift`
- [x] T042 [US2] Implement encode(frames:frameDelay:loopCount:to:) static method with ImageIO
- [x] T043 [US2] Implement reduceFrames(_:targetFPS:sourceFPS:) for frame rate reduction
- [x] T044 [US2] Add GIF frame collection array to RecordingService for gif mode
- [x] T045 [US2] Implement handleGIFSample(_:) method for collecting CGImage frames during recording
- [x] T046 [US2] Implement finalizeGIF(config:) async method to encode collected frames
- [x] T047 [US2] Add GIF mode toggle to recording menu in MenuBarView
- [x] T048 [US2] Add memory warning for long GIF recordings (>30 seconds)

**Checkpoint**: User Story 2 complete - GIF recording works independently

---

## Phase 6: User Story 3 - Capture Audio with Recording (Priority: P2)

**Goal**: Enable microphone and system audio capture synchronized with video

**Independent Test**: Enable microphone, record while speaking, verify audio is present and synchronized in playback

### Tests for User Story 3

- [x] T049 [P] [US3] Integration test for audio sync verification in `ScreenProTests/Integration/AudioRecordingTests.swift`

### Implementation for User Story 3

- [x] T050 [US3] Enable SCStreamConfiguration.capturesAudio for system audio capture in RecordingService
- [x] T051 [US3] Add AVAssetWriterInput for audio track with AAC encoding settings
- [x] T052 [US3] Implement handleAudioSample(_:) method for writing audio to asset writer
- [x] T053 [US3] Add AVAudioEngine setup for microphone capture in RecordingService
- [x] T054 [US3] Implement microphone tap installation on audioEngine.inputNode
- [x] T055 [US3] Create AVAudioPCMBuffer to CMSampleBuffer conversion helper in `ScreenPro/Core/Extensions/AVAudioPCMBuffer+CMSampleBuffer.swift`
- [x] T056 [US3] Implement handleMicrophoneBuffer(_:time:) method for mic audio processing
- [x] T057 [US3] Add microphone permission check using existing PermissionManager before enabling mic
- [x] T058 [US3] Add audio options toggles to recording menu (System Audio, Microphone)

**Checkpoint**: User Story 3 complete - audio recording works independently

---

## Phase 7: User Story 7 - Configure Recording Quality (Priority: P2)

**Goal**: Allow users to select resolution, quality level, and frame rate for recordings

**Independent Test**: Configure different resolution/quality settings, record, verify output matches expected resolution and file size

### Implementation for User Story 7

- [x] T059 [US7] Add recording quality settings UI to RecordingSettingsTab in `ScreenPro/Features/Settings/RecordingSettingsTab.swift`
- [x] T060 [US7] Add resolution picker (480p, 720p, 1080p, 4K) to RecordingSettingsTab
- [x] T061 [US7] Add quality picker (Low, Medium, High, Maximum) to RecordingSettingsTab
- [x] T062 [US7] Add frame rate picker (15, 24, 30, 60 fps) to RecordingSettingsTab
- [x] T063 [US7] Create VideoConfig from Settings in RecordingService before starting recording
- [x] T064 [US7] Apply resolution/quality/fps settings to AVAssetWriter configuration

**Checkpoint**: User Story 7 complete - quality configuration works independently

---

## Phase 8: User Story 5 - Visualize Mouse Clicks (Priority: P3)

**Goal**: Show visual indicators at click positions during recording for tutorial creation

**Independent Test**: Enable click visualization, record while clicking, verify expanding rings appear at click locations in output

### Tests for User Story 5

- [x] T065 [P] [US5] Unit test for ClickEffect model in `ScreenProTests/Unit/ClickEffectTests.swift`

### Implementation for User Story 5

- [x] T066 [P] [US5] Create ClickEffect struct in `ScreenPro/Features/Recording/Models/ClickEffect.swift`
- [x] T067 [US5] Create ClickOverlayController with NSWindow at .screenSaver level in `ScreenPro/Features/Recording/ClickOverlayController.swift`
- [x] T068 [US5] Implement global mouse event monitoring for left/right clicks
- [x] T069 [US5] Create ClickOverlayView SwiftUI component with expanding ring animation
- [x] T070 [US5] Implement ClickRipple view with scale and opacity animation over 500ms
- [x] T071 [US5] Add color differentiation: blue for left click, green for right click
- [x] T072 [US5] Wire ClickOverlayController start/stop to RecordingService when showClicks enabled
- [x] T073 [US5] Add click visualization toggle to recording settings

**Checkpoint**: User Story 5 complete - click visualization works independently

---

## Phase 9: User Story 6 - Display Keystrokes (Priority: P4)

**Goal**: Show keyboard shortcuts and key presses during recording for tutorials

**Independent Test**: Enable keystroke overlay, record while pressing keys, verify keystrokes appear with proper modifier symbols

### Tests for User Story 6

- [x] T074 [P] [US6] Unit test for KeyPress.displayString formatting in `ScreenProTests/Unit/KeyPressTests.swift`

### Implementation for User Story 6

- [x] T075 [P] [US6] Create KeyPress struct in `ScreenPro/Features/Recording/Models/KeyPress.swift`
- [x] T076 [US6] Create KeystrokeOverlayController with NSWindow at .screenSaver level in `ScreenPro/Features/Recording/KeystrokeOverlayController.swift`
- [x] T077 [US6] Implement global keyboard event monitoring for keyDown events
- [x] T078 [US6] Create KeystrokeOverlayView SwiftUI component showing recent keys
- [x] T079 [US6] Implement modifier symbol formatting: ⌘⇧⌥⌃
- [x] T080 [US6] Implement key queue showing last 5 keystrokes with fade out after 2 seconds
- [x] T081 [US6] Wire KeystrokeOverlayController start/stop to RecordingService when showKeystrokes enabled
- [x] T082 [US6] Add keystroke visualization toggle to recording settings

**Checkpoint**: User Story 6 complete - keystroke overlay works independently

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T083 [P] Add cursor visibility toggle (show/hide cursor in recordings) to settings and RecordingService
- [x] T084 [P] Implement disk space check before starting recording
- [x] T085 [P] Handle window closure mid-recording gracefully (save captured content)
- [x] T086 [P] Add recording shortcut to ShortcutManager (e.g., Cmd+Shift+5)
- [x] T087 Integrate RecordingResult with QuickAccessOverlay for post-recording actions
- [x] T088 Add recording to capture history in StorageService
- [ ] T089 [P] Performance profiling: verify no frame drops at 30fps 1080p (requires manual Instruments profiling)
- [ ] T090 [P] Memory profiling: verify stable memory for 30-minute recording (requires manual Instruments profiling)
- [ ] T091 Run quickstart.md manual test checklist validation (requires manual testing)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - US1 & US4 (P1): Can proceed in parallel after Foundational
  - US2, US3, US7 (P2): Can proceed after US1 or in parallel
  - US5 (P3): Can proceed after US1 or in parallel
  - US6 (P4): Can proceed after US1 or in parallel
- **Polish (Phase 10)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Foundation only - No dependencies on other stories
- **User Story 4 (P1)**: Foundation only - Builds on US1's RecordingService but independently testable
- **User Story 2 (P2)**: Foundation only - Uses RecordingService differently (GIF mode)
- **User Story 3 (P2)**: Foundation only - Adds audio to video recording
- **User Story 7 (P2)**: Foundation only - Configures parameters used by US1
- **User Story 5 (P3)**: Foundation only - Overlay controller independent of recording format
- **User Story 6 (P4)**: Foundation only - Overlay controller independent of recording format

### Within Each User Story

- Tests (if included) SHOULD be written first to understand acceptance criteria
- Models before services
- Services before UI
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks T002-T008 can run in parallel (different model files)
- US1 tests T014-T015 can run in parallel
- US4 test T026-T027 can run in parallel
- US4 task T028 can run in parallel with T029
- US2 tests T038-T040 can run in parallel
- US5 tasks T065-T066 can run in parallel
- US6 tasks T074-T075 can run in parallel
- Polish tasks T083-T086 and T089-T090 can run in parallel

---

## Parallel Example: User Story 1 Setup

```bash
# Launch all model tasks for User Story 1 together:
Task: "Create RecordingState enum in ScreenPro/Features/Recording/Models/RecordingState.swift"
Task: "Create RecordingRegion enum in ScreenPro/Features/Recording/Models/RecordingRegion.swift"
Task: "Create VideoConfig struct in ScreenPro/Features/Recording/Models/VideoConfig.swift"
Task: "Create RecordingFormat enum in ScreenPro/Features/Recording/Models/RecordingFormat.swift"
Task: "Create RecordingResult struct in ScreenPro/Features/Recording/Models/RecordingResult.swift"
Task: "Create RecordingError enum in ScreenPro/Features/Recording/Models/RecordingError.swift"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 4 Only)

1. Complete Phase 1: Setup - Create models
2. Complete Phase 2: Foundational - RecordingService skeleton + AppCoordinator integration
3. Complete Phase 3: User Story 1 - Basic video recording
4. Complete Phase 4: User Story 4 - Recording controls
5. **STOP and VALIDATE**: Test video recording with controls independently
6. Deploy/demo if ready - This is the MVP!

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add US1 + US4 → Test independently → **MVP Ready!**
3. Add US2 (GIF) → Test independently → Demo GIF capability
4. Add US3 (Audio) → Test independently → Demo audio recording
5. Add US7 (Quality) → Test independently → Demo quality settings
6. Add US5 (Clicks) → Test independently → Demo click visualization
7. Add US6 (Keystrokes) → Test independently → Demo keystroke overlay
8. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers after Foundational phase:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (Video) + User Story 4 (Controls) → MVP
   - Developer B: User Story 2 (GIF)
   - Developer C: User Story 5 (Clicks) + User Story 6 (Keystrokes)
3. Stories complete and integrate independently

---

## Summary

| Phase | Tasks | Stories Covered |
|-------|-------|-----------------|
| Phase 1: Setup | T001-T008 (8 tasks) | Shared models |
| Phase 2: Foundational | T009-T013 (5 tasks) | Core infrastructure |
| Phase 3: US1 Video | T014-T025 (12 tasks) | P1 - Video Recording |
| Phase 4: US4 Controls | T026-T037 (12 tasks) | P1 - Recording Controls |
| Phase 5: US2 GIF | T038-T048 (11 tasks) | P2 - GIF Recording |
| Phase 6: US3 Audio | T049-T058 (10 tasks) | P2 - Audio Capture |
| Phase 7: US7 Quality | T059-T064 (6 tasks) | P2 - Quality Config |
| Phase 8: US5 Clicks | T065-T073 (9 tasks) | P3 - Click Visualization |
| Phase 9: US6 Keystrokes | T074-T082 (9 tasks) | P4 - Keystroke Overlay |
| Phase 10: Polish | T083-T091 (9 tasks) | Cross-cutting |
| **Total** | **91 tasks** | **7 user stories** |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- MVP scope: User Story 1 + User Story 4 (video recording with controls)
