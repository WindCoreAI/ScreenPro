# Tasks: Project Setup & Core Infrastructure

**Input**: Design documents from `/specs/001-project-setup/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Unit tests are included as specified in the plan. Tests for SettingsManager and PermissionManager are part of the constitution's Testing Discipline requirement.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Project structure from plan.md:
- `ScreenPro/` - Main application source
- `ScreenPro/Core/` - Core services and app coordinator
- `ScreenPro/Features/` - Feature modules (MenuBar, Settings)
- `ScreenProTests/` - Unit tests

---

## Phase 1: Setup (Project Initialization)

**Purpose**: Create Xcode project and configure build settings

- [x] T001 Create new macOS SwiftUI app project named ScreenPro in Xcode with Swift 5.9
- [x] T002 [P] Configure build settings: MACOSX_DEPLOYMENT_TARGET=14.0, SWIFT_STRICT_CONCURRENCY=complete in ScreenPro.xcodeproj
- [x] T003 [P] Add LSUIElement=true and usage descriptions to ScreenPro/Info.plist
- [x] T004 [P] Create entitlements file with sandbox and permission entitlements in ScreenPro/ScreenPro.entitlements
- [x] T005 Create folder structure: Core/, Core/Services/, Features/, Features/MenuBar/, Features/Settings/, Resources/ in ScreenPro/

---

## Phase 2: Foundational (Core Data Models & Services)

**Purpose**: Implement shared data models and service layer that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T006 [P] Create Settings struct with all Codable properties in ScreenPro/Core/Services/SettingsManager.swift
- [x] T007 [P] Create supporting enums (ImageFormat, VideoFormat, VideoQuality, QuickAccessPosition, CaptureType) in ScreenPro/Core/Services/SettingsManager.swift
- [x] T008 [P] Create Shortcut and ShortcutAction models in ScreenPro/Core/Services/ShortcutManager.swift
- [x] T009 [P] Create PermissionStatus enum in ScreenPro/Core/Services/PermissionManager.swift
- [x] T010 Create AppCoordinator.State enum with all state cases in ScreenPro/Core/AppCoordinator.swift
- [x] T011 Implement AppCoordinator class with state machine and service references in ScreenPro/Core/AppCoordinator.swift
- [x] T012 Create app entry point with @main and MenuBarExtra in ScreenPro/ScreenProApp.swift
- [x] T013 Implement AppDelegate with lifecycle management in ScreenPro/AppDelegate.swift

**Checkpoint**: Foundation ready - Core infrastructure exists, user story implementation can begin

---

## Phase 3: User Story 1 - Launch and Access App via Menu Bar (Priority: P1) 🎯 MVP

**Goal**: User can launch ScreenPro and access it via menu bar icon with dropdown menu showing all capture options

**Independent Test**: Launch app, verify menu bar icon appears, click to open dropdown, verify all menu options visible (disabled features grayed out), verify app not in Dock

### Implementation for User Story 1

- [x] T014 [US1] Implement MenuBarView with all capture and recording menu items in ScreenPro/Features/MenuBar/MenuBarView.swift
- [x] T015 [US1] Add capture section with area, window, fullscreen options (disabled) in ScreenPro/Features/MenuBar/MenuBarView.swift
- [x] T016 [US1] Add recording section with video and GIF options (disabled) in ScreenPro/Features/MenuBar/MenuBarView.swift
- [x] T017 [US1] Add settings and quit menu items with keyboard shortcuts in ScreenPro/Features/MenuBar/MenuBarView.swift
- [x] T018 [US1] Wire MenuBarView to AppCoordinator actions in ScreenPro/ScreenProApp.swift
- [x] T019 [US1] Add app icon to Assets.xcassets in ScreenPro/Resources/Assets.xcassets/AppIcon.appiconset/

**Checkpoint**: App launches with menu bar icon, dropdown displays all options, app hidden from Dock

---

## Phase 4: User Story 2 - Grant Screen Recording Permission (Priority: P1)

**Goal**: App checks for screen recording permission on launch and guides user to grant it through System Preferences

**Independent Test**: Fresh install (reset TCC), launch app, observe permission check behavior, click "Open Settings" and verify it opens correct System Preferences pane

### Implementation for User Story 2

- [x] T020 [US2] Implement PermissionManager with screen recording status tracking in ScreenPro/Core/Services/PermissionManager.swift
- [x] T021 [US2] Add checkScreenRecordingPermission using SCShareableContent in ScreenPro/Core/Services/PermissionManager.swift
- [x] T022 [US2] Add openScreenRecordingPreferences with x-apple.systempreferences URL in ScreenPro/Core/Services/PermissionManager.swift
- [x] T023 [US2] Add checkInitialPermissions for app launch in ScreenPro/Core/Services/PermissionManager.swift
- [x] T024 [US2] Integrate permission check into AppCoordinator.initialize() in ScreenPro/Core/AppCoordinator.swift
- [x] T025 [US2] Handle requestingPermission state in AppCoordinator in ScreenPro/Core/AppCoordinator.swift

**Checkpoint**: App checks screen recording permission on launch, provides guidance when denied

---

## Phase 5: User Story 3 - Configure Application Settings (Priority: P2)

**Goal**: User can open settings window, modify preferences across 4 tabs, and have changes persist after restart

**Independent Test**: Open settings (Cmd+,), change save location and image format, quit and relaunch, verify settings persisted

### Unit Tests for User Story 3

- [x] T026 [P] [US3] Create SettingsManagerTests with default settings test in ScreenProTests/SettingsManagerTests.swift
- [x] T027 [P] [US3] Add settings persistence test (save/load cycle) in ScreenProTests/SettingsManagerTests.swift
- [x] T028 [P] [US3] Add filename generation test in ScreenProTests/SettingsManagerTests.swift

### Implementation for User Story 3

- [x] T029 [US3] Implement SettingsManager with UserDefaults persistence in ScreenPro/Core/Services/SettingsManager.swift
- [x] T030 [US3] Add save(), reset(), and generateFilename() methods in ScreenPro/Core/Services/SettingsManager.swift
- [x] T031 [US3] Create SettingsView with TabView structure in ScreenPro/Features/Settings/SettingsView.swift
- [x] T032 [P] [US3] Implement GeneralSettingsTab with launch at login, menu bar icon, capture sound toggles in ScreenPro/Features/Settings/GeneralSettingsTab.swift
- [x] T033 [P] [US3] Implement CaptureSettingsTab with save location, naming pattern, format options in ScreenPro/Features/Settings/CaptureSettingsTab.swift
- [x] T034 [P] [US3] Implement RecordingSettingsTab with video format, quality, FPS, audio options in ScreenPro/Features/Settings/RecordingSettingsTab.swift
- [x] T035 [P] [US3] Create PermissionRow component for displaying permission status in ScreenPro/Features/Settings/GeneralSettingsTab.swift
- [x] T036 [US3] Add Settings scene to ScreenProApp with Cmd+, shortcut in ScreenPro/ScreenProApp.swift
- [x] T037 [US3] Implement showSettings() in AppCoordinator with NSWindow in ScreenPro/Core/AppCoordinator.swift

**Checkpoint**: Settings window opens with 4 tabs, changes persist after restart

---

## Phase 6: User Story 4 - Use Global Keyboard Shortcuts (Priority: P2)

**Goal**: User can trigger capture actions via global keyboard shortcuts even when app is not focused

**Independent Test**: Focus another app, press Cmd+Shift+4, verify area capture state transition (placeholder for M1)

### Implementation for User Story 4

- [x] T038 [US4] Implement ShortcutManager with Carbon hotkey registration in ScreenPro/Core/Services/ShortcutManager.swift
- [x] T039 [US4] Define default shortcuts dictionary (Cmd+Shift+3,4,5,6) in ScreenPro/Core/Services/ShortcutManager.swift
- [x] T040 [US4] Implement register(), unregister(), registerAll(), unregisterAll() methods in ScreenPro/Core/Services/ShortcutManager.swift
- [x] T041 [US4] Implement detectConflict() for system shortcut detection in ScreenPro/Core/Services/ShortcutManager.swift
- [x] T042 [US4] Add displayString computed property with modifier symbols in ScreenPro/Core/Services/ShortcutManager.swift
- [x] T043 [US4] Implement ShortcutsSettingsTab with shortcut display in ScreenPro/Features/Settings/ShortcutsSettingsTab.swift
- [x] T044 [US4] Create ShortcutRow component for displaying shortcuts in ScreenPro/Features/Settings/ShortcutsSettingsTab.swift
- [x] T045 [US4] Wire ShortcutManager action handler to AppCoordinator in ScreenPro/AppDelegate.swift
- [x] T046 [US4] Call registerDefaults() on app launch in ScreenPro/AppDelegate.swift

**Checkpoint**: Global shortcuts registered and trigger state transitions

---

## Phase 7: User Story 5 - Manage Microphone Permission for Recording (Priority: P3)

**Goal**: User can view microphone permission status in settings and request/grant permission

**Independent Test**: Open Settings > General, view microphone status, click Request if not determined, verify system dialog appears

### Unit Tests for User Story 5

- [x] T047 [P] [US5] Create PermissionManagerTests with status check test in ScreenProTests/PermissionManagerTests.swift
- [x] T048 [P] [US5] Add microphone permission status test in ScreenProTests/PermissionManagerTests.swift

### Implementation for User Story 5

- [x] T049 [US5] Add microphone status tracking to PermissionManager in ScreenPro/Core/Services/PermissionManager.swift
- [x] T050 [US5] Implement checkMicrophonePermission() using AVCaptureDevice in ScreenPro/Core/Services/PermissionManager.swift
- [x] T051 [US5] Implement requestMicrophonePermission() with async/await in ScreenPro/Core/Services/PermissionManager.swift
- [x] T052 [US5] Implement openMicrophonePreferences() with x-apple.systempreferences URL in ScreenPro/Core/Services/PermissionManager.swift
- [x] T053 [US5] Add microphone PermissionRow to GeneralSettingsTab in ScreenPro/Features/Settings/GeneralSettingsTab.swift

**Checkpoint**: Microphone permission status visible in settings, request flow works

---

## Phase 8: User Story 6 - Storage Service (Supporting Infrastructure)

**Goal**: Provide file operations and clipboard functionality for future capture features

**Independent Test**: Call generateFilename() and verify correct format, test clipboard operations

### Implementation for User Story 6

- [x] T054 [P] Implement StorageService with save() and delete() methods in ScreenPro/Core/Services/StorageService.swift
- [x] T055 [P] Add uniqueURL() for filename conflict resolution in ScreenPro/Core/Services/StorageService.swift
- [x] T056 [P] Add copyToClipboard() methods for image data and NSImage in ScreenPro/Core/Services/StorageService.swift
- [x] T057 Wire StorageService to AppCoordinator in ScreenPro/Core/AppCoordinator.swift
- [x] T058 Ensure save directory creation on settings load in ScreenPro/Core/Services/SettingsManager.swift

**Checkpoint**: Storage operations ready for Milestone 2 capture implementation

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Final integration, cleanup, and validation

- [x] T059 Add accessible labels to all menu items in ScreenPro/Features/MenuBar/MenuBarView.swift
- [x] T060 Add accessible labels to all settings controls in ScreenPro/Features/Settings/
- [x] T061 Implement AppCoordinator.cleanup() for shortcut unregistration in ScreenPro/Core/AppCoordinator.swift
- [x] T062 Run XCTest suite and verify all tests pass
- [x] T063 Build with Release configuration and verify no warnings
- [x] T064 Verify app launches under 2 seconds and memory under 50MB idle
- [x] T065 Run quickstart.md verification checklist manually

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-8)**: All depend on Foundational phase completion
  - US1 and US2 are both P1 and can proceed in parallel after Foundational
  - US3 and US4 are both P2 and can proceed in parallel after US1/US2
  - US5 is P3 and can proceed after US3/US4
  - US6 (Storage) is infrastructure and can proceed in parallel with any story
- **Polish (Phase 9)**: Depends on all user stories being complete

### User Story Dependencies

| Story | Priority | Can Start After | Depends On Stories |
|-------|----------|-----------------|-------------------|
| US1 - Menu Bar | P1 | Foundational | None |
| US2 - Screen Recording Permission | P1 | Foundational | None |
| US3 - Settings | P2 | Foundational | None (uses US2 permission display) |
| US4 - Shortcuts | P2 | Foundational | None |
| US5 - Microphone Permission | P3 | Foundational | US2 (shares PermissionManager) |
| US6 - Storage | Support | Foundational | None |

### Within Each User Story

- Tests (if included) MUST be written and FAIL before implementation
- Data models before services
- Services before UI
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

**Phase 1 (Setup)**:
- T002, T003, T004 can run in parallel

**Phase 2 (Foundational)**:
- T006, T007, T008, T009 can run in parallel (different files)

**User Story Phases**:
- US3: T026, T027, T028 (tests) can run in parallel
- US3: T032, T033, T034, T035 (settings tabs) can run in parallel
- US5: T047, T048 (tests) can run in parallel
- US6: T054, T055, T056 can run in parallel

**Cross-Story Parallelism**:
- Once Foundational is complete, US1 and US2 can proceed in parallel
- US3 and US4 can proceed in parallel
- US5 and US6 can proceed in parallel

---

## Parallel Example: User Story 3 (Settings)

```bash
# Launch all tests together:
Task: "Create SettingsManagerTests with default settings test in ScreenProTests/SettingsManagerTests.swift"
Task: "Add settings persistence test in ScreenProTests/SettingsManagerTests.swift"
Task: "Add filename generation test in ScreenProTests/SettingsManagerTests.swift"

# Launch all settings tabs together (after SettingsManager is done):
Task: "Implement GeneralSettingsTab in ScreenPro/Features/Settings/GeneralSettingsTab.swift"
Task: "Implement CaptureSettingsTab in ScreenPro/Features/Settings/CaptureSettingsTab.swift"
Task: "Implement RecordingSettingsTab in ScreenPro/Features/Settings/RecordingSettingsTab.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 + 2 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (Menu Bar)
4. Complete Phase 4: User Story 2 (Screen Recording Permission)
5. **STOP and VALIDATE**: App launches, menu bar works, permission handling works
6. This is a functional MVP for Milestone 1

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add US1 + US2 → Test independently → MVP ready!
3. Add US3 (Settings) → Test settings persistence → Enhanced app
4. Add US4 (Shortcuts) → Test global shortcuts → Power user features
5. Add US5 (Microphone) + US6 (Storage) → Ready for Milestone 2

### Parallel Team Strategy

With multiple developers after Foundational is complete:

- Developer A: User Story 1 (Menu Bar)
- Developer B: User Story 2 (Screen Recording Permission)
- Developer C: User Story 3 (Settings) - can start US3 while A/B finish US1/US2

---

## Summary

| Metric | Count |
|--------|-------|
| Total Tasks | 65 |
| Setup Phase | 5 |
| Foundational Phase | 8 |
| User Story 1 (Menu Bar) | 6 |
| User Story 2 (Permission) | 6 |
| User Story 3 (Settings) | 12 |
| User Story 4 (Shortcuts) | 9 |
| User Story 5 (Microphone) | 7 |
| User Story 6 (Storage) | 5 |
| Polish Phase | 7 |
| Parallel Tasks [P] | 24 |

**MVP Scope**: Setup + Foundational + US1 + US2 = 25 tasks

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Constitution requires @MainActor for all UI-related services
- All services must be protocol-based for testability per constitution
