# Milestone 3: Quick Access Overlay

## Overview

**Goal**: Implement the floating thumbnail overlay that appears after capture, providing quick actions and drag-and-drop functionality.

**Prerequisites**: Milestone 2 completed

---

## Deliverables

| Deliverable | Description | Priority |
|-------------|-------------|----------|
| QuickAccessWindow | Floating NSWindow for overlay | P0 |
| ThumbnailView | Capture preview with actions | P0 |
| Drag & Drop | Export to other apps | P0 |
| Action Buttons | Copy, Save, Annotate, Close | P0 |
| Capture Queue | Multiple capture management | P1 |
| Keyboard Navigation | Shortcuts for actions | P1 |
| Position Management | Configurable corner position | P2 |

---

## Implementation Tasks

### 3.1 Implement Quick Access Window

**Task**: Create floating window controller

**File**: `Features/QuickAccess/QuickAccessWindowController.swift`

```swift
import AppKit
import SwiftUI
import Combine

@MainActor
final class QuickAccessWindowController: NSObject, ObservableObject {
    // MARK: - Properties

    @Published private(set) var captures: [CaptureItem] = []
    @Published private(set) var selectedIndex: Int = 0

    private var window: QuickAccessWindow?
    private var cancellables = Set<AnyCancellable>()

    private let settingsManager: SettingsManager
    private weak var coordinator: AppCoordinator?

    // MARK: - Capture Item

    struct CaptureItem: Identifiable {
        let id: UUID
        let result: CaptureService.CaptureResult
        let thumbnail: NSImage
        let timestamp: Date

        init(result: CaptureService.CaptureResult) {
            self.id = result.id
            self.result = result
            self.thumbnail = Self.createThumbnail(from: result.nsImage)
            self.timestamp = result.timestamp
        }

        private static func createThumbnail(from image: NSImage, maxSize: CGFloat = 300) -> NSImage {
            let aspectRatio = image.size.width / image.size.height
            let thumbnailSize: NSSize

            if aspectRatio > 1 {
                thumbnailSize = NSSize(width: maxSize, height: maxSize / aspectRatio)
            } else {
                thumbnailSize = NSSize(width: maxSize * aspectRatio, height: maxSize)
            }

            let thumbnail = NSImage(size: thumbnailSize)
            thumbnail.lockFocus()
            image.draw(
                in: NSRect(origin: .zero, size: thumbnailSize),
                from: NSRect(origin: .zero, size: image.size),
                operation: .copy,
                fraction: 1.0
            )
            thumbnail.unlockFocus()

            return thumbnail
        }
    }

    // MARK: - Initialization

    init(settingsManager: SettingsManager, coordinator: AppCoordinator) {
        self.settingsManager = settingsManager
        self.coordinator = coordinator
        super.init()
    }

    // MARK: - Public Methods

    func addCapture(_ result: CaptureService.CaptureResult) {
        let item = CaptureItem(result: result)
        captures.insert(item, at: 0)
        selectedIndex = 0

        showWindow()
        setupAutoDismiss()
    }

    func removeCapture(_ id: UUID) {
        captures.removeAll { $0.id == id }

        if captures.isEmpty {
            hideWindow()
        } else if selectedIndex >= captures.count {
            selectedIndex = captures.count - 1
        }
    }

    func clearAll() {
        captures.removeAll()
        hideWindow()
    }

    // MARK: - Actions

    func copyToClipboard(_ item: CaptureItem) {
        coordinator?.captureService.copyToClipboard(item.result)
        removeCapture(item.id)
    }

    func saveToFile(_ item: CaptureItem) {
        do {
            _ = try coordinator?.captureService.save(item.result)
            removeCapture(item.id)
        } catch {
            // Show error
            NSAlert(error: error).runModal()
        }
    }

    func openInAnnotator(_ item: CaptureItem) {
        coordinator?.openAnnotationEditor(for: item.result)
        removeCapture(item.id)
    }

    func dismiss(_ item: CaptureItem) {
        removeCapture(item.id)
    }

    // MARK: - Window Management

    private func showWindow() {
        if window == nil {
            createWindow()
        }

        updateWindowPosition()
        window?.orderFront(nil)
    }

    private func hideWindow() {
        window?.orderOut(nil)
    }

    private func createWindow() {
        let window = QuickAccessWindow(controller: self)
        self.window = window
    }

    private func updateWindowPosition() {
        guard let window = window, let screen = NSScreen.main else { return }

        let padding: CGFloat = 20
        let windowSize = window.frame.size
        let screenFrame = screen.visibleFrame

        let origin: NSPoint

        switch settingsManager.settings.quickAccessPosition {
        case .bottomLeft:
            origin = NSPoint(
                x: screenFrame.minX + padding,
                y: screenFrame.minY + padding
            )
        case .bottomRight:
            origin = NSPoint(
                x: screenFrame.maxX - windowSize.width - padding,
                y: screenFrame.minY + padding
            )
        case .topLeft:
            origin = NSPoint(
                x: screenFrame.minX + padding,
                y: screenFrame.maxY - windowSize.height - padding
            )
        case .topRight:
            origin = NSPoint(
                x: screenFrame.maxX - windowSize.width - padding,
                y: screenFrame.maxY - windowSize.height - padding
            )
        }

        window.setFrameOrigin(origin)
    }

    // MARK: - Auto Dismiss

    private var autoDismissTask: Task<Void, Never>?

    private func setupAutoDismiss() {
        autoDismissTask?.cancel()

        let delay = settingsManager.settings.autoDismissDelay
        guard delay > 0 else { return }

        autoDismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            if !Task.isCancelled {
                clearAll()
            }
        }
    }

    func cancelAutoDismiss() {
        autoDismissTask?.cancel()
    }

    // MARK: - Keyboard Navigation

    func selectNext() {
        if selectedIndex < captures.count - 1 {
            selectedIndex += 1
        }
    }

    func selectPrevious() {
        if selectedIndex > 0 {
            selectedIndex -= 1
        }
    }

    func performActionOnSelected(_ action: Action) {
        guard selectedIndex < captures.count else { return }
        let item = captures[selectedIndex]

        switch action {
        case .copy:
            copyToClipboard(item)
        case .save:
            saveToFile(item)
        case .annotate:
            openInAnnotator(item)
        case .dismiss:
            dismiss(item)
        }
    }

    enum Action {
        case copy, save, annotate, dismiss
    }
}
```

---

### 3.2 Implement Quick Access Window

**Task**: Create the floating NSWindow

**File**: `Features/QuickAccess/QuickAccessWindow.swift`

```swift
import AppKit
import SwiftUI

final class QuickAccessWindow: NSWindow {
    private weak var controller: QuickAccessWindowController?

    init(controller: QuickAccessWindowController) {
        self.controller = controller

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Window configuration
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]

        // Content
        let contentView = QuickAccessContentView(controller: controller)
        self.contentView = NSHostingView(rootView: contentView)

        // Size to fit content
        setContentSize(NSSize(width: 320, height: calculateHeight()))
    }

    private func calculateHeight() -> CGFloat {
        guard let controller = controller else { return 200 }
        let itemHeight: CGFloat = 100
        let padding: CGFloat = 16
        let maxItems = 5

        let visibleItems = min(controller.captures.count, maxItems)
        return CGFloat(visibleItems) * itemHeight + padding * 2
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53:  // Escape
            controller?.performActionOnSelected(.dismiss)
        case 36:  // Return
            controller?.performActionOnSelected(.annotate)
        case 49:  // Space
            // Quick Look preview
            break
        case 125: // Down arrow
            controller?.selectNext()
        case 126: // Up arrow
            controller?.selectPrevious()
        default:
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers {
                case "c":
                    controller?.performActionOnSelected(.copy)
                case "s":
                    controller?.performActionOnSelected(.save)
                default:
                    super.keyDown(with: event)
                }
            } else {
                super.keyDown(with: event)
            }
        }
    }
}
```

---

### 3.3 Implement Quick Access Content View

**Task**: Create SwiftUI content view

**File**: `Features/QuickAccess/QuickAccessContentView.swift`

```swift
import SwiftUI

struct QuickAccessContentView: View {
    @ObservedObject var controller: QuickAccessWindowController

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(controller.captures.enumerated()), id: \.element.id) { index, item in
                QuickAccessItemView(
                    item: item,
                    isSelected: index == controller.selectedIndex,
                    onCopy: { controller.copyToClipboard(item) },
                    onSave: { controller.saveToFile(item) },
                    onAnnotate: { controller.openInAnnotator(item) },
                    onDismiss: { controller.dismiss(item) }
                )
            }
        }
        .padding(12)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onHover { hovering in
            if hovering {
                controller.cancelAutoDismiss()
            }
        }
    }
}

struct QuickAccessItemView: View {
    let item: QuickAccessWindowController.CaptureItem
    let isSelected: Bool
    let onCopy: () -> Void
    let onSave: () -> Void
    let onAnnotate: () -> Void
    let onDismiss: () -> Void

    @State private var isHovering = false
    @State private var isDragging = false

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail (draggable)
            DraggableThumbnail(item: item, isDragging: $isDragging)
                .frame(width: 80, height: 60)

            // Info & Actions
            VStack(alignment: .leading, spacing: 4) {
                Text(dimensionsText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)

                Text(timeAgoText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                // Action buttons (visible on hover)
                if isHovering {
                    HStack(spacing: 8) {
                        ActionButton(icon: "doc.on.doc", tooltip: "Copy") {
                            onCopy()
                        }
                        ActionButton(icon: "square.and.arrow.down", tooltip: "Save") {
                            onSave()
                        }
                        ActionButton(icon: "pencil", tooltip: "Annotate") {
                            onAnnotate()
                        }
                    }
                }
            }

            Spacer()

            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0.5)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var dimensionsText: String {
        let width = item.result.image.width
        let height = item.result.image.height
        return "\(width) × \(height)"
    }

    private var timeAgoText: String {
        let interval = Date().timeIntervalSince(item.timestamp)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: item.timestamp)
        }
    }
}

struct ActionButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .frame(width: 24, height: 24)
                .background(Color.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}
```

---

### 3.4 Implement Drag and Drop

**Task**: Enable dragging captures to other apps

**File**: `Features/QuickAccess/DraggableThumbnail.swift`

```swift
import SwiftUI
import AppKit

struct DraggableThumbnail: View {
    let item: QuickAccessWindowController.CaptureItem
    @Binding var isDragging: Bool

    var body: some View {
        Image(nsImage: item.thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 80, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(radius: isDragging ? 4 : 2)
            .scaleEffect(isDragging ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isDragging)
            .onDrag {
                isDragging = true
                return createDragItem()
            }
            .onDrop(of: [], isTargeted: nil) { _ in
                isDragging = false
                return false
            }
    }

    private func createDragItem() -> NSItemProvider {
        let provider = NSItemProvider()

        // Provide image data
        let image = item.result.nsImage
        provider.register(image)

        // Also provide as file promise for apps that prefer files
        if let tiffData = image.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {

            // Register as PNG data
            provider.registerDataRepresentation(
                forTypeIdentifier: "public.png",
                visibility: .all
            ) { completion in
                completion(pngData, nil)
                return nil
            }
        }

        return provider
    }
}

// Alternative: Using NSView subclass for more control
final class DraggableThumbnailView: NSView, NSDraggingSource {
    var image: NSImage?
    var captureResult: CaptureService.CaptureResult?

    override func mouseDown(with event: NSEvent) {
        guard let image = image else { return }

        let draggingItem = NSDraggingItem(pasteboardWriter: image)
        draggingItem.setDraggingFrame(bounds, contents: image)

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        return [.copy]
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        if operation != [] {
            // Drag completed successfully
            // Could notify controller to remove item
        }
    }
}
```

---

### 3.5 Implement Visual Effect View

**Task**: Create NSVisualEffectView wrapper for SwiftUI

**File**: `Core/Extensions/VisualEffectView.swift`

```swift
import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}
```

---

### 3.6 Update AppCoordinator Integration

**Task**: Connect Quick Access to capture flow

**File**: Update `Core/AppCoordinator.swift`

```swift
// Add to AppCoordinator:

// MARK: - Quick Access

private(set) lazy var quickAccessController: QuickAccessWindowController = {
    QuickAccessWindowController(settingsManager: settingsManager, coordinator: self)
}()

// Update handleCaptureResult:
private func handleCaptureResult(_ result: CaptureService.CaptureResult) {
    state = .idle

    if settingsManager.settings.showQuickAccess {
        // Show in Quick Access Overlay
        quickAccessController.addCapture(result)
    } else {
        // Direct save (legacy behavior)
        do {
            let url = try captureService.save(result)
            captureService.copyToClipboard(result)
            showNotification(title: "Screenshot saved", body: url.lastPathComponent)
        } catch {
            handleCaptureError(error)
        }
    }
}

// MARK: - Annotation Editor

func openAnnotationEditor(for result: CaptureService.CaptureResult) {
    state = .annotating(result.id)
    // Will be implemented in Milestone 4
    // For now, just save the file
    do {
        let url = try captureService.save(result)
        NSWorkspace.shared.open(url)
    } catch {
        handleCaptureError(error)
    }
}
```

---

### 3.7 Implement Keyboard Shortcuts

**Task**: Add keyboard navigation to Quick Access

**File**: `Features/QuickAccess/QuickAccessKeyboardHandler.swift`

```swift
import AppKit
import Carbon

final class QuickAccessKeyboardHandler {
    weak var controller: QuickAccessWindowController?

    private var eventMonitor: Any?

    func startMonitoring() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil  // Event consumed
            }
            return event
        }
    }

    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard let controller = controller else { return false }
        guard !controller.captures.isEmpty else { return false }

        // Check if Quick Access window is key
        guard NSApp.keyWindow is QuickAccessWindow else { return false }

        switch event.keyCode {
        case 53:  // Escape
            controller.performActionOnSelected(.dismiss)
            return true

        case 36:  // Return/Enter
            controller.performActionOnSelected(.annotate)
            return true

        case 125: // Down
            controller.selectNext()
            return true

        case 126: // Up
            controller.selectPrevious()
            return true

        default:
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers?.lowercased() {
                case "c":
                    controller.performActionOnSelected(.copy)
                    return true
                case "s":
                    controller.performActionOnSelected(.save)
                    return true
                case "a":
                    controller.performActionOnSelected(.annotate)
                    return true
                default:
                    break
                }
            }
        }

        return false
    }
}
```

---

## File Structure After Milestone 3

```
ScreenPro/
├── ... (previous files)
│
├── Features/
│   ├── QuickAccess/
│   │   ├── QuickAccessWindowController.swift
│   │   ├── QuickAccessWindow.swift
│   │   ├── QuickAccessContentView.swift
│   │   ├── DraggableThumbnail.swift
│   │   └── QuickAccessKeyboardHandler.swift
│   └── ...
│
├── Core/
│   ├── Extensions/
│   │   └── VisualEffectView.swift
│   └── ...
```

---

## Interaction Flows

### Capture → Quick Access Flow
```
Capture Complete
      │
      ▼
┌─────────────────┐
│ showQuickAccess │──No──▶ Direct Save
│   enabled?      │
└────────┬────────┘
         │ Yes
         ▼
┌─────────────────┐
│ Create CaptureItem │
│ Generate Thumbnail │
└────────┬────────────┘
         │
         ▼
┌─────────────────┐
│ Add to Queue    │
│ Show Window     │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────┐
│     User Interaction         │
│                              │
│  ┌──────┐ ┌──────┐ ┌──────┐ │
│  │ Copy │ │ Save │ │ Edit │ │
│  └──┬───┘ └──┬───┘ └──┬───┘ │
│     │        │        │     │
└─────┼────────┼────────┼─────┘
      │        │        │
      ▼        ▼        ▼
  Clipboard   File    Editor
```

### Drag & Drop Flow
```
Mouse Down on Thumbnail
         │
         ▼
Begin Drag Session
         │
         ▼
┌─────────────────┐
│ Create Provider │
│ - NSImage       │
│ - PNG Data      │
│ - File Promise  │
└────────┬────────┘
         │
         ▼
Drag to Target App
         │
         ▼
┌─────────────────┐
│ Drop Accepted?  │
└────────┬────────┘
    Yes  │  No
         │
         ▼
Remove from Queue
```

---

## Testing Checklist

### Manual Testing

- [ ] Overlay appears after capture
- [ ] Thumbnail displays correctly
- [ ] Hover reveals action buttons
- [ ] Copy button copies to clipboard
- [ ] Save button saves to disk
- [ ] Annotate button opens editor (placeholder)
- [ ] Close button removes from queue
- [ ] Drag to Finder creates file
- [ ] Drag to app pastes image
- [ ] Escape dismisses selected item
- [ ] Cmd+C copies selected item
- [ ] Arrow keys navigate queue
- [ ] Multiple captures stack correctly
- [ ] Auto-dismiss works (when configured)
- [ ] Position settings work (all 4 corners)
- [ ] Window persists across space changes

### Unit Tests

```swift
final class QuickAccessTests: XCTestCase {
    func testCaptureItemCreation() {
        // Test thumbnail generation
    }

    func testQueueManagement() {
        // Test add/remove operations
    }

    func testKeyboardNavigation() {
        // Test selection index updates
    }
}
```

---

## Exit Criteria

| Criterion | Verification |
|-----------|--------------|
| Overlay appears | Capture triggers overlay |
| Thumbnail correct | Image preview visible |
| Actions work | All buttons functional |
| Drag & drop works | Drag to Finder/apps |
| Queue works | Multiple captures visible |
| Keyboard works | Shortcuts functional |
| Position works | All 4 corners tested |
| Auto-dismiss works | Timer dismisses overlay |
| Performance | Appears within 200ms |

---

## Next Steps

After completing Milestone 3, proceed to [Milestone 4: Annotation Editor](./04-annotation-editor.md) to implement the image markup system.
