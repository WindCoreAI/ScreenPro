# Research: Project Setup & Core Infrastructure

**Feature**: 001-project-setup
**Date**: 2025-12-22
**Status**: Complete

## Research Summary

This document captures technical decisions and best practices for implementing the ScreenPro project foundation. All technical context is well-understood from the specification and existing documentation.

---

## 1. Global Keyboard Shortcuts on macOS

### Decision
Use Carbon API (`RegisterEventHotKey`) for global keyboard shortcut registration.

### Rationale
- Carbon API is the established, stable method for registering system-wide keyboard shortcuts on macOS
- Works reliably across all supported macOS versions (14.0+)
- Does not require Accessibility permission for basic hotkey registration
- Alternative libraries (HotKey, MASShortcut) are wrappers around Carbon anyway

### Alternatives Considered
| Alternative | Why Rejected |
|-------------|--------------|
| NSEvent global monitors | Requires Accessibility permission, more complex setup |
| CGEvent taps | Requires Accessibility permission, overkill for simple hotkeys |
| HotKey Swift package | External dependency violates "Apple frameworks only" constitution rule |
| MASShortcut | Objective-C library, external dependency |

### Implementation Notes
- `RegisterEventHotKey` for registration
- `UnregisterEventHotKey` for cleanup
- Handle `EventHotKeyID` uniquely per action
- Conflict detection by attempting registration and checking result

---

## 2. Menu Bar Integration with SwiftUI

### Decision
Use `MenuBarExtra` (SwiftUI native) with `.menuBarExtraStyle(.menu)` for standard dropdown menu appearance.

### Rationale
- Native SwiftUI approach introduced in macOS 13
- Simplest integration with SwiftUI app lifecycle
- Automatic handling of menu bar visibility and styling
- Constitution requires SwiftUI as primary UI framework

### Alternatives Considered
| Alternative | Why Rejected |
|-------------|--------------|
| NSStatusItem directly | Requires more boilerplate, harder SwiftUI integration |
| NSPopover style | Spec requires standard dropdown menu, not popover |

### Implementation Notes
- `MenuBarExtra` declared in App `body` alongside `Settings` scene
- Use `@NSApplicationDelegateAdaptor` for AppDelegate integration
- `Image(systemName: "camera.viewfinder")` for menu bar icon
- Pass `AppCoordinator` via `@EnvironmentObject`

---

## 3. LSUIElement (Hide from Dock)

### Decision
Set `LSUIElement` to `true` in Info.plist.

### Rationale
- Standard macOS mechanism for agent/helper apps
- Hides app from Dock and App Switcher
- Menu bar icon remains visible
- Constitution Principle III: "invisible until needed"

### Implementation Notes
```xml
<key>LSUIElement</key>
<true/>
```

---

## 4. Screen Recording Permission Detection

### Decision
Use ScreenCaptureKit's `SCShareableContent.excludingDesktopWindows` to check permission status.

### Rationale
- ScreenCaptureKit automatically triggers permission dialog when accessing content
- No separate permission check API exists - attempting access reveals status
- If access succeeds, permission is granted; if error code indicates user declined, permission is denied
- Constitution requires ScreenCaptureKit for all screen capture operations

### Alternatives Considered
| Alternative | Why Rejected |
|-------------|--------------|
| CGWindowListCreateImage | Deprecated, constitution explicitly forbids |
| CGDisplayStream | Older API, not recommended |

### Implementation Notes
- `SCStreamError.userDeclined` indicates permission denied
- Empty content (no windows/displays) while successful indicates fresh state
- Navigate to System Preferences via URL scheme: `x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture`

---

## 5. Microphone Permission Handling

### Decision
Use AVFoundation's `AVCaptureDevice.authorizationStatus(for: .audio)` and `requestAccess(for: .audio)`.

### Rationale
- Standard AVFoundation API for microphone permission
- Works consistently across macOS versions
- Constitution requires AVFoundation for audio operations

### Implementation Notes
- Check status with `authorizationStatus(for: .audio)`
- Request with async `requestAccess(for: .audio)` continuation wrapper
- Navigate to System Preferences: `x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone`

---

## 6. Settings Persistence

### Decision
Use UserDefaults with Codable wrapper for all settings.

### Rationale
- Simple, lightweight persistence for preferences
- Constitution allows UserDefaults for settings (SwiftData for history)
- Automatic synchronization with macOS preference system
- Easy migration and reset functionality

### Alternatives Considered
| Alternative | Why Rejected |
|-------------|--------------|
| SwiftData | Overkill for simple preferences, reserved for capture history |
| Property list file | More complex, UserDefaults handles this automatically |
| @AppStorage | Less flexible for complex settings model |

### Implementation Notes
- `Settings` struct conforming to `Codable`
- JSON encoding/decoding for UserDefaults storage
- Single key: "ScreenProSettings"
- Fallback to defaults on decode failure

---

## 7. App State Machine Pattern

### Decision
Use enum-based state machine in `AppCoordinator` with `@MainActor` annotation.

### Rationale
- Clear state transitions with exhaustive switch handling
- Thread safety via @MainActor for UI-related state
- Constitution: "@MainActor for all UI-related code"
- Central coordination point for all app actions

### States for Milestone 1
```swift
enum State {
    case idle
    case requestingPermission
    // Future states (placeholder for M2+):
    case selectingArea
    case selectingWindow
    case capturing
    case recording
    case annotating(UUID)
    case uploading(UUID)
}
```

---

## 8. SwiftUI Settings Window

### Decision
Use SwiftUI `Settings` scene with `TabView` for tabbed preferences.

### Rationale
- Native SwiftUI settings integration
- Automatically responds to ⌘, keyboard shortcut
- Tab-based organization matches spec (General, Capture, Recording, Shortcuts)
- Constitution: SwiftUI as primary UI framework

### Implementation Notes
- `Settings { SettingsView() }` in App body
- `TabView` with `.tabItem` for each tab
- `.formStyle(.grouped)` for macOS-native form styling
- `fileImporter` modifier for folder selection

---

## 9. Xcode Project Configuration

### Decision
Create new Xcode project with following configuration:
- Product Name: ScreenPro
- Interface: SwiftUI
- Language: Swift
- Deployment Target: macOS 14.0
- Hardened Runtime: Yes
- App Sandbox: Yes

### Build Settings
```
MACOSX_DEPLOYMENT_TARGET = 14.0
SWIFT_VERSION = 5.9
ENABLE_HARDENED_RUNTIME = YES
CODE_SIGN_ENTITLEMENTS = ScreenPro/ScreenPro.entitlements
SWIFT_STRICT_CONCURRENCY = complete
```

### Entitlements
- `com.apple.security.app-sandbox` = true
- `com.apple.security.files.user-selected.read-write` = true
- `com.apple.security.files.downloads.read-write` = true
- `com.apple.security.assets.pictures.read-write` = true
- `com.apple.security.network.client` = true (for future cloud feature)
- `com.apple.security.device.audio-input` = true

---

## 10. Service Layer Architecture

### Decision
Protocol-based services injected into AppCoordinator, all services @MainActor.

### Rationale
- Constitution: "Services MUST be protocol-based for testability"
- Constitution: "@MainActor for all UI-related code"
- Clear separation of concerns
- Easy mocking for tests

### Services for Milestone 1
| Service | Responsibility |
|---------|---------------|
| PermissionManager | Check/request screen recording and microphone permissions |
| ShortcutManager | Register/unregister global keyboard shortcuts |
| SettingsManager | Persist and retrieve user preferences |
| StorageService | File operations, clipboard, filename generation |

---

## Dependencies Summary

### Apple Frameworks Used
| Framework | Purpose |
|-----------|---------|
| SwiftUI | UI framework, MenuBarExtra, Settings |
| AppKit | NSWindow, NSStatusItem integration |
| ScreenCaptureKit | Screen recording permission detection |
| AVFoundation | Microphone permission handling |
| Carbon | Global keyboard shortcut registration |
| UniformTypeIdentifiers | File type handling |

### External Dependencies
None - Constitution Principle I requires Apple frameworks only.

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Carbon API deprecation | Monitor WWDC for modern alternatives; API stable for 15+ years |
| Permission flow confusion | Clear UI guidance, direct links to System Preferences |
| Shortcut conflicts with system | Detect conflicts, warn user, allow customization |
| UserDefaults corruption | Fallback to defaults, continue functioning |
