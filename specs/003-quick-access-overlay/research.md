# Research: Quick Access Overlay Implementation

**Feature**: 003-quick-access-overlay
**Date**: 2025-12-22

## Research Summary

Three key technical areas were investigated for the Quick Access Overlay implementation:

1. **Floating NSWindow Configuration** - Window properties for floating overlay behavior
2. **Drag-and-Drop Implementation** - Image drag to external applications
3. **Thumbnail Generation** - Efficient async thumbnail creation from CGImage

---

## 1. Floating NSWindow Configuration

### Decision: Use `.floating` Level with Multi-Space Support

**Rationale**: The Quick Access Overlay must:
- Appear above regular windows but below system menus
- Persist across macOS Spaces (virtual desktops)
- Be draggable without title bar
- Not steal focus from other applications

### Implementation Pattern

```swift
// QuickAccessWindow configuration
level = .floating                           // Above regular windows
isOpaque = false                            // Allow transparency
backgroundColor = .clear                    // Transparent background
hasShadow = true                            // Visual depth
isMovableByWindowBackground = true          // Drag from any area
collectionBehavior = [.canJoinAllSpaces, .stationary]

// Focus behavior
override var canBecomeKey: Bool { true }    // Allow keyboard focus
// Show without activating app
window.orderFront(nil)                      // Not makeKeyAndOrderFront
```

### Alternatives Considered

| Level | Value | Rejected Because |
|-------|-------|------------------|
| `.screenSaver` | 1001 | Too aggressive; would cover Dock/Menu Bar |
| `.popUpMenu` | 101 | Intended for menus, not persistent panels |
| `.normal` | 0 | Would be hidden by other windows |

### Key Properties Reference

| Property | Value | Purpose |
|----------|-------|---------|
| `level` | `.floating` | Float above regular windows |
| `styleMask` | `.borderless` | No title bar |
| `isMovableByWindowBackground` | `true` | Drag anywhere |
| `collectionBehavior` | `[.canJoinAllSpaces, .stationary]` | All Spaces |
| `hasShadow` | `true` | Visual depth |
| `ignoresMouseEvents` | `false` | Receive mouse events |

---

## 2. Drag-and-Drop Implementation

### Decision: AppKit NSDraggingSource with NSItemProvider

**Rationale**: SwiftUI's `.onDrag` modifier has limitations:
- Returns single NSItemProvider only
- No support for NSFilePromiseProvider (Finder)
- Limited control over drag session

AppKit NSDraggingSource provides:
- Multiple data representations for compatibility
- File promises for Finder
- Custom visual feedback

### Implementation Pattern

```swift
// NSViewRepresentable wrapper for SwiftUI integration
struct DraggableThumbnail: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> DragSourceImageView {
        DragSourceImageView(image: image)
    }
}

class DragSourceImageView: NSView, NSDraggingSource {
    override func mouseDown(with event: NSEvent) {
        let pasteboard = NSPasteboard(name: .draggingPasteboard)
        pasteboard.clearContents()

        // Provide multiple formats for app compatibility
        let item = NSPasteboardItem()
        item.setData(image.tiffRepresentation, forType: .tiff)
        item.setData(image.pngData(), forType: NSPasteboard.PasteboardType("public.png"))

        pasteboard.writeObjects([item])

        dragImage(image, at: location, offset: .zero, event: event,
                  pasteboard: pasteboard, source: self, slideBack: true)
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
}
```

### App Compatibility Matrix

| App | TIFF | PNG | NSImage | File URL |
|-----|------|-----|---------|----------|
| Finder | No | No | No | Yes (FilePromise) |
| Slack | Yes | Yes | Yes | Yes |
| Messages | Yes | Yes | Yes | Yes |
| Mail | Yes | Yes | Yes | Yes |
| Pages | Yes | Yes | Yes | Yes |
| Figma | Yes | Yes | Yes | Yes |

### Recommendation

1. **Primary**: Provide TIFF and PNG data representations
2. **Secondary**: For Finder, use NSFilePromiseProvider (on-demand file creation)
3. **SwiftUI Integration**: Wrap AppKit view in NSViewRepresentable

---

## 3. Thumbnail Generation

### Decision: Core Graphics CGContext for In-Memory Images

**Rationale**:
- Captures arrive as CGImage (from ScreenCaptureKit), already in memory
- Core Graphics CGContext is optimal for in-memory downsampling
- CGImageSource better for file-based operations (not our use case)

### Performance Comparison

| API | Time (4K source) | Best For |
|-----|------------------|----------|
| CGImageSource | 16-43ms | File-based thumbnails |
| **Core Graphics** | 50-150ms | In-memory CGImage |
| vImage | 30-50ms | Batch processing |
| NSImage | 600-700ms | Never (too slow) |

### Implementation Pattern

```swift
actor ThumbnailGenerator {
    nonisolated func generateThumbnail(
        from image: CGImage,
        maxPixelSize: Int = 240,
        scaleFactor: CGFloat = 2.0
    ) async -> CGImage? {
        await Task.detached(priority: .userInitiated) {
            self.scaleCGImage(image, maxPixelSize: maxPixelSize)
        }.value
    }

    private nonisolated func scaleCGImage(_ image: CGImage, maxPixelSize: Int) -> CGImage? {
        // Calculate scaled dimensions maintaining aspect ratio
        let sourceWidth = CGFloat(image.width)
        let sourceHeight = CGFloat(image.height)
        let scale = min(1.0, CGFloat(maxPixelSize) / max(sourceWidth, sourceHeight))

        let scaledWidth = Int(sourceWidth * scale)
        let scaledHeight = Int(sourceHeight * scale)

        guard let context = CGContext(
            data: nil,
            width: scaledWidth,
            height: scaledHeight,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: image.bitmapInfo.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))

        return context.makeImage()
    }
}
```

### Retina Display Support

- Capture at physical pixels (e.g., 3840x2160 @ 2x scale)
- Generate thumbnail at physical pixels (e.g., 240px max)
- Wrap in NSImage with logical point size (width / scaleFactor)

### Memory Considerations

| Scenario | Memory |
|----------|--------|
| One 4K capture @ 2x | ~33MB |
| Thumbnail (240px max) | ~600KB |
| 10 thumbnails | ~6MB |
| Queue limit recommendation | 10 items |

---

## Integration Recommendations

### Performance Targets Validation

| Target | Achievable | How |
|--------|------------|-----|
| <200ms overlay appearance | Yes | Async thumbnail, immediate UI |
| 60fps interactions | Yes | SwiftUI/AppKit native |
| <50MB memory (5 captures) | Yes | Limit queue, evict oldest |

### Architecture

1. **CaptureItem** - Holds reference to full CGImage + generated thumbnail
2. **CaptureQueue** - Manages ordered collection, enforces limit
3. **ThumbnailGenerator** - Actor-isolated async generation
4. **QuickAccessWindowController** - Coordinates window + queue
5. **DraggableThumbnail** - NSViewRepresentable for drag support

### Existing Code Integration

- Modify `AppCoordinator.handleCaptureResult()` to route to Quick Access
- Use existing `CaptureResult` as source for `CaptureItem`
- Use existing `CaptureService.save()` and `copyToClipboard()` for actions
- Use existing `SettingsManager.settings.showQuickAccess` to control behavior

---

## Sources

- Apple Developer Documentation: NSWindow, NSDraggingSource, CGContext
- ScreenPro codebase: SelectionWindow.swift, WindowPickerOverlay.swift patterns
- Milestone 3 specification: docs/milestones/03-quick-access-overlay.md
- macOS Human Interface Guidelines: Floating panels and overlays
