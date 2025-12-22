# UX Design Analysis & Guidelines

## Design Philosophy

ScreenPro should embrace the design philosophy that made CleanShot X successful:

> "Operate almost invisibly except for the Quick Access thumbnails and the Annotation tool"

The app should feel like a natural extension of macOS - present when needed, invisible when not.

---

## Core UX Patterns

### 1. Quick Access Overlay (QAO)

The most important UX innovation in modern screenshot apps. This floating thumbnail is the primary interaction point after capture.

#### Behavior Specifications

```
Position: Bottom-left corner (configurable)
Size: ~120x80px thumbnail
Appear: Immediately after any capture
Persist: Until user interacts or dismisses
Queue: Stack multiple captures vertically
```

#### Interaction States

| State | Appearance | Actions Available |
|-------|------------|-------------------|
| **Idle** | Thumbnail + subtle shadow | Hover to reveal actions |
| **Hover** | Expanded with action buttons | Copy, Save, Annotate, Upload, Close |
| **Drag** | Full-size preview with cursor | Drop into any app |
| **Multiple** | Stacked thumbnails | Select any to bring forward |

#### Quick Actions (Always Visible on Hover)

1. **Copy** (Cmd+C) - Copy to clipboard
2. **Save** (Cmd+S) - Save to default location
3. **Annotate** (Cmd+A) - Open editor
4. **Upload** (Cmd+U) - Upload to cloud
5. **Close** (Esc) - Dismiss without action

#### Keyboard Shortcuts in QAO

| Shortcut | Action |
|----------|--------|
| Enter | Open in annotation editor |
| Space | Quick Look preview |
| Cmd+C | Copy to clipboard |
| Cmd+S | Save to disk |
| Cmd+Shift+S | Save As... |
| Esc | Dismiss |
| Arrow keys | Navigate between queued items |

---

### 2. Capture Mode Selection

#### All-In-One Mode (Recommended Default)

A single keyboard shortcut (e.g., Cmd+Shift+5) opens a capture interface:

```
┌─────────────────────────────────────────────────────────┐
│  ○ Area  ○ Window  ○ Screen  ○ Record  │  Options ▾  │
├─────────────────────────────────────────────────────────┤
│         [Selection area on screen]                      │
│                                                         │
│    ┌─────────────┐                                     │
│    │  800 x 600  │  ← Live dimensions                  │
│    └─────────────┘                                     │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  Cancel          [Capture]              │ Timer: Off   │
└─────────────────────────────────────────────────────────┘
```

#### Individual Mode Shortcuts

| Mode | Suggested Shortcut | Rationale |
|------|-------------------|-----------|
| All-in-One | Cmd+Shift+5 | Matches macOS native |
| Area | Cmd+Shift+4 | Matches macOS native |
| Window | Cmd+Shift+4, Space | Matches macOS native |
| Fullscreen | Cmd+Shift+3 | Matches macOS native |
| Recording | Cmd+Shift+6 | New assignment |

---

### 3. Selection Interface

#### Crosshair Design

```
      ↑
      │
  ←───┼───→     Thin lines (1px)
      │         Color: White with dark border (visibility)
      ↓         Extend to screen edges
```

#### Magnifier (On Option Key)

```
┌─────────────┐
│  ███████    │    Magnification: 4x-8x
│  ███████    │    Size: 100x100px
│  ███████    │    Position: Follow cursor
│─────────────│    Shows:
│  X: 1234    │    - Pixel coordinates
│  Y: 5678    │    - RGB values (optional)
└─────────────┘
```

#### Selection Feedback

- **Dimension display**: Show WxH in center of selection
- **Aspect ratio lock**: Hold Shift to constrain
- **From center**: Hold Option to expand from center
- **Preset dimensions**: Dropdown with common sizes

---

### 4. Annotation Editor

#### Toolbar Design

```
┌────────────────────────────────────────────────────────────────────┐
│  [←] [→]  │  🔍  │  ✏️  🔤  ➡️  ⬜  ⭕  ─  │  🔲  ⚪  │  💾  📋  ↗️  │
│   Undo     Zoom    Pencil Text Arrow Rect Oval Line  Blur Spot  Save Copy Share
└────────────────────────────────────────────────────────────────────┘
```

#### Tool Organization (Left to Right)

1. **History**: Undo/Redo
2. **View**: Zoom controls
3. **Drawing Tools**: Pencil, Text, Arrow, Rectangle, Oval, Line
4. **Privacy Tools**: Blur, Pixelate
5. **Emphasis Tools**: Spotlight, Highlighter, Counter
6. **Actions**: Save, Copy, Share/Upload

#### Property Panel (Context-Sensitive)

Appears when tool selected:

```
┌──────────────────────────────────────────────┐
│  Color: [●] [●] [●] [●] [●] [+]             │
│  Size:  ○──────●────○  (slider)              │
│  Style: [Solid] [Dashed] [Arrow head]        │
└──────────────────────────────────────────────┘
```

#### Canvas Behaviors

- **Infinite canvas**: Allow drawing outside original bounds
- **Auto-expand**: Canvas grows to accommodate annotations
- **Transparent padding**: Clear background when expanded
- **Snap to edges**: Annotations align to screenshot edges
- **Smart guides**: Show alignment when moving objects

---

### 5. Recording Controls

#### Recording Mode UI

```
During Recording:
┌───────────────────────────────────────┐
│  ● REC  00:00:32  │  ⏸️  ⏹️  │  🎤 🔊 │
│                   │         │ Audio  │
└───────────────────────────────────────┘
Position: Top-center of screen (draggable)
```

#### Control States

| Control | Icon | State |
|---------|------|-------|
| Recording | ● | Red pulsing dot |
| Paused | ⏸️ | Yellow, blinking |
| Stopped | ⏹️ | Returns to normal |
| Mic Active | 🎤 | Green indicator |
| System Audio | 🔊 | Blue indicator |

#### Click Visualization Options

```
┌─────────────────────────────────────┐
│  Click Style                        │
│  ○ Circle ripple                    │
│  ○ Solid circle                     │
│  ○ Crosshair                        │
│                                     │
│  Color: [Pick]   Size: [Medium ▾]   │
└─────────────────────────────────────┘
```

---

### 6. Preferences Organization

#### Tab Structure

```
┌───────────────────────────────────────────────────────────────┐
│  [General] [Capture] [Recording] [Annotations] [Shortcuts]   │
│  [Cloud]   [Advanced]                                         │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│           Tab-specific content here                           │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

#### General Tab
- Launch at login
- Menu bar icon options
- Default save location
- File naming pattern
- Notification preferences

#### Capture Tab
- Show crosshair
- Show magnifier
- Capture sound
- Hide desktop icons
- Include cursor
- Default format (PNG, JPG, TIFF)

#### Shortcuts Tab
- Global shortcuts (capture modes)
- Annotation tool shortcuts
- Quick Access shortcuts
- Conflict detection with system

---

### 7. Menu Bar Integration

#### Menu Bar Icon States

| State | Icon | Meaning |
|-------|------|---------|
| Idle | ○ | Ready |
| Capturing | ● | Active capture |
| Recording | ● (red) | Recording in progress |
| Uploading | ↑ | Cloud upload active |

#### Menu Bar Dropdown

```
┌─────────────────────────────────┐
│  Capture Area         ⌘⇧4      │
│  Capture Window       ⌘⇧4 Space│
│  Capture Fullscreen   ⌘⇧3      │
│  ──────────────────────────    │
│  Record Screen        ⌘⇧6      │
│  Record GIF           ⌘⇧G      │
│  ──────────────────────────    │
│  Scrolling Capture    ⌘⇧S      │
│  Text Recognition     ⌘⇧T      │
│  ──────────────────────────    │
│  Open History         ⌘H       │
│  ──────────────────────────    │
│  Preferences...       ⌘,       │
│  Quit                 ⌘Q       │
└─────────────────────────────────┘
```

---

## Visual Design Guidelines

### Color Palette

```
Primary Action:     #007AFF (System Blue)
Destructive:        #FF3B30 (System Red)
Recording:          #FF3B30 (Red)
Success:            #34C759 (System Green)
Warning:            #FF9500 (System Orange)

Background Light:   #FFFFFF
Background Dark:    #1E1E1E
Surface:            #F5F5F5 / #2D2D2D
```

### Typography

- **System Font**: SF Pro (via -apple-system)
- **Monospace** (dimensions): SF Mono
- **Sizes**:
  - Title: 13pt semibold
  - Body: 13pt regular
  - Caption: 11pt regular
  - Dimension overlay: 12pt medium

### Spacing

- **Standard padding**: 12px
- **Compact padding**: 8px
- **Icon size**: 16x16 (toolbar), 20x20 (menu)
- **Thumbnail height**: 80px
- **Corner radius**: 8px (windows), 4px (buttons)

### Shadows

```
Quick Access Overlay:
  box-shadow: 0 4px 12px rgba(0,0,0,0.15),
              0 0 1px rgba(0,0,0,0.1);

Floating Window:
  box-shadow: 0 8px 24px rgba(0,0,0,0.2),
              0 0 1px rgba(0,0,0,0.1);
```

---

## Accessibility Considerations

### Keyboard Navigation

- Full keyboard access to all features
- Focus indicators for all interactive elements
- Escape always dismisses/cancels
- Tab order follows visual layout

### VoiceOver Support

- All buttons have accessible labels
- Announce capture results
- Describe annotation tools
- Navigate history with arrows

### Visual Accessibility

- Minimum 4.5:1 contrast ratio
- Don't rely solely on color
- Support reduced motion preference
- Respect increased contrast setting

### Customization

- Configurable cursor size during selection
- Optional sound feedback
- Adjustable overlay opacity
- Custom shortcut support

---

## Onboarding Flow

### First Launch

1. **Welcome screen** with key features
2. **Permission request** (Screen Recording)
3. **Shortcut preference** - Use macOS defaults or custom
4. **Quick tutorial** - 3-step capture demo
5. **Ready state** - Show menu bar icon

### Permission Denied Handling

```
┌────────────────────────────────────────────┐
│  ⚠️ Screen Recording Permission Required   │
│                                            │
│  ScreenPro needs permission to capture     │
│  your screen.                              │
│                                            │
│  1. Open System Preferences               │
│  2. Go to Privacy & Security              │
│  3. Enable ScreenPro                      │
│                                            │
│  [Open System Preferences]    [Later]     │
└────────────────────────────────────────────┘
```

---

## Sources

- [CleanShot X Features](https://cleanshot.com/features)
- [CleanShot UX Patterns - Alchemists](https://alchemists.io/articles/clean_shot)
- [CleanShot User Flow - Page Flows](https://pageflows.com/web/products/cleanshot/)
- [macOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
- [Shottr - Pixel Professionals](https://shottr.cc/)
