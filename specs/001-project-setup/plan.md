# Implementation Plan: Project Setup & Core Infrastructure

**Branch**: `001-project-setup` | **Date**: 2025-12-22 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-project-setup/spec.md`

## Summary

Establish the foundational infrastructure for ScreenPro, a native macOS screenshot and screen recording application. This milestone delivers a working menu bar application with permission handling, global keyboard shortcuts, and a complete settings system. The app will be hidden from the Dock, accessible via menu bar, and will manage screen recording and microphone permissions to prepare for future capture functionality.

## Technical Context

**Language/Version**: Swift 5.9+ with strict concurrency checking enabled
**Primary Dependencies**: SwiftUI (UI), AppKit (NSStatusItem, NSWindow), ScreenCaptureKit (permission detection), AVFoundation (microphone permission), Carbon (global hotkeys)
**Storage**: UserDefaults for settings persistence (SwiftData deferred to later milestone for capture history)
**Testing**: XCTest for unit tests
**Target Platform**: macOS 14.0+ (Sonoma), Universal Binary (Apple Silicon + Intel)
**Project Type**: Single macOS application
**Performance Goals**: Launch < 2 seconds, Menu response < 100ms, Settings open < 500ms, Shortcut response < 200ms
**Constraints**: Memory < 50MB idle, App Sandbox enabled, LSUIElement (no Dock icon)
**Scale/Scope**: Single-user desktop application

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Compliance Notes |
|-----------|--------|------------------|
| I. Native macOS First | ✅ PASS | Using SwiftUI, AppKit, ScreenCaptureKit, AVFoundation - all Apple frameworks |
| II. Privacy by Default | ✅ PASS | All data stored locally via UserDefaults, no telemetry, no network calls in this milestone |
| III. UX Excellence | ✅ PASS | Menu bar unobtrusive (LSUIElement), keyboard-accessible via global shortcuts |
| IV. Performance Standards | ✅ PASS | Targets set: launch < 2s, menu < 100ms, shortcuts < 200ms, memory < 50MB |
| V. Testing Discipline | ✅ PASS | Unit tests planned for settings persistence and service layer |
| VI. Accessibility Compliance | ✅ PASS | All UI elements will have accessible labels, keyboard navigation supported |
| VII. Security Boundaries | ✅ PASS | App Sandbox enabled, permissions requested when needed, no sensitive data storage |

**Gate Result**: PASS - All constitution principles satisfied. Proceeding to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/001-project-setup/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (internal service contracts)
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
ScreenPro/
├── ScreenProApp.swift           # App entry point with @main
├── AppDelegate.swift            # NSApplicationDelegate for lifecycle
├── Info.plist                   # App configuration (LSUIElement, permissions)
├── ScreenPro.entitlements       # Sandbox and permission entitlements
│
├── Core/
│   ├── AppCoordinator.swift     # Central state machine
│   └── Services/
│       ├── PermissionManager.swift   # Screen recording & microphone permissions
│       ├── ShortcutManager.swift     # Global keyboard shortcut registration
│       ├── SettingsManager.swift     # User preferences persistence
│       └── StorageService.swift      # File operations (minimal for M1)
│
├── Features/
│   ├── MenuBar/
│   │   └── MenuBarView.swift    # Menu bar dropdown menu
│   └── Settings/
│       ├── SettingsView.swift        # Main settings window
│       ├── GeneralSettingsTab.swift  # General preferences tab
│       ├── CaptureSettingsTab.swift  # Capture preferences tab
│       ├── RecordingSettingsTab.swift # Recording preferences tab
│       └── ShortcutsSettingsTab.swift # Shortcut configuration tab
│
└── Resources/
    └── Assets.xcassets/
        └── AppIcon.appiconset/  # App icons

ScreenProTests/
├── SettingsManagerTests.swift   # Settings persistence tests
└── PermissionManagerTests.swift # Permission status tests
```

**Structure Decision**: Single macOS application structure following Apple's recommended patterns. Feature-based organization within Features/ folder, shared services in Core/Services/. Tests in separate ScreenProTests target.

## Complexity Tracking

> No constitution violations. No complexity tracking needed.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | N/A |

---

## Post-Design Constitution Re-Check

*Re-evaluated after Phase 1 design completion.*

| Principle | Status | Post-Design Verification |
|-----------|--------|--------------------------|
| I. Native macOS First | ✅ PASS | All frameworks verified: SwiftUI, AppKit, ScreenCaptureKit, AVFoundation, Carbon. No external dependencies. |
| II. Privacy by Default | ✅ PASS | Data model confirms local-only storage. No network calls. No telemetry. |
| III. UX Excellence | ✅ PASS | Service contracts support keyboard accessibility. LSUIElement confirmed. |
| IV. Performance Standards | ✅ PASS | Performance targets documented in Technical Context. Memory < 50MB confirmed as constraint. |
| V. Testing Discipline | ✅ PASS | Test files planned in project structure. Service protocols enable testability. |
| VI. Accessibility Compliance | ✅ PASS | SwiftUI provides default accessibility. Settings tabs support keyboard navigation. |
| VII. Security Boundaries | ✅ PASS | App Sandbox in entitlements. Permission requests at appropriate times per service contracts. |

**Final Gate Result**: ✅ PASS - Design fully compliant with constitution. Ready for task generation.

---

## Generated Artifacts

| Artifact | Path | Status |
|----------|------|--------|
| Implementation Plan | [plan.md](./plan.md) | ✅ Complete |
| Research | [research.md](./research.md) | ✅ Complete |
| Data Model | [data-model.md](./data-model.md) | ✅ Complete |
| Service Contracts | [contracts/services.md](./contracts/services.md) | ✅ Complete |
| Quickstart Guide | [quickstart.md](./quickstart.md) | ✅ Complete |
| Tasks | tasks.md | ⏳ Pending `/speckit.tasks` |

---

## Next Steps

Run `/speckit.tasks` to generate the implementation task list from this plan.
