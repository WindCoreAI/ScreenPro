# Data Model: Quick Access Overlay

**Feature**: 003-quick-access-overlay
**Date**: 2025-12-22

## Overview

The Quick Access Overlay feature introduces three new data entities to manage capture queuing and overlay behavior. These entities integrate with the existing `CaptureResult` and `Settings` models.

---

## Entity Relationship Diagram

```
┌─────────────────────┐
│   CaptureResult     │  (existing)
│   ─────────────     │
│   id: UUID          │
│   image: CGImage    │
│   mode: CaptureMode │
│   timestamp: Date   │
│   sourceRect: CGRect│
│   scaleFactor: CGFloat
└─────────┬───────────┘
          │ creates
          ▼
┌─────────────────────┐         ┌─────────────────────┐
│    CaptureItem      │◄────────│    CaptureQueue     │
│    ───────────      │  manages │    ────────────     │
│    id: UUID         │         │    items: [CaptureItem]
│    result: CaptureResult      │    selectedIndex: Int
│    thumbnail: NSImage│        │    maxVisibleItems: Int
│    createdAt: Date  │         └─────────────────────┘
│    dimensions: CGSize│
└─────────────────────┘

┌─────────────────────┐
│  QuickAccessPosition│  (existing enum in Settings)
│  ──────────────────│
│  bottomLeft         │
│  bottomRight        │
│  topLeft            │
│  topRight           │
└─────────────────────┘

┌─────────────────────┐
│    Settings         │  (existing, relevant fields)
│    ────────         │
│    showQuickAccess: Bool
│    quickAccessPosition: QuickAccessPosition
│    autoDismissDelay: TimeInterval
└─────────────────────┘
```

---

## Entity Definitions

### CaptureItem

Represents a single capture in the Quick Access queue.

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `id` | `UUID` | Unique identifier | Inherited from CaptureResult |
| `result` | `CaptureResult` | Original capture data | Required |
| `thumbnail` | `NSImage` | Scaled preview image | Generated async, max 300px |
| `createdAt` | `Date` | When added to queue | Set on creation |
| `dimensions` | `CGSize` | Original image size in pixels | From result.pixelSize |

**Lifecycle**:
1. Created when `CaptureResult` is received
2. Thumbnail generated asynchronously
3. Removed when user performs action (Copy/Save/Annotate/Dismiss)

**Computed Properties**:
- `dimensionsText: String` - Formatted as "1920 × 1080"
- `timeAgoText: String` - Relative time ("Just now", "2m ago")
- `nsImage: NSImage` - Full-resolution image from result

### CaptureQueue

Manages the ordered collection of pending captures.

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| `items` | `[CaptureItem]` | Ordered captures (newest first) | `[]` |
| `selectedIndex` | `Int` | Currently selected item index | `0` |
| `maxVisibleItems` | `Int` | Max items displayed before scroll | `5` |
| `maxQueueSize` | `Int` | Max items before oldest evicted | `10` |

**Operations**:
| Operation | Description |
|-----------|-------------|
| `add(_ result: CaptureResult)` | Insert at front, evict oldest if at capacity |
| `remove(_ id: UUID)` | Remove specific item |
| `clear()` | Remove all items |
| `selectNext()` | Move selection down |
| `selectPrevious()` | Move selection up |
| `selected: CaptureItem?` | Currently selected item |

**State Transitions**:
```
Empty ──add──▶ HasItems
HasItems ──add──▶ HasItems (insert at front)
HasItems ──remove last──▶ Empty
HasItems ──remove──▶ HasItems (adjust selectedIndex)
```

### QuickAccessPosition (Existing)

Already defined in `SettingsManager.swift`. No changes needed.

```swift
enum QuickAccessPosition: String, Codable, CaseIterable {
    case bottomLeft
    case bottomRight
    case topLeft
    case topRight
}
```

---

## Validation Rules

### CaptureItem

| Rule | Validation |
|------|------------|
| ID uniqueness | Each item must have unique UUID |
| Thumbnail size | Max 300px on longest side |
| Memory limit | Queue limited to 10 items |

### CaptureQueue

| Rule | Validation |
|------|------------|
| Index bounds | selectedIndex must be 0..<items.count or 0 if empty |
| Capacity | items.count <= maxQueueSize |
| Order | Newest items at front (index 0) |

---

## Integration with Existing Models

### CaptureResult (Existing)

The `CaptureItem` wraps `CaptureResult` to add queue-specific properties:

```swift
// Existing CaptureResult provides:
let id: UUID
let image: CGImage        // Full resolution
let mode: CaptureMode
let timestamp: Date
let sourceRect: CGRect
let scaleFactor: CGFloat

// Computed (existing):
var nsImage: NSImage
var pixelSize: CGSize
var pointSize: CGSize
```

### Settings (Existing)

Quick Access settings already defined in `SettingsManager.swift`:

```swift
// Quick Access Settings (lines 111-113)
var showQuickAccess: Bool = true
var quickAccessPosition: QuickAccessPosition = .bottomLeft
var autoDismissDelay: TimeInterval = 0  // 0 = disabled
```

---

## Memory Considerations

| Entity | Size Estimate | Notes |
|--------|---------------|-------|
| CaptureItem (thumbnail only) | ~600KB | At 240px max |
| CaptureItem (with full result) | ~33MB | 4K image |
| CaptureQueue (5 items) | ~165MB | Full-res images |
| CaptureQueue (10 items) | ~330MB | At capacity |

**Mitigation**: Queue evicts oldest items when capacity reached. Thumbnails generated at reduced resolution.

---

## Swift Type Definitions

```swift
/// Represents a single capture in the Quick Access queue
struct CaptureItem: Identifiable {
    let id: UUID
    let result: CaptureResult
    var thumbnail: NSImage?  // Generated asynchronously
    let createdAt: Date

    var dimensions: CGSize { result.pixelSize }
    var nsImage: NSImage { result.nsImage }

    var dimensionsText: String {
        "\(Int(dimensions.width)) × \(Int(dimensions.height))"
    }

    var timeAgoText: String {
        // Computed relative time
    }
}

/// Manages ordered collection of pending captures
@MainActor
final class CaptureQueue: ObservableObject {
    @Published private(set) var items: [CaptureItem] = []
    @Published var selectedIndex: Int = 0

    let maxVisibleItems: Int = 5
    let maxQueueSize: Int = 10

    var isEmpty: Bool { items.isEmpty }
    var selected: CaptureItem? {
        guard selectedIndex < items.count else { return nil }
        return items[selectedIndex]
    }

    func add(_ result: CaptureResult) { /* ... */ }
    func remove(_ id: UUID) { /* ... */ }
    func clear() { /* ... */ }
    func selectNext() { /* ... */ }
    func selectPrevious() { /* ... */ }
}
```
