# Quick Start: Quick Access Overlay Implementation

**Feature**: 003-quick-access-overlay
**Date**: 2025-12-22
**Estimated Complexity**: Medium

## Overview

This guide provides a step-by-step approach to implementing the Quick Access Overlay feature. Follow the phases in order; each phase builds on the previous.

---

## Prerequisites

Before starting, ensure:

1. **Milestone 2 Complete**: CaptureService, CaptureResult, and capture flow working
2. **Settings in Place**: `showQuickAccess`, `quickAccessPosition`, `autoDismissDelay` already exist in SettingsManager
3. **Xcode Project**: All source files in ScreenPro target

---

## Phase 1: Core Data Models (Day 1)

### Files to Create

```
ScreenPro/Features/QuickAccess/
├── CaptureItem.swift
└── CaptureQueue.swift
```

### Implementation Order

1. **CaptureItem.swift**
   - Wrapper around CaptureResult
   - Add thumbnail property (optional NSImage)
   - Add computed properties: dimensionsText, timeAgoText

2. **CaptureQueue.swift**
   - ObservableObject with @Published items array
   - Implement add/remove/clear methods
   - Implement selectNext/selectPrevious for keyboard nav

### Verification

```swift
// Unit test: CaptureQueue correctly manages items
func testQueueAddsCaptures() {
    let queue = CaptureQueue()
    let mockResult = CaptureResult(/* mock */)

    queue.add(mockResult)

    XCTAssertEqual(queue.items.count, 1)
    XCTAssertEqual(queue.items[0].id, mockResult.id)
}
```

---

## Phase 2: Window Infrastructure (Day 2)

### Files to Create

```
ScreenPro/Features/QuickAccess/
├── QuickAccessWindow.swift
└── QuickAccessWindowController.swift

ScreenPro/Core/Extensions/
└── VisualEffectView.swift
```

### Implementation Order

1. **VisualEffectView.swift**
   - NSViewRepresentable wrapping NSVisualEffectView
   - Support .hudWindow material

2. **QuickAccessWindow.swift**
   - NSWindow subclass with borderless style
   - Configure: level = .floating, collectionBehavior = [.canJoinAllSpaces, .stationary]
   - Override canBecomeKey to return true

3. **QuickAccessWindowController.swift**
   - Owns CaptureQueue instance
   - Manages window lifecycle (show/hide/position)
   - Handles auto-dismiss timer

### Key Configuration

```swift
// QuickAccessWindow.swift
level = .floating
isOpaque = false
backgroundColor = .clear
hasShadow = true
isMovableByWindowBackground = true
collectionBehavior = [.canJoinAllSpaces, .stationary]
```

### Verification

```swift
// Manual test: Window appears floating and draggable
func testWindowConfiguration() {
    let controller = QuickAccessWindowController(/* deps */)
    controller.show()
    // Verify: Window visible, floating above other windows
    // Verify: Can drag window by background
    // Verify: Persists when switching Spaces
}
```

---

## Phase 3: SwiftUI Views (Day 3-4)

### Files to Create

```
ScreenPro/Features/QuickAccess/
├── QuickAccessContentView.swift
├── QuickAccessItemView.swift
└── DraggableThumbnail.swift
```

### Implementation Order

1. **QuickAccessItemView.swift**
   - Single capture item display
   - Thumbnail + dimensions + timestamp
   - Action buttons on hover
   - Selection highlight for keyboard nav

2. **QuickAccessContentView.swift**
   - VStack of QuickAccessItemView
   - VisualEffectView background
   - Hover to cancel auto-dismiss

3. **DraggableThumbnail.swift**
   - NSViewRepresentable wrapping drag source
   - NSDraggingSource implementation
   - Provide TIFF + PNG data representations

### UI Layout

```
┌─────────────────────────────────────┐
│  ┌─────────────────────────────────┐│
│  │ [Thumbnail] 1920×1080  Just now ││
│  │             [Copy][Save][Edit][X]│
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ [Thumbnail] 3840×2160    2m ago ││
│  │             [Copy][Save][Edit][X]│
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

### Verification

```swift
// SwiftUI Preview testing
struct QuickAccessContentView_Previews: PreviewProvider {
    static var previews: some View {
        QuickAccessContentView(controller: MockController())
    }
}
```

---

## Phase 4: Thumbnail Generation (Day 4)

### Files to Create

```
ScreenPro/Features/QuickAccess/
└── ThumbnailGenerator.swift
```

### Implementation

1. **ThumbnailGenerator.swift**
   - Swift actor for thread-safe async generation
   - Use CGContext for in-memory downsampling
   - Max 240px on longest side
   - Preserve aspect ratio

### Key Pattern

```swift
actor ThumbnailGenerator {
    func generateThumbnail(from image: CGImage, maxPixelSize: Int = 240) async -> CGImage? {
        // Scale using CGContext
        // Return on background queue
    }
}
```

### Verification

```swift
// Performance test: Thumbnail generation under 100ms
func testThumbnailPerformance() async {
    let generator = ThumbnailGenerator()
    let largeImage: CGImage = /* 4K image */

    let start = Date()
    let _ = await generator.generateThumbnail(from: largeImage)
    let elapsed = Date().timeIntervalSince(start)

    XCTAssertLessThan(elapsed, 0.1)
}
```

---

## Phase 5: AppCoordinator Integration (Day 5)

### Files to Modify

```
ScreenPro/Core/AppCoordinator.swift
```

### Changes Required

1. Add `quickAccessController` property
2. Modify `handleCaptureResult()` to route to Quick Access
3. Add `openAnnotationEditor(for:)` placeholder

### Integration Points

```swift
// AppCoordinator.swift additions

private(set) lazy var quickAccessController: QuickAccessWindowController = {
    QuickAccessWindowController(
        settingsManager: settingsManager,
        captureService: captureService,
        coordinator: self
    )
}()

private func handleCaptureResult(_ result: CaptureResult) {
    if settingsManager.settings.showQuickAccess {
        quickAccessController.addCapture(result)
    } else {
        // Existing direct save behavior
    }
    state = .idle
}

func openAnnotationEditor(for result: CaptureResult) {
    // Placeholder for Milestone 4
    // For now, save and open in Preview
    state = .annotating(result.id)
    do {
        let url = try captureService.save(result)
        NSWorkspace.shared.open(url)
    } catch { /* handle */ }
    state = .idle
}
```

### Verification

```swift
// Integration test: Capture triggers Quick Access
func testCaptureShowsQuickAccess() async {
    let coordinator = AppCoordinator()
    coordinator.settingsManager.settings.showQuickAccess = true

    await coordinator.captureFullscreen()

    // Verify: Quick Access overlay is visible
    XCTAssertTrue(coordinator.quickAccessController.isVisible)
}
```

---

## Phase 6: Keyboard Navigation (Day 5-6)

### Files to Modify

```
ScreenPro/Features/QuickAccess/
└── QuickAccessWindow.swift (add keyDown override)
```

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Escape | Dismiss selected |
| Return/Enter | Open in annotator |
| Cmd+C | Copy to clipboard |
| Cmd+S | Save to disk |
| Up/Down | Navigate selection |

### Implementation

```swift
// QuickAccessWindow.swift
override func keyDown(with event: NSEvent) {
    switch event.keyCode {
    case 53: // Escape
        controller?.performActionOnSelected(.dismiss)
    case 36: // Return
        controller?.performActionOnSelected(.annotate)
    case 125: // Down
        controller?.selectNext()
    case 126: // Up
        controller?.selectPrevious()
    default:
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "c": controller?.performActionOnSelected(.copy)
            case "s": controller?.performActionOnSelected(.save)
            default: super.keyDown(with: event)
            }
        } else {
            super.keyDown(with: event)
        }
    }
}
```

---

## Phase 7: Testing & Polish (Day 6-7)

### Test Checklist

- [ ] Overlay appears after any capture type (area, window, fullscreen)
- [ ] Thumbnail displays correctly with dimensions
- [ ] Copy button copies to clipboard
- [ ] Save button saves to configured location
- [ ] Annotate button opens editor (placeholder)
- [ ] Close button dismisses capture
- [ ] Drag to Finder creates PNG file
- [ ] Drag to Messages/Slack pastes image
- [ ] Escape dismisses selected
- [ ] Cmd+C copies selected
- [ ] Arrow keys navigate queue
- [ ] Multiple captures stack correctly
- [ ] Auto-dismiss works when configured
- [ ] Position settings work (all 4 corners)
- [ ] Overlay persists across Spaces

### Performance Verification

- [ ] Overlay appears within 200ms of capture
- [ ] Memory stays under 50MB with 5 captures
- [ ] No main thread blocking during thumbnail generation

---

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Window doesn't appear | Check window level and orderFront call |
| Drag doesn't work in Finder | Add NSFilePromiseProvider |
| Keyboard shortcuts not working | Ensure window is key (canBecomeKey = true) |
| Memory growing | Verify queue eviction at capacity |
| Overlay hidden by fullscreen app | Use .canJoinAllSpaces in collectionBehavior |

---

## Next Steps After Completion

1. Run `/speckit.tasks` to generate detailed task breakdown
2. Create feature branch from main
3. Implement in phase order
4. Test each phase before moving to next
5. Integration test with full capture flow
