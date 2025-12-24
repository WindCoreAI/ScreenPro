# ScreenPro

A powerful native macOS application for enhanced screenshot and screen recording, inspired by CleanShot X.

## Features

### Screenshot Capture
- **Area Capture** - Select any region with precision crosshair overlay
- **Window Capture** - Capture specific windows with a visual picker
- **Fullscreen Capture** - Capture entire screen or specific displays
- **Scrolling Capture** - Automatically stitch long content with smart scrolling
- **Self-Timer** - Delayed capture for setup time

### Screen Recording
- **Video Recording** - High-quality MP4/H.264 video capture
- **GIF Recording** - Create animated GIFs with optimized file sizes
- **Audio Support** - Capture microphone and system audio
- **Click Visualization** - Show mouse clicks in recordings
- **Keystroke Overlay** - Display keyboard input on screen
- **Pause/Resume** - Control recording without stopping
- **Video Trimming** - Edit recordings before saving

### Quick Access Overlay
- Floating thumbnail preview after each capture
- One-click copy, save, and annotate actions
- Drag & drop directly to other applications
- Capture queue for multiple screenshots
- Keyboard navigation support
- Configurable position and auto-dismiss

### Annotation Editor
- **Drawing Tools** - Arrow, rectangle, ellipse, line
- **Text Tool** - Add text with customizable styles
- **Blur & Pixelate** - Redact sensitive information
- **Highlighter & Spotlight** - Emphasize important areas
- **Counter Tool** - Add numbered markers
- **Crop Tool** - Resize with aspect ratio presets
- **Undo/Redo** - Full history support
- **Multi-format Export** - PNG, JPEG, and more

### Advanced Features
- **OCR Text Recognition** - Extract text from images using Vision framework
- **Crosshair Magnifier** - Pixel-perfect selection accuracy
- **Screen Freeze** - Freeze screen for easier capture
- **Background Tool** - Create beautiful social media images
- **Camera Overlay** - Picture-in-picture for recordings

## Technology Stack

- **Language**: Swift 5.9+ with strict concurrency
- **UI Framework**: SwiftUI with AppKit integration
- **Minimum macOS**: 14.0 (Sonoma)
- **Key Frameworks**: ScreenCaptureKit, AVFoundation, Vision, Core Image, ImageIO

## Development Status

| Milestone | Status |
|-----------|--------|
| 1. Project Setup & Core Infrastructure | ✅ Complete |
| 2. Basic Screenshot Capture | ✅ Complete |
| 3. Quick Access Overlay | ✅ Complete |
| 4. Annotation Editor | ✅ Complete |
| 5. Screen Recording | ✅ Complete |
| 6. Advanced Features | ✅ Complete |
| 7. Cloud & Polish | 🚧 In Progress |

## Build Instructions

```bash
# Build
xcodebuild -scheme ScreenPro -configuration Debug build

# Run tests
xcodebuild -scheme ScreenPro -configuration Debug test

# Archive for release
xcodebuild -scheme ScreenPro -configuration Release archive
```

## Documentation

Detailed documentation is available in the `/docs` folder:
- [Feature Investigation](./docs/01-feature-investigation.md) - Feature analysis and research
- [UX Design](./docs/02-ux-design.md) - UX patterns and visual guidelines
- [System Architecture](./docs/03-system-architecture.md) - Technical architecture details
- [Milestones Overview](./docs/milestones/00-overview.md) - Development roadmap

## License

Copyright (c) 2024 WindCoreAI. All rights reserved.
