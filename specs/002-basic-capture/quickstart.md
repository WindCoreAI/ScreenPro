# Quickstart: Basic Screenshot Capture

**Feature**: 002-basic-capture
**Date**: 2025-12-22

## Prerequisites

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Milestone 1 (001-project-setup) completed

## Build & Run

### 1. Open Project

```bash
cd /Users/zhiruifeng/Workspace/Wind-Core/ScreenPro
open ScreenPro.xcodeproj
```

### 2. Build

```bash
xcodebuild -scheme ScreenPro -configuration Debug build
```

Or use Xcode: Product → Build (⌘B)

### 3. Run

```bash
xcodebuild -scheme ScreenPro -configuration Debug -destination 'platform=macOS' run
```

Or use Xcode: Product → Run (⌘R)

### 4. Grant Permission

On first capture attempt:
1. System will prompt for Screen Recording permission
2. Open System Settings → Privacy & Security → Screen Recording
3. Enable ScreenPro
4. Restart the app for permission to take effect

## Testing Capture Features

### Area Capture

1. Click menu bar icon → "Capture Area" (or use shortcut ⌘⇧4)
2. Click and drag to select region
3. Release to capture
4. Verify: Image saved to Pictures/ScreenPro folder and copied to clipboard

### Window Capture

1. Click menu bar icon → "Capture Window" (or use shortcut ⌘⇧4 + Space)
2. Hover over windows to see highlight
3. Click to capture
4. Verify: Window image saved and copied to clipboard

### Fullscreen Capture

1. Click menu bar icon → "Capture Fullscreen" (or use shortcut ⌘⇧3)
2. Immediate capture of main display
3. Verify: Full display image saved and copied to clipboard

### Cancel Capture

- During area/window selection, press Escape to cancel

## Verification Checklist

- [ ] Menu bar icon appears on launch
- [ ] Area selection overlay shows crosshair and dimensions
- [ ] Window picker highlights hovered windows
- [ ] Fullscreen capture works without selection UI
- [ ] Capture sound plays (if enabled in settings)
- [ ] Images saved to configured location
- [ ] Images available in clipboard (paste into Preview.app)
- [ ] Escape cancels selection modes
- [ ] Multi-monitor: selection works on all displays

## Run Tests

```bash
xcodebuild -scheme ScreenPro -configuration Debug test
```

### Expected Test Coverage

- CaptureService unit tests (crop, coordinate conversion)
- Integration tests for capture workflows

## Troubleshooting

### Permission Denied

If captures fail with permission error:
1. Check System Settings → Privacy & Security → Screen Recording
2. Ensure ScreenPro is enabled
3. Restart the app

### Blank/Black Images

If captured images are blank:
1. Verify screen recording permission is granted
2. Check if the content being captured allows recording
3. Some apps (DRM content, secure input) may block capture

### Wrong Resolution

If images appear wrong size:
1. Check Retina scaling in settings
2. Verify display configuration in System Settings → Displays

## Development Notes

### Key Files

| File | Purpose |
|------|---------|
| `Features/Capture/CaptureService.swift` | Core capture logic |
| `Features/Capture/SelectionOverlay/SelectionWindow.swift` | Area selection UI |
| `Features/Capture/WindowPicker/WindowPickerController.swift` | Window selection |
| `Core/AppCoordinator.swift` | Capture flow integration |

### Debug Logging

Enable verbose logging by setting environment variable:
```
SCREENPRO_DEBUG=1
```

### Common Issues

1. **Selection overlay doesn't appear**: Check window level and collection behavior
2. **Window highlight missing**: Verify NSWindow configuration
3. **Capture delayed**: Check async/await chain for blocking calls
