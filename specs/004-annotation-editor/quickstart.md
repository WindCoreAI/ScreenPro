# Quickstart: Annotation Editor

**Feature**: 004-annotation-editor
**Date**: 2025-12-22

## Prerequisites

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Screen Recording permission granted for ScreenPro

## Build & Run

### 1. Clone and Open Project

```bash
cd /Users/zhiruifeng/Workspace/Wind-Core/ScreenPro
open ScreenPro.xcodeproj
```

### 2. Build the Project

```bash
xcodebuild -scheme ScreenPro -configuration Debug build
```

Or in Xcode: `Product > Build` (⌘B)

### 3. Run the Application

```bash
xcodebuild -scheme ScreenPro -configuration Debug -destination 'platform=macOS' run
```

Or in Xcode: `Product > Run` (⌘R)

## Testing the Annotation Editor

### Open the Editor

1. **Via Capture**: Take a screenshot (⌘⇧4 for area capture)
2. **Via Quick Access**: Click "Annotate" on the Quick Access thumbnail (Milestone 3)
3. The annotation editor window opens with your capture

### Use Annotation Tools

| Tool | Shortcut | Usage |
|------|----------|-------|
| Select | V | Click to select, drag to move |
| Arrow | A | Drag from start to end |
| Rectangle | R | Drag to define bounds |
| Ellipse | O | Drag to define bounds |
| Line | L | Drag from start to end |
| Text | T | Click to place, type to add text |
| Blur | B | Drag to define blur region |
| Pixelate | P | Drag to define pixelate region |
| Highlighter | H | Freeform drag to highlight |
| Counter | N | Click to place numbered circle |
| Crop | C | Drag to define crop region |

### Common Actions

| Action | Shortcut |
|--------|----------|
| Undo | ⌘Z |
| Redo | ⇧⌘Z |
| Save | ⌘S |
| Copy to Clipboard | ⇧⌘C |
| Delete Selection | ⌫ |
| Cancel | ⎋ (Escape) |

### Customization

- **Color**: Click color picker in toolbar
- **Stroke Width**: Click width selector (circles in toolbar)
- **Zoom**: Scroll or pinch on trackpad

## Running Tests

### Unit Tests

```bash
xcodebuild test \
  -scheme ScreenPro \
  -destination 'platform=macOS' \
  -only-testing:ScreenProTests/Unit/AnnotationRenderingTests \
  -only-testing:ScreenProTests/Unit/AnnotationDocumentTests \
  -only-testing:ScreenProTests/Unit/BlurRendererTests
```

### Integration Tests

```bash
xcodebuild test \
  -scheme ScreenPro \
  -destination 'platform=macOS' \
  -only-testing:ScreenProTests/Integration/AnnotationIntegrationTests
```

### All Tests

```bash
xcodebuild test -scheme ScreenPro -destination 'platform=macOS'
```

## Key Files

### Models

| File | Description |
|------|-------------|
| `Features/Annotation/Models/Annotation.swift` | Base protocol + annotation types |
| `Features/Annotation/Models/AnnotationDocument.swift` | Document with undo support |
| `Features/Annotation/Models/AnnotationColor.swift` | Color model |

### Views

| File | Description |
|------|-------------|
| `Features/Annotation/Views/AnnotationCanvasView.swift` | Drawing canvas |
| `Features/Annotation/Views/AnnotationsLayer.swift` | Renders annotations |
| `Features/Annotation/Views/SelectionHandles.swift` | Move/resize handles |

### Toolbar

| File | Description |
|------|-------------|
| `Features/Annotation/Toolbar/AnnotationToolbar.swift` | Main toolbar |
| `Features/Annotation/Toolbar/ColorPickerButton.swift` | Color selection |
| `Features/Annotation/Toolbar/StrokeWidthPicker.swift` | Stroke width |

### Rendering

| File | Description |
|------|-------------|
| `Features/Annotation/Rendering/AnnotationRenderer.swift` | Core Graphics rendering |
| `Features/Annotation/Rendering/BlurRenderer.swift` | Core Image blur |
| `Features/Annotation/Rendering/ExportRenderer.swift` | Final composition |

### Window

| File | Description |
|------|-------------|
| `Features/Annotation/AnnotationEditorWindow.swift` | NSWindow + SwiftUI host |

## Troubleshooting

### Editor doesn't open

1. Verify screen recording permission is granted
2. Check that capture completed successfully (check console for errors)
3. Ensure Quick Access Overlay (Milestone 3) is implemented

### Blur effect not visible

Blur is rendered as a placeholder during editing. The actual blur is applied only during export. Export the image to verify blur is working.

### Undo not working

1. Ensure you're using Cmd+Z (not Ctrl+Z)
2. Check canUndo state in AnnotationDocument
3. Verify undo manager is registered for all operations

### Performance issues with large images

1. 8K images may require reduced zoom level for smooth editing
2. Consider export at lower scale for faster processing
3. Check memory usage in Activity Monitor (target: < 300MB)

## Next Steps

After implementing the Annotation Editor:

1. Run `/speckit.tasks` to generate the implementation task list
2. Integrate with Quick Access Overlay (Milestone 3) for "Annotate" action
3. Update AppCoordinator to handle `.annotating(UUID)` state
4. Connect to StorageService for save operations
