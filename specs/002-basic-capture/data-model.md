# Data Model: Basic Screenshot Capture

**Feature**: 002-basic-capture
**Date**: 2025-12-22

## Overview

This document defines the data entities for the screenshot capture feature. Models follow Swift conventions with Codable conformance where persistence is needed.

---

## Core Entities

### CaptureMode

Represents the type of capture operation being performed.

```
CaptureMode
├── area(CGRect)         # User-selected rectangular region
├── window(SCWindow)     # Single application window
└── display(SCDisplay)   # Entire display/screen
```

**Relationships**:
- Used by CaptureService to determine capture method
- Stored in CaptureResult for metadata

**Validation**:
- Area rect must be > 5x5 pixels
- Window must be valid SCWindow from SCShareableContent
- Display must be valid SCDisplay from SCShareableContent

---

### CaptureConfig

Configuration options for a capture operation.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| includeCursor | Bool | false | Whether to show cursor in capture |
| imageFormat | ImageFormat | .png | Output format (PNG, JPEG, TIFF, HEIC) |
| scaleFactor | CGFloat | 2.0 | Retina scale factor |

**Relationships**:
- Populated from SettingsManager.settings
- Passed to CaptureService for capture configuration

**Validation**:
- scaleFactor must be >= 1.0

---

### CaptureResult

The output of a successful capture operation.

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Unique identifier for this capture |
| image | CGImage | The captured image at native resolution |
| mode | CaptureMode | How the capture was performed |
| timestamp | Date | When the capture occurred |
| sourceRect | CGRect | Original screen coordinates of capture |

**Computed Properties**:
- `nsImage: NSImage` - Converts CGImage to NSImage for clipboard/display

**Relationships**:
- Created by CaptureService after successful capture
- Consumed by StorageService for save/clipboard operations
- Will be consumed by QuickAccessOverlay in Milestone 3

**Validation**:
- image must be non-nil
- sourceRect must be non-empty

---

### DisplayInfo

Wrapper for display information combining NSScreen and SCDisplay data.

| Field | Type | Description |
|-------|------|-------------|
| screen | NSScreen | AppKit screen reference |
| scDisplay | SCDisplay? | ScreenCaptureKit display (after content refresh) |
| frame | CGRect | Screen frame in global coordinates |
| isMain | Bool | Whether this is the main display |

**Computed Properties**:
- `displayID: CGDirectDisplayID` - Core Graphics display identifier

**Relationships**:
- Created by DisplayManager
- Used for multi-monitor coordinate conversion

---

## Service Entities

### SelectionState

Tracks the current state of area selection.

| Field | Type | Description |
|-------|------|-------------|
| startPoint | CGPoint? | Where drag started (screen coordinates) |
| currentPoint | CGPoint? | Current mouse position |
| isDragging | Bool | Whether user is actively dragging |

**Computed Properties**:
- `selectionRect: CGRect?` - Calculated rectangle from start to current point

**Validation**:
- selectionRect must be > 5x5 to be valid

---

### WindowSelection

Tracks state during window picker mode.

| Field | Type | Description |
|-------|------|-------------|
| hoveredWindow | SCWindow? | Currently highlighted window |
| availableWindows | [SCWindow] | All selectable windows |

**Relationships**:
- Managed by WindowPickerController
- Windows filtered from SCShareableContent

---

## Error Types

### CaptureError

Errors that can occur during capture operations.

| Case | Description |
|------|-------------|
| noDisplayFound | No display found for capture area |
| cropFailed | Failed to crop captured image to selection |
| permissionDenied | Screen recording permission not granted |
| invalidSelection | Selection too small (< 5x5 pixels) |
| cancelled | User cancelled capture (Escape key) |

**Relationships**:
- Thrown by CaptureService methods
- Handled by AppCoordinator for user notification

---

## Entity Relationships Diagram

```
┌─────────────────┐
│ AppCoordinator  │
│ (State Machine) │
└────────┬────────┘
         │ triggers
         ▼
┌─────────────────┐     uses      ┌──────────────────┐
│ CaptureService  │──────────────▶│ DisplayManager   │
│                 │               │                  │
│ - captureArea() │               │ - displays       │
│ - captureWindow │               │ - display(for:)  │
│ - captureDisplay│               └──────────────────┘
└────────┬────────┘
         │ returns
         ▼
┌─────────────────┐     passed to ┌──────────────────┐
│ CaptureResult   │──────────────▶│ StorageService   │
│                 │               │                  │
│ - id            │               │ - save()         │
│ - image         │               │ - copyToClipboard│
│ - mode          │               └──────────────────┘
│ - timestamp     │
└─────────────────┘

┌─────────────────┐
│ SelectionWindow │─────▶ SelectionState
│ (UI Overlay)    │       - startPoint
└─────────────────┘       - currentPoint
                          - selectionRect

┌─────────────────┐
│ WindowPicker    │─────▶ WindowSelection
│ Controller      │       - hoveredWindow
└─────────────────┘       - availableWindows
```

---

## State Transitions

### Capture Flow States

```
idle
  │
  ├──[captureArea()]───▶ selectingArea
  │                           │
  │                           ├──[drag complete]───▶ capturing
  │                           │                          │
  │                           │                          └──▶ idle (success)
  │                           │
  │                           └──[Escape/cancel]───▶ idle
  │
  ├──[captureWindow()]──▶ selectingWindow
  │                           │
  │                           ├──[click window]────▶ capturing
  │                           │                          │
  │                           │                          └──▶ idle (success)
  │                           │
  │                           └──[Escape/cancel]───▶ idle
  │
  └──[captureFullscreen()]──▶ capturing
                                  │
                                  └──▶ idle (success)
```

---

## Persistence Notes

- **CaptureResult**: Not persisted in this milestone. Will be stored via SwiftData in Milestone 3 for capture history.
- **CaptureConfig**: Derived from Settings (already persisted via UserDefaults in SettingsManager).
- **DisplayInfo**: Runtime only, refreshed from system on each capture.
- **SelectionState/WindowSelection**: Runtime only, ephemeral during capture operation.

---

## Type Mapping

| Entity | Swift Type | Codable | Persistence |
|--------|------------|---------|-------------|
| CaptureMode | enum | No (contains SCWindow/SCDisplay) | None |
| CaptureConfig | struct | Yes | Via Settings |
| CaptureResult | struct | No (contains CGImage) | Future: SwiftData |
| DisplayInfo | struct | No (contains NSScreen) | None |
| SelectionState | @State/class | No | None |
| WindowSelection | class | No | None |
| CaptureError | enum | No | None |
