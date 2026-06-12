# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ScreenPro is a native macOS application for enhanced screenshot and screen recording, inspired by CleanShot X. The app provides area/window/fullscreen capture, screen recording with audio, GIF creation, annotation tools, OCR, and cloud sharing.

## Technology Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI with AppKit integration
- **Minimum macOS**: 14.0 (Sonoma)
- **Key Frameworks**: ScreenCaptureKit, AVFoundation, Vision, Core Image, ImageIO

## Documentation

Detailed research and design documents are in `/docs`:
- `01-feature-investigation.md` - Feature analysis and competitive research
- `02-ux-design.md` - UX patterns and visual design guidelines
- `03-system-architecture.md` - Technical architecture and implementation details

## Architecture Overview

The app follows a modular architecture with these core components:

- **AppCoordinator**: Central state machine managing app flow
- **CaptureService**: Screenshot capture using ScreenCaptureKit
- **RecordingService**: Video/GIF recording with audio support
- **QuickAccessOverlay**: Floating thumbnail for post-capture actions
- **AnnotationEditor**: Full-featured image markup editor
- **StorageService**: Capture history and file management

## Build Commands

```bash
# Build (when Xcode project exists)
xcodebuild -scheme ScreenPro -configuration Debug build

# Run tests
xcodebuild -scheme ScreenPro -configuration Debug test

# Archive for release
xcodebuild -scheme ScreenPro -configuration Release archive
```

## Key Implementation Notes

- All screen capture uses ScreenCaptureKit (not deprecated CGWindowListCreateImage)
- OCR uses Vision framework with on-device processing
- GIF encoding uses ImageIO with CGImageDestination
- System audio capture uses ScreenCaptureKit's audio features (no drivers needed)
- Global shortcuts require accessibility permissions for some features

## Active Technologies
- Swift 5.9+ with strict concurrency checking enabled + SwiftUI (UI), AppKit (NSStatusItem, NSWindow), ScreenCaptureKit (permission detection), AVFoundation (microphone permission), Carbon (global hotkeys) (001-project-setup)
- UserDefaults for settings persistence (SwiftData deferred to later milestone for capture history) (001-project-setup)
- Swift 5.9+ with strict concurrency checking enabled + ScreenCaptureKit, AppKit, SwiftUI, Core Graphics, Core Image (002-basic-capture)
- FileManager (user-configured save location), NSPasteboard (clipboard) (002-basic-capture)
- Swift 5.9+ with strict concurrency checking enabled + SwiftUI (views), AppKit (NSWindow, NSPasteboard, NSDraggingSource), Core Graphics (thumbnail generation) (003-quick-access-overlay)
- In-memory queue (no persistence - captures discarded on dismiss) (003-quick-access-overlay)
- Swift 5.9+ with strict concurrency checking enabled + SwiftUI, AppKit (NSWindow, NSImage), Core Graphics, Core Image, Core Tex (004-annotation-editor)
- In-memory during editing, export to FileManager via StorageService, clipboard via NSPasteboard (004-annotation-editor)
- Swift 5.9+ with strict concurrency checking enabled + ScreenCaptureKit, AVFoundation, ImageIO, AppKit, SwiftUI, Core Graphics (005-screen-recording)
- FileManager for recordings, UserDefaults for settings (via existing SettingsManager) (005-screen-recording)
- Swift 5.9+ with strict concurrency checking enabled + ScreenCaptureKit (capture), Vision (OCR, image registration), AVFoundation (camera, recording), Core Graphics (image processing), Core Image (effects), ImageIO (export), SwiftUI + AppKi (006-advanced-features)
- In-memory during editing; FileManager for export via StorageService (006-advanced-features)
- Swift 5.9+ with strict concurrency checking enabled + SwiftData (capture history persistence), URLSession (cloud upload), os.signpost (performance instrumentation), SwiftUI + AppKit (history browser, onboarding windows) (007-cloud-polish)
- SwiftData for capture history; UserDefaults (via SettingsManager) for cloud/history/onboarding settings with migration-tolerant decoding (007-cloud-polish)
- Swift 5.9+, strict concurrency checking enabled + ScreenCaptureKit (existing stream), AVFoundation (AVAudioEngine), Speech (SFSpeechRecognizer — new framework, Apple-native), Carbon (existing ShortcutManager), SwiftUI + AppKit (summary window, note field), Core Graphics / ImageIO (PNG screenshots), Foundation `JSONEncoder` (manifest) (008-review-recording)
- FileManager bundle folder under `settings.defaultSaveLocation`; SwiftData capture-history entry (existing store); settings via existing `SettingsManager` (UserDefaults) (008-review-recording)

## Recent Changes
- 008-review-recording: Added Review Recording mode — flag moments during a screen recording via session-scoped global hotkey (⌃⌥F) or controls button, on-device speech transcription (SFSpeechRecognizer, never server) turning spoken observations into review notes with screenshots extracted from the live stream (ReviewFrameBuffer ring), MicrophoneAudioHub (single AVAudioEngine tap fanned out to the mic track and the recognizer), skippable post-stop summary editor, and a Review Report bundle (recording.mp4 + screenshots/ + report.md + report.json manifest, schema v1) designed to feed agentic coding workflows; plus Review settings tab and speech permission handling
- 007-cloud-polish: Added CloudService (multipart upload, shareable links with expiry/password, delete tokens), capture history (SwiftData store + browser window with search/filter/grid/list/drag-out), Quick Access upload action (⌘U), onboarding flow, Cloud settings tab, accessibility support (VoiceOver announcer, keyboard navigation, Reduce Motion), performance monitoring (signposts, memory-pressure handling), and tolerant Settings decoding so upgrades no longer reset preferences
- 003-quick-access-overlay: Implemented Quick Access overlay feature with floating thumbnail preview, copy/save/annotate/dismiss actions, drag-and-drop to external apps, keyboard navigation, position configuration, and auto-dismiss
- 002-basic-capture: Added area/window/fullscreen capture with ScreenCaptureKit integration
- 001-project-setup: Added Swift 5.9+ with strict concurrency checking enabled + SwiftUI (UI), AppKit (NSStatusItem, NSWindow), ScreenCaptureKit (permission detection), AVFoundation (microphone permission), Carbon (global hotkeys)
