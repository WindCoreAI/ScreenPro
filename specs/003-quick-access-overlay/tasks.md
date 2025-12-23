# Tasks: Quick Access Overlay

**Input**: Design documents from `/specs/003-quick-access-overlay/`
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/QuickAccessProtocols.swift, quickstart.md

**Tests**: Integration tests for happy path are included per constitution requirement (Testing Discipline).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **macOS app**: `ScreenPro/` for source, `ScreenProTests/` for tests
- Paths follow existing structure: `Features/QuickAccess/`, `Core/Extensions/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create QuickAccess feature module structure

- [x] T001 Create `ScreenPro/Features/QuickAccess/` directory structure
- [x] T002 [P] Create `ScreenPro/Core/Extensions/` directory if not exists
- [x] T003 [P] Create `ScreenProTests/QuickAccess/` test directory structure

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Data Models

- [x] T004 [P] Create CaptureItem struct in `ScreenPro/Features/QuickAccess/CaptureItem.swift` with id, result, thumbnail, createdAt, dimensions, dimensionsText, timeAgoText properties per data-model.md
- [x] T005 [P] Create CaptureQueue ObservableObject in `ScreenPro/Features/QuickAccess/CaptureQueue.swift` with items array, selectedIndex, add/remove/clear/selectNext/selectPrevious methods per data-model.md

### Window Infrastructure

- [x] T006 [P] Create VisualEffectView NSViewRepresentable in `ScreenPro/Core/Extensions/VisualEffectView.swift` wrapping NSVisualEffectView with .hudWindow material support
- [x] T007 Create QuickAccessWindow NSWindow subclass in `ScreenPro/Features/QuickAccess/QuickAccessWindow.swift` with borderless style, floating level, collectionBehavior [.canJoinAllSpaces, .stationary], per research.md
- [x] T008 Create QuickAccessWindowController in `ScreenPro/Features/QuickAccess/QuickAccessWindowController.swift` with queue property, show/hide/updatePosition methods, window lifecycle management

### Thumbnail Generation

- [x] T009 Create ThumbnailGenerator actor in `ScreenPro/Features/QuickAccess/ThumbnailGenerator.swift` with async generateThumbnail(from:maxPixelSize:scaleFactor:) using CGContext per research.md

### Unit Tests

- [x] T010 [P] Create CaptureQueueTests in `ScreenProTests/QuickAccess/CaptureQueueTests.swift` testing add, remove, clear, selection, capacity limits
- [x] T011 [P] Create CaptureItemTests in `ScreenProTests/QuickAccess/CaptureItemTests.swift` testing dimensionsText, timeAgoText computed properties

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - View Capture Preview (Priority: P1) 🎯 MVP

**Goal**: Display floating thumbnail overlay immediately after capture showing preview image with dimensions

**Independent Test**: Take any screenshot and verify a floating thumbnail appears showing the captured content within 200ms

### Implementation for User Story 1

- [x] T012 [US1] Create QuickAccessItemView SwiftUI view in `ScreenPro/Features/QuickAccess/QuickAccessItemView.swift` displaying thumbnail image, dimensions text, and timestamp
- [x] T013 [US1] Create QuickAccessContentView SwiftUI view in `ScreenPro/Features/QuickAccess/QuickAccessContentView.swift` with VisualEffectView background, VStack of QuickAccessItemView items
- [x] T014 [US1] Wire QuickAccessWindow to host QuickAccessContentView via NSHostingView in `ScreenPro/Features/QuickAccess/QuickAccessWindow.swift`
- [x] T015 [US1] Add addCapture(_ result: CaptureResult) method to QuickAccessWindowController that creates CaptureItem, generates thumbnail async, adds to queue, and shows window
- [x] T016 [US1] Add quickAccessController lazy property to AppCoordinator in `ScreenPro/Core/AppCoordinator.swift`
- [x] T017 [US1] Modify handleCaptureResult() in `ScreenPro/Core/AppCoordinator.swift` to route to quickAccessController.addCapture() when showQuickAccess setting is enabled
- [x] T018 [US1] Add VoiceOver accessibility labels to QuickAccessItemView for thumbnail, dimensions, and timestamp

**Checkpoint**: User Story 1 complete - overlay appears after capture with preview

---

## Phase 4: User Story 2 - Quick Copy to Clipboard (Priority: P1)

**Goal**: Enable one-click copy of full-resolution image to system clipboard

**Independent Test**: Capture screenshot, click Copy button, paste into any app to verify image appears

### Implementation for User Story 2

- [x] T019 [P] [US2] Add Copy button to QuickAccessItemView action buttons row in `ScreenPro/Features/QuickAccess/QuickAccessItemView.swift`
- [x] T020 [US2] Add copyToClipboard(_ item: CaptureItem) method to QuickAccessWindowController using existing CaptureService.copyToClipboard()
- [x] T021 [US2] Wire Copy button tap to controller.copyToClipboard() and remove item from queue after success
- [x] T022 [US2] Add hover state to show/hide action buttons in QuickAccessItemView using .onHover modifier
- [x] T023 [US2] Add tooltip "Copy to Clipboard (⌘C)" to Copy button

**Checkpoint**: User Story 2 complete - copy action works

---

## Phase 5: User Story 3 - Quick Save to Disk (Priority: P1)

**Goal**: Enable one-click save of capture to configured default location

**Independent Test**: Capture screenshot, click Save button, verify file appears in configured save location

### Implementation for User Story 3

- [x] T024 [P] [US3] Add Save button to QuickAccessItemView action buttons row in `ScreenPro/Features/QuickAccess/QuickAccessItemView.swift`
- [x] T025 [US3] Add saveToFile(_ item: CaptureItem) throws method to QuickAccessWindowController using existing CaptureService.save()
- [x] T026 [US3] Wire Save button tap to controller.saveToFile() and remove item from queue after success
- [x] T027 [US3] Add error handling for save failures - display alert and keep item in queue
- [x] T028 [US3] Add tooltip "Save to Disk (⌘S)" to Save button

**Checkpoint**: User Story 3 complete - save action works

---

## Phase 6: User Story 4 - Drag and Drop to Applications (Priority: P1)

**Goal**: Enable drag-and-drop of thumbnail to external applications (Finder, Slack, Messages, etc.)

**Independent Test**: Capture screenshot, drag thumbnail into Finder to create PNG file, drag into Messages to insert image

### Implementation for User Story 4

- [x] T029 [US4] Create DraggableThumbnail NSViewRepresentable in `ScreenPro/Features/QuickAccess/DraggableThumbnail.swift` implementing NSDraggingSource
- [x] T030 [US4] Implement mouseDown(with:) to start drag session with NSPasteboard containing TIFF and PNG data representations per research.md
- [x] T031 [US4] Implement draggingSession(_:sourceOperationMaskFor:) returning .copy for both internal and external contexts
- [x] T032 [US4] Add NSFilePromiseProvider support for Finder file creation with PNG format
- [x] T033 [US4] Replace Image in QuickAccessItemView with DraggableThumbnail for the thumbnail display
- [x] T034 [US4] Add visual feedback during drag (opacity change on drag start)

**Checkpoint**: User Story 4 complete - drag and drop works with common apps

---

## Phase 7: User Story 5 - Dismiss Capture (Priority: P1)

**Goal**: Enable quick dismissal of unwanted captures via Close button or Escape key

**Independent Test**: Capture screenshot, click Close button or press Escape, verify capture removed and overlay hidden if empty

### Implementation for User Story 5

- [x] T035 [P] [US5] Add Close (X) button to QuickAccessItemView action buttons row in `ScreenPro/Features/QuickAccess/QuickAccessItemView.swift`
- [x] T036 [US5] Add dismiss(_ item: CaptureItem) method to QuickAccessWindowController that removes item from queue
- [x] T037 [US5] Wire Close button tap to controller.dismiss() with item
- [x] T038 [US5] Add dismissAll() method to QuickAccessWindowController that clears queue and hides window
- [x] T039 [US5] Hide overlay window when queue becomes empty after dismiss
- [x] T040 [US5] Add tooltip "Dismiss (Esc)" to Close button

**Checkpoint**: User Story 5 complete - dismiss action works

---

## Phase 8: User Story 6 - Open in Annotation Editor (Priority: P2)

**Goal**: Enable opening capture in annotation editor directly from overlay

**Independent Test**: Capture screenshot, click Annotate button or press Return, verify editor opens (placeholder: opens in Preview)

### Implementation for User Story 6

- [x] T041 [P] [US6] Add Annotate button to QuickAccessItemView action buttons row in `ScreenPro/Features/QuickAccess/QuickAccessItemView.swift`
- [x] T042 [US6] Add openInAnnotator(_ item: CaptureItem) method to QuickAccessWindowController
- [x] T043 [US6] Add openAnnotationEditor(for result: CaptureResult) placeholder method to AppCoordinator that saves file and opens in Preview via NSWorkspace.shared.open()
- [x] T044 [US6] Wire Annotate button tap to controller.openInAnnotator() which calls coordinator.openAnnotationEditor()
- [x] T045 [US6] Remove item from queue after opening in annotator
- [x] T046 [US6] Add tooltip "Annotate (Return)" to Annotate button

**Checkpoint**: User Story 6 complete - annotate action works (placeholder)

---

## Phase 9: User Story 7 - Manage Multiple Captures (Priority: P2)

**Goal**: Queue multiple captures in vertical stack when taken in succession

**Independent Test**: Take 3+ screenshots rapidly, verify all appear stacked in overlay with newest at top

### Implementation for User Story 7

- [x] T047 [US7] Update QuickAccessContentView to display up to maxVisibleItems (5) in scrollable VStack in `ScreenPro/Features/QuickAccess/QuickAccessContentView.swift`
- [x] T048 [US7] Add scroll indicator when queue exceeds maxVisibleItems
- [x] T049 [US7] Update QuickAccessWindowController.updateContentSize() to adjust window height based on queue count
- [x] T050 [US7] Add entry animation for new items (fade in from edge)
- [x] T051 [US7] Add removal animation for dismissed items (fade out)
- [x] T052 [US7] Ensure action buttons work independently for each item in queue

**Checkpoint**: User Story 7 complete - multi-capture queue works

---

## Phase 10: User Story 8 - Keyboard Navigation (Priority: P2)

**Goal**: Navigate and act on captures using keyboard shortcuts

**Independent Test**: Take screenshots, use arrow keys to navigate, Cmd+C to copy, Cmd+S to save, Escape to dismiss

### Implementation for User Story 8

- [x] T053 [US8] Override keyDown(with:) in QuickAccessWindow to handle Escape (53), Return (36), Up (126), Down (125) key codes per contracts/QuickAccessProtocols.swift
- [x] T054 [US8] Handle Cmd+C, Cmd+S, Cmd+A modifier key combinations in keyDown
- [x] T055 [US8] Add performActionOnSelected(_ action: QuickAccessAction) method to QuickAccessWindowController
- [x] T056 [US8] Add selection highlight visual to selected item in QuickAccessItemView (border or background tint)
- [x] T057 [US8] Wire arrow keys to queue.selectNext() and queue.selectPrevious()
- [x] T058 [US8] Ensure window becomes key on show to receive keyboard events (makeKeyAndOrderFront)

**Checkpoint**: User Story 8 complete - keyboard navigation works

---

## Phase 11: User Story 9 - Configure Overlay Position (Priority: P3)

**Goal**: Allow user to choose which screen corner the overlay appears in

**Independent Test**: Change position setting to each corner, take screenshots, verify overlay appears in selected corner

### Implementation for User Story 9

- [x] T059 [US9] Add updatePosition() method to QuickAccessWindowController that calculates frame based on settingsManager.settings.quickAccessPosition
- [x] T060 [US9] Implement position calculation for all four corners (bottomLeft, bottomRight, topLeft, topRight) with screen insets
- [x] T061 [US9] Call updatePosition() in show() and when settings change
- [x] T062 [US9] Add per-session drag repositioning by making window movable (isMovableByWindowBackground = true)
- [x] T063 [US9] Observe settings changes via Combine publisher to update position when changed

**Checkpoint**: User Story 9 complete - position configuration works

---

## Phase 12: User Story 10 - Auto-Dismiss After Timeout (Priority: P3)

**Goal**: Automatically dismiss overlay after configurable inactivity period

**Independent Test**: Set auto-dismiss to 5 seconds, capture screenshot, wait without interaction, verify overlay dismisses

### Implementation for User Story 10

- [x] T064 [US10] Add autoDismissTimer property to QuickAccessWindowController
- [x] T065 [US10] Start/restart timer when capture added, reading duration from settingsManager.settings.autoDismissDelay
- [x] T066 [US10] Cancel timer when autoDismissDelay is 0 (disabled)
- [x] T067 [US10] Add cancelAutoDismiss() method called on any user interaction with overlay
- [x] T068 [US10] Add .onHover modifier to QuickAccessContentView to call cancelAutoDismiss() and restart timer on hover exit
- [x] T069 [US10] Call dismissAll() when timer fires

**Checkpoint**: User Story 10 complete - auto-dismiss works

---

## Phase 13: Polish & Cross-Cutting Concerns

**Purpose**: Integration testing, accessibility polish, and final validation

- [x] T070 Create QuickAccessIntegrationTests in `ScreenProTests/QuickAccess/QuickAccessIntegrationTests.swift` testing full capture→overlay flow
- [x] T071 [P] Verify VoiceOver announces all interactive elements correctly
- [x] T072 [P] Verify overlay persists across macOS Spaces (virtual desktops)
- [x] T073 Test overlay with very large captures (4K+) - verify thumbnail generation and memory
- [x] T074 Test drag-and-drop with Finder, Messages, Slack, Mail, Pages
- [x] T075 Verify overlay appears within 200ms of capture completion (performance target)
- [x] T076 Verify memory stays under 50MB with 5 captures in queue
- [x] T077 Run quickstart.md validation checklist

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-12)**: All depend on Foundational phase completion
  - US1 (View Preview) must complete before US2-US8 (they depend on the overlay infrastructure)
  - US2-US5 (P1 actions) can run in parallel after US1
  - US6-US8 (P2 features) can run in parallel after US1
  - US9-US10 (P3 features) can run in parallel after US1
- **Polish (Phase 13)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Foundation - BLOCKS all other stories (creates overlay infrastructure)
- **User Story 2 (P1)**: Requires US1 complete (needs action buttons infrastructure)
- **User Story 3 (P1)**: Requires US1 complete (needs action buttons infrastructure)
- **User Story 4 (P1)**: Requires US1 complete (needs thumbnail view to make draggable)
- **User Story 5 (P1)**: Requires US1 complete (needs action buttons infrastructure)
- **User Story 6 (P2)**: Requires US1 complete (needs action buttons infrastructure)
- **User Story 7 (P2)**: Requires US1 complete (extends queue display)
- **User Story 8 (P2)**: Requires US1 complete (adds keyboard handling to window)
- **User Story 9 (P3)**: Requires US1 complete (extends window positioning)
- **User Story 10 (P3)**: Requires US1 complete (adds timer to controller)

### Within Each User Story

- Models/infrastructure before views
- Controller methods before UI wiring
- Core implementation before polish (tooltips, animations)

### Parallel Opportunities

After Phase 2 (Foundational) and Phase 3 (US1) complete:

- US2, US3, US5 can run in parallel (independent action buttons)
- US4 can run in parallel (independent drag implementation)
- US6 can run in parallel (independent annotate action)
- US7, US8 can run in parallel (queue display vs keyboard)
- US9, US10 can run in parallel (position vs timer)

---

## Parallel Example: P1 Actions (US2, US3, US5)

```bash
# After US1 complete, launch these in parallel:
Task: T019 "Add Copy button to QuickAccessItemView" (US2)
Task: T024 "Add Save button to QuickAccessItemView" (US3)
Task: T035 "Add Close button to QuickAccessItemView" (US5)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (View Capture Preview)
4. **STOP and VALIDATE**: Test overlay appears after capture
5. Deploy/demo if ready - basic functionality works

### Core Actions (P1 Stories)

1. Add Phase 4-7: User Stories 2-5 (Copy, Save, Drag, Dismiss)
2. **VALIDATE**: All core actions work
3. Deploy - fully functional overlay

### Enhanced Features (P2 Stories)

1. Add Phase 8-10: User Stories 6-8 (Annotate, Queue, Keyboard)
2. **VALIDATE**: Power user features work
3. Deploy - complete feature set

### Polish (P3 Stories)

1. Add Phase 11-12: User Stories 9-10 (Position, Auto-dismiss)
2. Complete Phase 13: Polish
3. **VALIDATE**: All tests pass
4. Final deployment

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- US1 is foundational for overlay - must complete before other stories
- US2-US5 (P1 actions) can be parallelized after US1
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Performance targets: <200ms overlay appearance, <50MB memory with 5 captures
