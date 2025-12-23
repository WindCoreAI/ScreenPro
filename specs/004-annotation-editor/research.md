# Research: Annotation Editor

**Feature**: 004-annotation-editor
**Date**: 2025-12-22

## Overview

This document captures technical research and decisions for the Annotation Editor feature. All unknowns from the Technical Context have been resolved.

---

## Research Topics

### 1. Annotation Rendering Architecture

**Question**: What is the best approach for rendering annotations on a canvas in macOS?

**Decision**: Use Core Graphics (CGContext) for direct rendering with SwiftUI Canvas view for display.

**Rationale**:
- Core Graphics provides pixel-perfect control over drawing operations
- CGContext supports affine transforms for annotation manipulation (move, resize, rotate)
- SwiftUI Canvas view wraps CGContext for SwiftUI integration
- Matches the approach used in professional image editors like Pixelmator and Affinity

**Alternatives Considered**:
- **NSView with draw(_ rect:)**: More complex, less SwiftUI integration
- **CALayer-based**: Good for animation but overkill for static annotations
- **SwiftUI Shape**: Limited control over complex shapes like arrows with arrowheads

**Implementation Pattern**:
```text
AnnotationCanvasView (SwiftUI)
    └─▶ Canvas { context, size in ... }
            └─▶ context.withCGContext { cgContext in
                    annotation.render(in: cgContext, scale: zoomLevel)
                }
```

---

### 2. Arrow Rendering with Arrowheads

**Question**: How to render arrows with proper arrowhead geometry?

**Decision**: Use CGMutablePath for arrow line with calculated arrowhead points based on angle.

**Rationale**:
- CGMutablePath allows both straight and curved arrows via addLine/addQuadCurve
- Arrowhead angle calculation (atan2) provides directionally correct heads
- Can support multiple head styles (open, filled, circle, none)

**Implementation Pattern**:
```text
Arrow rendering:
1. Calculate angle: atan2(end.y - start.y, end.x - start.x)
2. Draw line path from start to end (straight or curved)
3. Calculate arrowhead points:
   - point1 = end - headLength * cos(angle - headAngle)
   - point2 = end - headLength * cos(angle + headAngle)
4. Draw arrowhead as filled or stroked path
```

**Key Parameters**:
- `headLength`: 15-20 points (scale with stroke width)
- `headAngle`: π/6 (30 degrees) for balanced appearance

---

### 3. Blur/Pixelate Effects

**Question**: How to implement gaussian blur and pixelation that are irreversible on export?

**Decision**: Use CIFilter with CIGaussianBlur and CIPixellate, apply destructively during export.

**Rationale**:
- CIFilter provides GPU-accelerated image processing
- CIGaussianBlur and CIPixellate are built-in filters with good performance
- Applying to the base image during export makes blur irreversible
- Can show preview during editing without modifying original

**Filters to Use**:
| Effect | CIFilter | Key Parameter | Range |
|--------|----------|---------------|-------|
| Gaussian Blur | CIGaussianBlur | inputRadius | 0-40 (intensity × 40) |
| Pixelate | CIPixellate | inputScale | 5-50 (intensity × 45 + 5) |

**Rendering Order**:
```text
Export pipeline:
1. Render base image to CGContext
2. For each BlurAnnotation (in z-order):
   a. Crop region from current image
   b. Apply CIFilter to cropped region
   c. Composite blurred region back onto image
3. Render all other annotations on top
4. Output final CGImage
```

**Security Note**: Blur is applied by replacing pixels in the source image during export. The original unblurred data is never written to the export file.

---

### 4. Undo/Redo Implementation

**Question**: What is the best pattern for undo/redo in a macOS annotation editor?

**Decision**: Use Foundation's UndoManager with closure-based undo registration.

**Rationale**:
- UndoManager is Apple's standard solution, integrates with Cmd+Z automatically
- Closure-based undo captures state snapshots efficiently
- Supports grouping operations (e.g., text editing session)
- Built-in redo stack management

**Implementation Pattern**:
```text
func addAnnotation(_ annotation: Annotation) {
    let previous = annotations
    annotations.append(annotation)

    undoManager.registerUndo(withTarget: self) { doc in
        doc.annotations = previous
    }
}
```

**Best Practices**:
- Register undo before or immediately after state change
- Capture only the minimal state needed for reversal
- Group related operations (e.g., entire text input session)
- Clear undo stack when document is saved/closed if desired

---

### 5. Text Annotation Rendering

**Question**: How to render text annotations with custom fonts and backgrounds?

**Decision**: Use Core Text (CTLine) for precise text rendering within CGContext.

**Rationale**:
- Core Text provides precise control over typography
- CTLine handles attributed strings with font, color, weight
- Can measure text bounds for background sizing
- Better performance than NSAttributedString drawing for real-time updates

**Implementation Pattern**:
```text
1. Create NSAttributedString with font attributes
2. Create CTLine from attributed string
3. Draw optional background rectangle (with padding)
4. Set context text matrix for correct orientation
5. Draw CTLine at calculated position
```

**Text Matrix for Core Graphics**:
```swift
context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
context.textPosition = CGPoint(x: textRect.minX, y: textRect.maxY - font.size)
CTLineDraw(line, context)
```

---

### 6. Selection and Manipulation

**Question**: How to implement selection handles for annotation manipulation?

**Decision**: Overlay selection handles as SwiftUI view elements with drag gestures.

**Rationale**:
- SwiftUI gestures are more responsive than tracking CGContext hit tests
- Separate view layer keeps rendering logic clean
- Can style handles with system accent color
- Corner and edge handles are standard UX pattern

**Handle Layout**:
```text
┌────────────────────────────────────┐
│ ○ (topLeft)      ○ (topRight)      │
│                                    │
│       Selected Annotation          │
│                                    │
│ ○ (bottomLeft)   ○ (bottomRight)   │
└────────────────────────────────────┘

Handles: 8x8pt circles, white fill with accent stroke
Border: 1pt accent color rectangle
```

**Gesture Handling**:
- Drag handle → resize annotation bounds
- Drag annotation body → move entire annotation
- Delete key → remove selected annotation

---

### 7. Highlighter with Blend Mode

**Question**: How to create a highlighter effect that doesn't fully obscure content?

**Decision**: Use CGBlendMode.multiply with reduced alpha (0.4) for highlighter strokes.

**Rationale**:
- Multiply blend mode darkens the background while preserving detail
- Combined with 40% alpha creates natural highlighter effect
- Yellow highlighter over black text remains readable
- Matches physical highlighter behavior

**Key Settings**:
```swift
context.setStrokeColor(color.cgColor.copy(alpha: 0.4)!)
context.setBlendMode(.multiply)
context.setLineCap(.round)
context.setLineJoin(.round)
```

---

### 8. Canvas Zoom and Pan

**Question**: How to implement zoom and pan for the annotation canvas?

**Decision**: Use SwiftUI ScrollView with GeometryReader and scale transforms.

**Rationale**:
- ScrollView provides native pan behavior with momentum
- Scale transform on content provides zoom
- GeometryReader allows coordinate conversion between canvas and screen
- Pinch gesture (if trackpad) can control zoom level

**Coordinate Conversion**:
```swift
// Screen point to canvas point
let canvasPoint = screenPoint.scaled(by: 1.0 / zoomLevel)

// Canvas point to screen point
let screenPoint = canvasPoint.scaled(by: zoomLevel)
```

**Zoom Levels**: 0.25x (25%) to 4.0x (400%), default 1.0x (fit to window)

---

### 9. Export Pipeline

**Question**: How to compose the final image with all annotations and effects?

**Decision**: Create CGContext, draw base image, apply blur regions, render all other annotations.

**Rationale**:
- CGContext provides precise pixel control for export
- Order: base image → blur effects → vector annotations
- Supports multiple output formats via NSBitmapImageRep
- Can scale for different output resolutions

**Export Format Support**:
| Format | NSBitmapImageRep Type | Properties |
|--------|----------------------|------------|
| PNG | .png | Lossless, transparency |
| JPEG | .jpeg | compressionFactor: 0.9 |
| TIFF | .tiff | Lossless |
| HEIC | .heic (via ImageIO) | Lossy, smaller files |

**Export Flow**:
```text
AnnotationDocument.export(format:) → Data
    1. renderWithBlur() → CGImage with blur applied
    2. NSBitmapImageRep(cgImage:)
    3. representation(using: format, properties:)
    4. Return Data for file/clipboard
```

---

## Technology Decisions Summary

| Area | Decision | Framework |
|------|----------|-----------|
| Canvas rendering | Core Graphics + SwiftUI Canvas | Core Graphics |
| Arrow drawing | CGMutablePath with angle calculation | Core Graphics |
| Blur effects | CIGaussianBlur, CIPixellate | Core Image |
| Undo/Redo | UndoManager with closures | Foundation |
| Text rendering | CTLine + NSAttributedString | Core Text |
| Selection handles | SwiftUI overlay with gestures | SwiftUI |
| Highlighter | Multiply blend mode at 40% alpha | Core Graphics |
| Zoom/Pan | ScrollView with scale transform | SwiftUI |
| Export | CGContext → NSBitmapImageRep | Core Graphics, AppKit |

---

## Performance Considerations

| Operation | Target | Strategy |
|-----------|--------|----------|
| Annotation rendering | < 16ms (60fps) | Render only visible, batch draw calls |
| Undo/Redo | < 100ms | Snapshot only changed state |
| Blur preview | < 100ms | Lower resolution preview, full quality on export |
| Export (4K) | < 2s | Background thread for render, main thread for UI |
| Memory (8K image) | < 300MB | Lazy loading, release CGImage after export |

---

## References

- [Core Graphics Programming Guide](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/)
- [Core Image Filter Reference](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Reference/CoreImageFilterReference/)
- [Using the Undo Manager](https://developer.apple.com/documentation/foundation/undomanager)
- [Core Text Programming Guide](https://developer.apple.com/library/archive/documentation/StringsTextFonts/Conceptual/CoreText_Programming/)
