# Feature Investigation: Screenshot & Recording Apps

## Executive Summary

This document analyzes the feature sets of leading macOS screenshot and screen recording applications, with CleanShot X as the primary reference implementation. The goal is to identify core features, differentiators, and implementation priorities for ScreenPro.

---

## CleanShot X - Comprehensive Analysis

CleanShot X positions itself as "7 tools in one" and is widely regarded as the most feature-complete screenshot solution for macOS.

### Screenshot Capture Modes

| Mode | Description | Priority |
|------|-------------|----------|
| **Area Capture** | Select rectangular region with crosshair | P0 - Critical |
| **Window Capture** | Click to capture specific window (with/without background) | P0 - Critical |
| **Fullscreen** | Capture entire screen or specific display | P0 - Critical |
| **Scrolling Capture** | Capture content longer than viewport | P1 - High |
| **Self-Timer** | Delayed capture (3-10 seconds) | P2 - Medium |
| **All-In-One Mode** | Single shortcut for all modes with preset dimensions | P1 - High |

### Screenshot Capture Enhancements

- **Crosshair display** - Precision alignment guides
- **Magnifier** - Pixel-level accuracy when selecting
- **Screen freeze** - Capture moving content by freezing display
- **Window detection** - Smart identification of windows, even when layered
- **Hide desktop icons** - Clean background for captures
- **Dimension presets** - Pre-configured sizes (1:1, 16:9, custom)
- **Last selection memory** - Retake previous screenshot area

### Screen Recording

| Feature | Description | Priority |
|---------|-------------|----------|
| **Video Recording** | MP4 H.264 at 480p to 4K, up to 60fps | P0 - Critical |
| **GIF Creation** | Direct recording to animated GIF | P1 - High |
| **Audio - Microphone** | Record voice narration | P0 - Critical |
| **Audio - System** | Capture computer audio (no drivers needed) | P1 - High |
| **Camera Overlay** | Picture-in-picture webcam | P2 - Medium |
| **Click Visualization** | Show mouse clicks with customizable style | P1 - High |
| **Keystroke Display** | Show pressed keys on screen | P1 - High |
| **Recording Timer** | Display elapsed time | P2 - Medium |
| **Pause/Resume** | Interrupt recording without creating new file | P1 - High |
| **Do Not Disturb** | Auto-enable during recording | P2 - Medium |

### Annotation Tools

| Tool | Keyboard Shortcut | Priority |
|------|-------------------|----------|
| **Arrow** | A | P0 - Critical |
| **Rectangle** | R | P0 - Critical |
| **Ellipse** | O | P0 - Critical |
| **Line** | L | P1 - High |
| **Pencil** | P (with auto-smoothing) | P1 - High |
| **Highlighter** | H | P0 - Critical |
| **Text** | T (7 predefined styles) | P0 - Critical |
| **Counter/Numbering** | N (for tutorials) | P1 - High |
| **Pixelate** | - (with randomization) | P0 - Critical |
| **Blur** | - (secure & smooth options) | P0 - Critical |
| **Spotlight** | - (dim surrounding area) | P1 - High |
| **Crop** | C (with aspect ratio & edge snapping) | P0 - Critical |

#### Annotation Enhancements
- **Draw outside bounds** - Canvas auto-expands with transparent background
- **Smart Highlighter** - Auto-detects words, adjusts brush size
- **Multi-image combination** - Stitch multiple screenshots
- **Editable project files** - Non-destructive editing format

### Quick Access Overlay

The cornerstone of CleanShot X's UX - a persistent thumbnail that appears after capture:

- **Position**: Bottom-left corner (configurable)
- **Behaviors**:
  - Stays visible until user interacts
  - Drag & drop to any app
  - Quick actions: Copy, Save, Annotate, Upload
  - Shows capture history queue
- **Keyboard shortcuts** for common actions
- **Remembers multiple captures** in queue

### Background Tool (Social Media)

Transform screenshots into presentation-ready images:
- Add solid color or gradient backgrounds
- Adjust padding and alignment
- Set aspect ratio presets (Twitter, Instagram, etc.)
- Auto-balance for perfect centering
- Shadow and border effects

### OCR (Text Recognition)

- Select any area containing text
- Text copied directly to clipboard
- Fully on-device processing (privacy)
- Supports 20+ languages

### Cloud Integration

- **CleanShot Cloud** - Built-in hosting service
- Instant upload after capture
- Shareable links with expiration
- Password protection
- Custom domains for teams
- Tagging and organization
- Team management features

### Capture History

- Up to 1 month retention
- Browse and search past captures
- Re-access for editing
- Quick Look preview (SPACE)
- Drag & drop from history

---

## Competitive Analysis

### Shottr (Free)

**Strengths:**
- Extremely lightweight (2.3MB)
- Native Apple Silicon optimization
- Fast: 17ms capture, 165ms display
- OCR with ML
- Scrolling capture
- Measurement tools (pixel dimensions)
- Text redaction that preserves image structure

**Weaknesses:**
- No cloud sharing (S3 upload only)
- No video recording
- Limited annotation styles

**Unique Features:**
- Pixel measurement rulers
- "Remove text" that keeps image intact
- Pin screenshots to screen

### Snagit (Paid - Enterprise)

**Strengths:**
- Cross-platform (Mac & Windows)
- Video recording with audio
- Pre-made templates and layouts
- Integration with Microsoft Office, Slack, etc.
- Step tool for numbered tutorials
- Stamps and stickers library

**Weaknesses:**
- Expensive
- Heavier resource usage
- More complex interface

**Unique Features:**
- Template library for documentation
- Batch processing
- Enterprise team features

### Skitch (Free - Deprecated)

**Strengths:**
- Simple and intuitive
- Evernote integration
- Collaboration features

**Weaknesses:**
- No longer maintained
- No scrolling capture
- No OCR
- No video recording

---

## Feature Priority Matrix for ScreenPro

### Phase 1: Core (MVP)

| Feature | Effort | Impact |
|---------|--------|--------|
| Area capture | Low | Critical |
| Window capture | Medium | Critical |
| Fullscreen capture | Low | Critical |
| Quick Access Overlay | Medium | Critical |
| Basic annotations (arrow, rectangle, text) | Medium | Critical |
| Blur/Pixelate | Low | Critical |
| Copy to clipboard | Low | Critical |
| Save to file | Low | Critical |

### Phase 2: Enhanced Capture

| Feature | Effort | Impact |
|---------|--------|--------|
| Scrolling capture | High | High |
| Screen recording (video) | High | High |
| Microphone audio | Medium | High |
| GIF creation | Medium | High |
| Crosshair & magnifier | Medium | Medium |
| Self-timer | Low | Low |

### Phase 3: Professional Tools

| Feature | Effort | Impact |
|---------|--------|--------|
| System audio capture | High | High |
| Camera overlay | Medium | Medium |
| Click/keystroke visualization | Medium | High |
| OCR text recognition | Medium | High |
| Background tool | Medium | Medium |
| Advanced annotation tools | Medium | Medium |

### Phase 4: Cloud & Collaboration

| Feature | Effort | Impact |
|---------|--------|--------|
| Cloud upload | High | High |
| Shareable links | High | High |
| Capture history | Medium | Medium |
| Team features | High | Medium |

---

## Key Differentiators to Consider

1. **Performance** - Shottr proves users value speed (17ms capture)
2. **Simplicity** - CleanShot succeeds by being "invisible" until needed
3. **Quick Access Overlay** - The defining UX pattern for modern screenshot apps
4. **On-device processing** - Privacy-focused OCR and editing
5. **Native macOS feel** - Follow platform conventions

---

## Sources

- [CleanShot X Official](https://cleanshot.com/)
- [CleanShot X Features](https://cleanshot.com/features)
- [Shottr](https://shottr.cc/)
- [XDA Developers - CleanShot Review](https://www.xda-developers.com/cleanshot-x-best-screenshot-tool-macos/)
- [Setapp - CleanShot vs Shottr](https://setapp.com/app-reviews/cleanshot-x-vs-shottr)
- [Screenshot Tools Comparison 2025](https://www.technicalexplore.com/tech/the-ultimate-guide-to-screenshot-apps-for-mac-in-2025-shottr-vs-cleanshot-x-and-beyond)
