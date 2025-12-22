# ScreenPro Documentation

This folder contains research, design, and architecture documentation for ScreenPro - a macOS screenshot and screen recording application.

## Documents

### [01 - Feature Investigation](./01-feature-investigation.md)
Comprehensive analysis of CleanShot X and competitor features including:
- Screenshot capture modes and enhancements
- Screen recording capabilities
- Annotation tools
- Cloud integration
- Competitive analysis (Shottr, Snagit, Skitch)
- Feature priority matrix for implementation phases

### [02 - UX Design](./02-ux-design.md)
User experience patterns and design guidelines covering:
- Quick Access Overlay behavior and interactions
- Capture mode selection interface
- Selection interface (crosshair, magnifier)
- Annotation editor layout
- Recording controls
- Preferences organization
- Menu bar integration
- Visual design guidelines
- Accessibility considerations
- Onboarding flow

### [03 - System Architecture](./03-system-architecture.md)
Technical architecture for macOS implementation including:
- Technology stack (Swift, SwiftUI, ScreenCaptureKit)
- Module breakdown (Capture, Recording, Annotation, etc.)
- ScreenCaptureKit integration patterns
- Recording pipeline (video, audio, GIF)
- Vision framework OCR integration
- Scrolling capture architecture
- Data models and persistence
- File structure
- Security and entitlements
- Performance targets

## Implementation Milestones

Detailed implementation guides are in the [milestones/](./milestones/) folder:

| Milestone | Description | Key Deliverables |
|-----------|-------------|------------------|
| [M1 - Project Setup](./milestones/01-project-setup.md) | Core infrastructure | Xcode project, menu bar, permissions, settings |
| [M2 - Basic Capture](./milestones/02-basic-capture.md) | Screenshot capture | Area, window, fullscreen with ScreenCaptureKit |
| [M3 - Quick Access](./milestones/03-quick-access-overlay.md) | Post-capture UI | Floating overlay, drag & drop, quick actions |
| [M4 - Annotation](./milestones/04-annotation-editor.md) | Image markup | Drawing tools, blur, text, undo/redo |
| [M5 - Recording](./milestones/05-screen-recording.md) | Video & GIF | MP4/GIF, audio capture, click overlay |
| [M6 - Advanced](./milestones/06-advanced-features.md) | Pro features | Scrolling capture, OCR, background tool |
| [M7 - Cloud & Polish](./milestones/07-cloud-polish.md) | Production ready | Cloud upload, history, accessibility |

See [milestones/00-overview.md](./milestones/00-overview.md) for the complete roadmap with dependency graph and success metrics.

## Key Technical Decisions

- **Minimum macOS**: 14.0 (Sonoma) for full ScreenCaptureKit screenshot API
- **UI Framework**: SwiftUI with AppKit integration for system features
- **No External Dependencies**: Using only Apple frameworks
- **Universal Binary**: Apple Silicon + Intel support

## Research Sources

Primary references used in this research:
- [CleanShot X](https://cleanshot.com/) - Feature reference
- [Shottr](https://shottr.cc/) - Performance benchmark
- [Apple ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit/) - Primary capture API
- [Apple Vision Framework](https://developer.apple.com/documentation/vision/) - OCR implementation
