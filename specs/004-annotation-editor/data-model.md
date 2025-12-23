# Data Model: Annotation Editor

**Feature**: 004-annotation-editor
**Date**: 2025-12-22

## Overview

This document defines the data entities for the Annotation Editor feature. Models follow Swift conventions with Codable conformance where serialization is needed. The annotation system uses a protocol-based design allowing polymorphic annotation handling.

---

## Core Entities

### Annotation (Protocol)

Base protocol defining common properties and behaviors for all annotation types.

```text
Annotation
├── id: UUID                      # Unique identifier
├── bounds: CGRect                # Bounding rectangle
├── transform: CGAffineTransform  # Transformation matrix
├── zIndex: Int                   # Layer ordering
├── isSelected: Bool              # Selection state
│
├── render(in: CGContext, scale:) # Draw to context
├── hitTest(_ point:) -> Bool     # Point containment
└── copy() -> Annotation          # Deep copy
```

**Computed Properties**:
- `transformedBounds: CGRect` - Bounds after transform applied

**Relationships**:
- Stored in AnnotationDocument.annotations array
- Rendered by AnnotationRenderer
- Selected/manipulated via canvas gestures

---

### ArrowAnnotation

Arrow with start/end points and optional curved line style.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| id | UUID | auto | Unique identifier |
| bounds | CGRect | calculated | Bounding rectangle |
| transform | CGAffineTransform | .identity | Transform matrix |
| zIndex | Int | 0 | Layer order |
| isSelected | Bool | false | Selection state |
| startPoint | CGPoint | required | Arrow tail position |
| endPoint | CGPoint | required | Arrow head position |
| style | ArrowStyle | default | Head/tail/line style |
| color | AnnotationColor | .red | Stroke color |
| strokeWidth | CGFloat | 3 | Line thickness |

**ArrowStyle**:
```text
ArrowStyle
├── headStyle: HeadStyle  # none, open, filled, circle
├── tailStyle: HeadStyle  # none, open, filled, circle
└── lineStyle: LineStyle  # straight, curved
```

**Validation**:
- startPoint and endPoint must differ by at least 5 points

---

### ShapeAnnotation

Geometric shapes: rectangle, ellipse, or line.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| id | UUID | auto | Unique identifier |
| bounds | CGRect | required | Shape bounds |
| transform | CGAffineTransform | .identity | Transform matrix |
| zIndex | Int | 0 | Layer order |
| isSelected | Bool | false | Selection state |
| shapeType | ShapeType | required | rectangle, ellipse, line |
| fillColor | AnnotationColor? | nil | Fill color (optional) |
| strokeColor | AnnotationColor | .red | Stroke color |
| strokeWidth | CGFloat | 3 | Line thickness |
| cornerRadius | CGFloat | 0 | For rounded rectangles |

**Validation**:
- bounds must be at least 5x5 points

---

### TextAnnotation

Text label with font styling and optional background.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| id | UUID | auto | Unique identifier |
| bounds | CGRect | calculated | Text bounds |
| transform | CGAffineTransform | .identity | Transform matrix |
| zIndex | Int | 0 | Layer order |
| isSelected | Bool | false | Selection state |
| text | String | required | Text content |
| font | AnnotationFont | default | Font configuration |
| textColor | AnnotationColor | .black | Text color |
| backgroundColor | AnnotationColor? | nil | Background color |
| padding | CGFloat | 8 | Internal padding |

**AnnotationFont**:
```text
AnnotationFont
├── name: String         # "SF Pro" default
├── size: CGFloat        # 16 default
└── weight: FontWeight   # regular, medium, semibold, bold
```

**Validation**:
- text must not be empty

---

### BlurAnnotation

Region to be blurred or pixelated on export.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| id | UUID | auto | Unique identifier |
| bounds | CGRect | required | Blur region |
| transform | CGAffineTransform | .identity | Transform matrix |
| zIndex | Int | 0 | Layer order |
| isSelected | Bool | false | Selection state |
| blurType | BlurType | .gaussian | gaussian or pixelate |
| intensity | CGFloat | 0.5 | 0.0 to 1.0 |

**BlurType**:
```text
BlurType
├── gaussian  # Smooth blur effect
└── pixelate  # Mosaic effect
```

**Note**: Blur is rendered as a placeholder rectangle during editing. Actual blur is applied during export.

---

### HighlighterAnnotation

Freeform semi-transparent stroke path.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| id | UUID | auto | Unique identifier |
| bounds | CGRect | calculated | Path bounds |
| transform | CGAffineTransform | .identity | Transform matrix |
| zIndex | Int | 0 | Layer order |
| isSelected | Bool | false | Selection state |
| points | [CGPoint] | required | Stroke path points |
| color | AnnotationColor | .yellow | Highlight color |
| strokeWidth | CGFloat | 20 | Highlight width |

**Rendering**:
- Alpha: 0.4
- Blend mode: multiply
- Line cap/join: round

**Validation**:
- points must have at least 2 elements

---

### CounterAnnotation

Numbered circle callout for step indicators.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| id | UUID | auto | Unique identifier |
| bounds | CGRect | calculated | Circle bounds |
| transform | CGAffineTransform | .identity | Transform matrix |
| zIndex | Int | 0 | Layer order |
| isSelected | Bool | false | Selection state |
| number | Int | required | Display number |
| position | CGPoint | required | Center position |
| color | AnnotationColor | .red | Background color |
| size | CGFloat | 28 | Circle diameter |

**Rendering**:
- Circle background with number text centered
- Text color: white
- Font: bold system font at 50% of size

---

## Supporting Types

### AnnotationColor

Color representation with preset values and CGColor/NSColor conversion.

| Field | Type | Description |
|-------|------|-------------|
| red | CGFloat | 0.0 to 1.0 |
| green | CGFloat | 0.0 to 1.0 |
| blue | CGFloat | 0.0 to 1.0 |
| alpha | CGFloat | 0.0 to 1.0 |

**Presets**:
- red, orange, yellow, green, blue, purple, black, white

**Computed Properties**:
- `cgColor: CGColor` - Core Graphics color
- `nsColor: NSColor` - AppKit color

---

### ToolConfiguration

Current tool settings shared across annotation creation.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| color | AnnotationColor | .red | Current color |
| strokeWidth | CGFloat | 3 | Current stroke width |
| fillEnabled | Bool | false | Whether shapes have fill |
| blurIntensity | CGFloat | 0.5 | Blur tool intensity |
| fontSize | CGFloat | 16 | Text tool font size |
| fontWeight | FontWeight | .regular | Text tool weight |

---

## Document Model

### AnnotationDocument

Container for base image and all annotations with undo support.

| Field | Type | Description |
|-------|------|-------------|
| baseImage | CGImage | Original captured image |
| annotations | [any Annotation] | All annotations |
| selectedAnnotationIds | Set<UUID> | Currently selected |
| canvasSize | CGSize | Canvas dimensions |

**State Management**:
- undoManager: UndoManager for undo/redo

**Computed Properties**:
- `canUndo: Bool` - Whether undo is available
- `canRedo: Bool` - Whether redo is available
- `selectedAnnotations: [any Annotation]` - Currently selected annotations

**Methods**:
```text
addAnnotation(_ annotation:)      # Add with undo
removeAnnotation(id:)             # Remove with undo
updateAnnotation<T>(_ annotation:) # Update with undo
clearAnnotations()                # Remove all with undo
selectAnnotation(at: CGPoint)     # Hit test and select
deselectAll()                     # Clear selection
undo()                            # Undo last action
redo()                            # Redo last undo
render(scale:) -> CGImage?        # Render annotations
renderWithBlur(scale:) -> CGImage? # Render with blur applied
export(format:) -> Data?          # Export to image data
```

---

## Entity Relationships

```text
┌───────────────────────────────────────────────────────────────────┐
│                      AnnotationDocument                            │
│                                                                   │
│  baseImage: CGImage                                               │
│  annotations: [any Annotation]                                    │
│  selectedAnnotationIds: Set<UUID>                                 │
│                                                                   │
│      ┌──────────┬──────────┬──────────┬──────────┬───────────┐   │
│      │  Arrow   │  Shape   │   Text   │   Blur   │ Highlighter│   │
│      │Annotation│Annotation│Annotation│Annotation│ Annotation │   │
│      └────┬─────┴────┬─────┴────┬─────┴────┬─────┴─────┬──────┘   │
│           │          │          │          │           │          │
│           └──────────┴──────────┴──────────┴───────────┘          │
│                              │                                     │
│                    all conform to                                  │
│                     Annotation protocol                            │
└───────────────────────────────────────────────────────────────────┘
                              │
                              │ renders to
                              ▼
                    ┌─────────────────┐
                    │    CGImage      │
                    │  (final export) │
                    └────────┬────────┘
                             │
            ┌────────────────┼────────────────┐
            │                │                │
            ▼                ▼                ▼
    ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
    │ StorageService │ │ NSPasteboard  │ │  CaptureResult │
    │   (save to    │ │  (clipboard)  │ │   (history)   │
    │    disk)      │ │               │ │               │
    └───────────────┘ └───────────────┘ └───────────────┘
```

---

## Tool Types

### AnnotationTool

Enum representing available tools.

```text
AnnotationTool
├── select      # Selection/move tool (V)
├── arrow       # Arrow tool (A)
├── rectangle   # Rectangle shape (R)
├── ellipse     # Ellipse shape (O)
├── line        # Line shape (L)
├── text        # Text tool (T)
├── blur        # Gaussian blur (B)
├── pixelate    # Pixelate blur (P)
├── highlighter # Highlighter (H)
├── counter     # Numbered circle (N)
└── crop        # Crop tool (C)
```

**Properties**:
- `icon: String` - SF Symbol name
- `shortcut: String?` - Keyboard shortcut letter

---

## State Transitions

### Editor State Flow

```text
idle (no annotation in progress)
    │
    ├──[tool selected]────────────────▶ tool selected
    │                                       │
    │                                       ├──[drag start]───▶ creating
    │                                       │                      │
    │                                       │                      ├──[drag end, valid]
    │                                       │                      │      ▼
    │                                       │                      │   add to document
    │                                       │                      │      ▼
    │                                       │                      └───▶ idle
    │                                       │
    │                                       └──[click on annotation]──▶ selected
    │                                                                      │
    │                                                      ┌───────────────┤
    │                                                      │               │
    │                                              [drag annotation]  [delete]
    │                                                      │               │
    │                                                      ▼               ▼
    │                                                  move/resize      idle
    │                                                      │
    │                                                      └───▶ idle
    │
    └──[Cmd+S/Save]──────▶ export ──────▶ idle
    │
    └──[Cancel/Close]────▶ prompt save ──────▶ closed
```

---

## Persistence

| Entity | Codable | Storage | Notes |
|--------|---------|---------|-------|
| AnnotationDocument | No | In-memory | Contains CGImage |
| Annotation types | Partial | Future | Could serialize to JSON for save/restore |
| AnnotationColor | Yes | Via Settings | Color presets |
| ToolConfiguration | Yes | Via Settings | Tool preferences |
| Exported Image | N/A | FileManager | PNG/JPEG/TIFF/HEIC |

**Current Milestone**: No annotation persistence. Document lives in memory until exported or closed.

**Future (Capture History)**: Could serialize annotations to JSON and store with capture history entry for re-editing.

---

## Type Mapping

| Entity | Swift Type | Codable | Persistence |
|--------|------------|---------|-------------|
| Annotation | protocol | No | None |
| ArrowAnnotation | struct | No (CGImage) | None |
| ShapeAnnotation | struct | No | None |
| TextAnnotation | struct | No | None |
| BlurAnnotation | struct | No | None |
| HighlighterAnnotation | struct | No | None |
| CounterAnnotation | struct | No | None |
| AnnotationDocument | class (@MainActor) | No | None |
| AnnotationColor | struct | Yes | Via Settings |
| ToolConfiguration | struct | Yes | Via Settings |
| AnnotationTool | enum | Yes | None |
