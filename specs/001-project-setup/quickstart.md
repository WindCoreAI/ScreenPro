# Quickstart: Project Setup & Core Infrastructure

**Feature**: 001-project-setup
**Date**: 2025-12-22

## Prerequisites

- Xcode 15.0 or later
- macOS 14.0 (Sonoma) or later
- Apple Developer account (for code signing)

## Getting Started

### 1. Create Xcode Project

```bash
# No command needed - create via Xcode
# File → New → Project → macOS → App
```

**Project Settings**:
- Product Name: `ScreenPro`
- Team: Your Apple Developer Team
- Organization Identifier: `com.yourcompany`
- Bundle Identifier: `com.yourcompany.ScreenPro`
- Interface: SwiftUI
- Language: Swift
- Storage: None

### 2. Configure Build Settings

Open project settings and configure:

| Setting | Value |
|---------|-------|
| MACOSX_DEPLOYMENT_TARGET | 14.0 |
| SWIFT_VERSION | 5.9 |
| ENABLE_HARDENED_RUNTIME | YES |
| SWIFT_STRICT_CONCURRENCY | complete |

### 3. Add Info.plist Keys

Add to Info.plist:

```xml
<!-- Hide from Dock -->
<key>LSUIElement</key>
<true/>

<!-- Permission descriptions -->
<key>NSScreenCaptureUsageDescription</key>
<string>ScreenPro needs screen recording permission to capture screenshots and record your screen.</string>

<key>NSMicrophoneUsageDescription</key>
<string>ScreenPro needs microphone access to record audio with your screen recordings.</string>
```

### 4. Configure Entitlements

Create/update `ScreenPro.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    <key>com.apple.security.assets.pictures.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
```

### 5. Create Folder Structure

```bash
# From project root
mkdir -p ScreenPro/Core/Services
mkdir -p ScreenPro/Features/MenuBar
mkdir -p ScreenPro/Features/Settings
mkdir -p ScreenPro/Resources
```

## Building

```bash
# Build for Debug
xcodebuild -scheme ScreenPro -configuration Debug build

# Build for Release
xcodebuild -scheme ScreenPro -configuration Release build
```

## Running

1. Open `ScreenPro.xcodeproj` in Xcode
2. Select the ScreenPro scheme
3. Press ⌘R to run

**First Launch**:
- Menu bar icon appears
- Screen recording permission dialog may appear
- App is hidden from Dock (LSUIElement)

## Testing

```bash
# Run unit tests
xcodebuild -scheme ScreenPro -configuration Debug test
```

## Verification Checklist

After implementation, verify:

- [ ] App launches and shows menu bar icon
- [ ] App does NOT appear in Dock
- [ ] Clicking menu bar icon shows dropdown menu
- [ ] Menu items display correctly (capture, recording sections)
- [ ] Disabled items appear grayed out
- [ ] Settings window opens (Cmd+, or menu item)
- [ ] All 4 settings tabs are visible (General, Capture, Recording, Shortcuts)
- [ ] Permission status shows in General tab
- [ ] Changing settings persists after restart
- [ ] Quit menu item closes app (Cmd+Q)

## Keyboard Shortcuts

Default shortcuts (when implemented):

| Shortcut | Action |
|----------|--------|
| ⌘⇧3 | Capture Fullscreen |
| ⌘⇧4 | Capture Area |
| ⌘⇧5 | All-in-One |
| ⌘⇧6 | Record Screen |
| ⌘, | Open Settings |
| ⌘Q | Quit |

## Troubleshooting

### Menu bar icon not appearing
- Ensure `LSUIElement` is set to `true`
- Check that `MenuBarExtra` is in App body

### Permission dialog not appearing
- Reset permissions: `tccutil reset ScreenCapture com.yourcompany.ScreenPro`
- Ensure ScreenCaptureKit is being accessed on launch

### Settings not persisting
- Check UserDefaults key: `ScreenProSettings`
- Verify Codable conformance on Settings struct

### Shortcuts not working
- Check Carbon.framework is linked
- Verify hotkey registration succeeded (check return status)
- Some shortcuts may conflict with system shortcuts

## Next Steps

After completing Milestone 1, proceed to:
- **Milestone 2**: Basic Screenshot Capture (ScreenCaptureKit integration)
- **Milestone 3**: Quick Access Overlay (floating thumbnail window)
