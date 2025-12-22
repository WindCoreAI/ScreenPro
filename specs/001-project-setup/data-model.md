# Data Model: Project Setup & Core Infrastructure

**Feature**: 001-project-setup
**Date**: 2025-12-22

## Overview

This document defines the data models for Milestone 1 of ScreenPro. These models focus on application state, user settings, and keyboard shortcuts. Capture history models are deferred to later milestones.

---

## 1. Application State

### AppCoordinator.State

Central state machine enum representing the current application state.

```
AppCoordinator.State
├── idle                    # Default state, ready for user action
├── requestingPermission    # Waiting for user to grant permissions
├── selectingArea           # (Future) User selecting screen region
├── selectingWindow         # (Future) User selecting window
├── capturing               # (Future) Capture in progress
├── recording               # (Future) Recording in progress
├── annotating(UUID)        # (Future) Editing capture with given ID
└── uploading(UUID)         # (Future) Uploading capture with given ID
```

**Validation Rules**:
- Only `idle` and `requestingPermission` are valid states for Milestone 1
- State transitions must be explicit via AppCoordinator methods
- Future states exist as placeholders to maintain stable API

---

## 2. Settings Model

### Settings

Root model containing all user-configurable preferences.

```
Settings (Codable)
├── General
│   ├── launchAtLogin: Bool = false
│   ├── showMenuBarIcon: Bool = true
│   └── playCaptureSound: Bool = true
│
├── Capture
│   ├── defaultSaveLocation: URL = ~/Pictures/ScreenPro
│   ├── fileNamingPattern: String = "Screenshot {date} at {time}"
│   ├── defaultImageFormat: ImageFormat = .png
│   ├── includeCursor: Bool = false
│   ├── showCrosshair: Bool = true
│   ├── showMagnifier: Bool = false
│   └── hideDesktopIcons: Bool = false
│
├── Recording
│   ├── defaultVideoFormat: VideoFormat = .mp4
│   ├── videoQuality: VideoQuality = .high
│   ├── videoFPS: Int = 30
│   ├── recordMicrophone: Bool = false
│   ├── recordSystemAudio: Bool = false
│   ├── showClicks: Bool = false
│   └── showKeystrokes: Bool = false
│
└── QuickAccess
    ├── showQuickAccess: Bool = true
    ├── quickAccessPosition: QuickAccessPosition = .bottomLeft
    └── autoDismissDelay: TimeInterval = 0.0
```

**Validation Rules**:
- `fileNamingPattern` must contain at least `{date}` or `{time}` placeholder
- `videoFPS` must be one of: 24, 30, 60
- `autoDismissDelay` of 0.0 means manual dismiss (no auto)
- `defaultSaveLocation` must be a valid writable directory

---

## 3. Supporting Enums

### ImageFormat

```
ImageFormat (String, Codable, CaseIterable)
├── png   → extension: "png",  utType: "public.png"
├── jpeg  → extension: "jpeg", utType: "public.jpeg"
├── tiff  → extension: "tiff", utType: "public.tiff"
└── heic  → extension: "heic", utType: "public.heic"
```

### VideoFormat

```
VideoFormat (String, Codable, CaseIterable)
├── mp4  → extension: "mp4"
└── mov  → extension: "mov"
```

### VideoQuality

```
VideoQuality (String, Codable, CaseIterable)
├── low     → displayName: "Low (480p)"
├── medium  → displayName: "Medium (720p)"
├── high    → displayName: "High (1080p)"
└── maximum → displayName: "Maximum (4K)"
```

### QuickAccessPosition

```
QuickAccessPosition (String, Codable, CaseIterable)
├── bottomLeft
├── bottomRight
├── topLeft
└── topRight
```

---

## 4. Shortcut Model

### Shortcut

Represents a keyboard shortcut combination.

```
Shortcut (Codable, Hashable)
├── keyCode: UInt32        # Carbon key code
├── modifiers: UInt32      # Carbon modifier flags
└── displayString: String  # Computed: "⌘⇧4" style representation
```

**Validation Rules**:
- `modifiers` must include at least one modifier (Cmd, Shift, Option, or Control)
- `keyCode` must be a valid Carbon key code
- No two shortcuts may have the same keyCode + modifiers combination

### ShortcutAction

```
ShortcutAction (String, Codable, CaseIterable)
├── captureArea
├── captureWindow
├── captureFullscreen
├── captureScrolling
├── startRecording
├── recordGIF
├── textRecognition
└── allInOne
```

### Default Shortcuts

| Action | Key | Modifiers | Display |
|--------|-----|-----------|---------|
| captureArea | 4 (0x15) | ⌘⇧ | ⌘⇧4 |
| captureFullscreen | 3 (0x14) | ⌘⇧ | ⌘⇧3 |
| allInOne | 5 (0x17) | ⌘⇧ | ⌘⇧5 |
| startRecording | 6 (0x16) | ⌘⇧ | ⌘⇧6 |

---

## 5. Permission Model

### PermissionStatus

```
PermissionStatus
├── authorized      # Permission granted
├── denied          # Permission explicitly denied
└── notDetermined   # User has not yet responded to prompt
```

**Relationships**:
- PermissionManager tracks status for: screenRecording, microphone
- Status is checked on app launch and cached
- Status may change externally (System Preferences)

---

## 6. Capture Type (Filename Generation)

### CaptureType

Used by StorageService for filename generation.

```
CaptureType
├── screenshot  → uses defaultImageFormat extension
├── video       → uses defaultVideoFormat extension
└── gif         → always ".gif"
```

---

## Entity Relationships

```
┌─────────────────────────────────────────────────────────────────────┐
│                        AppCoordinator                                │
│  - state: State                                                      │
│  - isReady: Bool                                                     │
├─────────────────────────────────────────────────────────────────────┤
│  Owns Services:                                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐      │
│  │ PermissionManager│  │ ShortcutManager │  │ SettingsManager │      │
│  │                  │  │                  │  │                 │      │
│  │ screenRecording: │  │ shortcuts:       │  │ settings:       │      │
│  │   PermissionStatus│  │   [Action:Shortcut]│  │   Settings    │      │
│  │ microphone:      │  │ hotKeyRefs:      │  │                 │      │
│  │   PermissionStatus│  │   [Action:Ref]   │  │                 │      │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘      │
│                                                                      │
│  ┌─────────────────┐                                                 │
│  │ StorageService  │                                                 │
│  │                  │                                                 │
│  │ Generates filenames                                               │
│  │ using SettingsManager                                             │
│  └─────────────────┘                                                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Persistence Strategy

| Model | Storage | Location |
|-------|---------|----------|
| Settings | UserDefaults | Key: "ScreenProSettings" |
| Shortcuts | Within Settings | Stored as part of Settings |
| PermissionStatus | Not persisted | Checked at runtime |
| AppState | Not persisted | Runtime only |

---

## Migration Strategy

**Version 1.0.0** (Initial Release):
- No migration needed
- Decode failure falls back to default Settings

**Future Versions**:
- Add version field to Settings
- Implement migration functions for schema changes
- Preserve user preferences during updates
