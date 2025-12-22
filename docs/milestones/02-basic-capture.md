# Milestone 2: Basic Screenshot Capture

## Overview

**Goal**: Implement core screenshot functionality including area, window, and fullscreen capture using ScreenCaptureKit.

**Prerequisites**: Milestone 1 completed

**Dependencies**: ScreenCaptureKit (macOS 14.0+)

---

## Deliverables

| Deliverable | Description | Priority |
|-------------|-------------|----------|
| CaptureService | Core capture logic using ScreenCaptureKit | P0 |
| Area Selection Overlay | Full-screen overlay for region selection | P0 |
| Window Picker | Window selection interface | P0 |
| Fullscreen Capture | Capture entire display | P0 |
| Crosshair & Dimensions | Selection guides with size display | P0 |
| Save & Copy | Output to file and clipboard | P0 |
| Capture Sound | Audio feedback on capture | P1 |

---

## Implementation Tasks

### 2.1 Implement CaptureService

**Task**: Create the main capture service using ScreenCaptureKit

**File**: `Features/Capture/CaptureService.swift`

```swift
import ScreenCaptureKit
import AppKit
import Combine

@MainActor
final class CaptureService: ObservableObject {
    // MARK: - Types

    enum CaptureMode {
        case area(CGRect)
        case window(SCWindow)
        case display(SCDisplay)
    }

    struct CaptureConfig {
        var includeCursor: Bool = false
        var imageFormat: SettingsManager.ImageFormat = .png
        var scaleFactor: CGFloat = 2.0  // Retina
    }

    struct CaptureResult {
        let id: UUID
        let image: CGImage
        let mode: CaptureMode
        let timestamp: Date
        let sourceRect: CGRect

        var nsImage: NSImage {
            NSImage(cgImage: image, size: NSSize(
                width: CGFloat(image.width) / 2,
                height: CGFloat(image.height) / 2
            ))
        }
    }

    // MARK: - Properties

    @Published private(set) var availableDisplays: [SCDisplay] = []
    @Published private(set) var availableWindows: [SCWindow] = []

    private let settingsManager: SettingsManager
    private let storageService: StorageService

    // MARK: - Initialization

    init(settingsManager: SettingsManager, storageService: StorageService) {
        self.settingsManager = settingsManager
        self.storageService = storageService
    }

    // MARK: - Content Discovery

    func refreshAvailableContent() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        availableDisplays = content.displays
        availableWindows = content.windows.filter { window in
            // Filter out system windows and small windows
            guard let app = window.owningApplication else { return false }
            guard window.frame.width > 50 && window.frame.height > 50 else { return false }
            guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return false }
            return true
        }
    }

    // MARK: - Capture Methods

    func captureArea(_ rect: CGRect) async throws -> CaptureResult {
        try await refreshAvailableContent()

        guard let display = displayContaining(rect) else {
            throw CaptureError.noDisplayFound
        }

        let config = createStreamConfiguration(for: rect)
        let filter = SCContentFilter(display: display, excludingWindows: [])

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        // Crop to selected area
        let croppedImage = try cropImage(image, to: rect, in: display.frame)

        playCaptureSound()

        return CaptureResult(
            id: UUID(),
            image: croppedImage,
            mode: .area(rect),
            timestamp: Date(),
            sourceRect: rect
        )
    }

    func captureWindow(_ window: SCWindow) async throws -> CaptureResult {
        let config = createStreamConfiguration(for: window.frame)
        let filter = SCContentFilter(desktopIndependentWindow: window)

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        playCaptureSound()

        return CaptureResult(
            id: UUID(),
            image: image,
            mode: .window(window),
            timestamp: Date(),
            sourceRect: window.frame
        )
    }

    func captureDisplay(_ display: SCDisplay? = nil) async throws -> CaptureResult {
        try await refreshAvailableContent()

        let targetDisplay = display ?? availableDisplays.first { $0.displayID == CGMainDisplayID() }

        guard let targetDisplay else {
            throw CaptureError.noDisplayFound
        }

        let config = createStreamConfiguration(for: targetDisplay.frame)
        let filter = SCContentFilter(display: targetDisplay, excludingWindows: [])

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        playCaptureSound()

        return CaptureResult(
            id: UUID(),
            image: image,
            mode: .display(targetDisplay),
            timestamp: Date(),
            sourceRect: targetDisplay.frame
        )
    }

    // MARK: - Configuration

    private func createStreamConfiguration(for rect: CGRect) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0

        config.width = Int(rect.width * scale)
        config.height = Int(rect.height * scale)
        config.scalesToFit = false
        config.showsCursor = settingsManager.settings.includeCursor
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB

        return config
    }

    // MARK: - Helpers

    private func displayContaining(_ rect: CGRect) -> SCDisplay? {
        availableDisplays.first { display in
            display.frame.intersects(rect)
        }
    }

    private func cropImage(_ image: CGImage, to rect: CGRect, in displayFrame: CGRect) throws -> CGImage {
        let scale = CGFloat(image.width) / displayFrame.width

        // Convert rect to image coordinates
        let cropRect = CGRect(
            x: (rect.origin.x - displayFrame.origin.x) * scale,
            y: (displayFrame.height - rect.origin.y - rect.height) * scale,  // Flip Y
            width: rect.width * scale,
            height: rect.height * scale
        )

        guard let cropped = image.cropping(to: cropRect) else {
            throw CaptureError.cropFailed
        }

        return cropped
    }

    private func playCaptureSound() {
        guard settingsManager.settings.playCaptureSound else { return }
        NSSound(named: "Grab")?.play()
    }

    // MARK: - Output

    func save(_ result: CaptureResult) throws -> URL {
        let data = imageData(from: result.image)
        let filename = settingsManager.generateFilename(for: .screenshot)

        return try storageService.save(
            imageData: data,
            filename: filename,
            to: settingsManager.settings.defaultSaveLocation
        )
    }

    func copyToClipboard(_ result: CaptureResult) {
        storageService.copyToClipboard(image: result.nsImage)
    }

    private func imageData(from image: CGImage) -> Data {
        let format = settingsManager.settings.defaultImageFormat
        let bitmapRep = NSBitmapImageRep(cgImage: image)

        switch format {
        case .png:
            return bitmapRep.representation(using: .png, properties: [:]) ?? Data()
        case .jpeg:
            return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) ?? Data()
        case .tiff:
            return bitmapRep.representation(using: .tiff, properties: [:]) ?? Data()
        case .heic:
            // HEIC requires additional handling
            return bitmapRep.representation(using: .png, properties: [:]) ?? Data()
        }
    }

    // MARK: - Errors

    enum CaptureError: LocalizedError {
        case noDisplayFound
        case cropFailed
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .noDisplayFound: return "No display found for capture area"
            case .cropFailed: return "Failed to crop captured image"
            case .permissionDenied: return "Screen recording permission denied"
            }
        }
    }
}
```

---

### 2.2 Implement Selection Overlay Window

**Task**: Create full-screen overlay for area selection

**File**: `Features/Capture/SelectionOverlay/SelectionWindow.swift`

```swift
import AppKit
import SwiftUI

final class SelectionWindow: NSWindow {
    private var selectionView: SelectionOverlayView?
    private var completion: ((CGRect?) -> Void)?

    init(for screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = SelectionOverlayView(screenFrame: screen.frame) { [weak self] rect in
            self?.completion?(rect)
            self?.close()
        }

        selectionView = view
        contentView = NSHostingView(rootView: view)
    }

    func beginSelection(completion: @escaping (CGRect?) -> Void) {
        self.completion = completion
        makeKeyAndOrderFront(nil)
        NSCursor.crosshair.set()
    }

    override func cancelOperation(_ sender: Any?) {
        completion?(nil)
        close()
    }

    override func close() {
        NSCursor.arrow.set()
        super.close()
    }
}
```

**File**: `Features/Capture/SelectionOverlay/SelectionOverlayView.swift`

```swift
import SwiftUI

struct SelectionOverlayView: View {
    let screenFrame: CGRect
    let onComplete: (CGRect?) -> Void

    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?
    @State private var isDragging = false

    private var selectionRect: CGRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)

            // Selection area (clear cutout)
            if let rect = selectionRect {
                SelectionRectView(rect: rect, screenFrame: screenFrame)
            }

            // Crosshair
            CrosshairView(position: currentPoint ?? .zero)

            // Dimensions display
            if let rect = selectionRect, rect.width > 0, rect.height > 0 {
                DimensionsView(rect: rect)
            }

            // Instructions
            if !isDragging {
                InstructionsView()
            }
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if startPoint == nil {
                        startPoint = value.startLocation
                        isDragging = true
                    }
                    currentPoint = value.location
                }
                .onEnded { _ in
                    if let rect = selectionRect, rect.width > 5, rect.height > 5 {
                        // Convert to screen coordinates
                        let screenRect = convertToScreen(rect)
                        onComplete(screenRect)
                    } else {
                        onComplete(nil)
                    }
                }
        )
        .onAppear {
            // Track mouse position for crosshair
            NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
                if !isDragging {
                    currentPoint = event.locationInWindow
                }
                return event
            }
        }
        .onExitCommand {
            onComplete(nil)
        }
    }

    private func convertToScreen(_ rect: CGRect) -> CGRect {
        // Convert from view coordinates to screen coordinates
        CGRect(
            x: screenFrame.origin.x + rect.origin.x,
            y: screenFrame.origin.y + (screenFrame.height - rect.origin.y - rect.height),
            width: rect.width,
            height: rect.height
        )
    }
}

struct SelectionRectView: View {
    let rect: CGRect
    let screenFrame: CGRect

    var body: some View {
        ZStack {
            // Clear area (punch through the dimming)
            Rectangle()
                .fill(.clear)
                .frame(width: rect.width, height: rect.height)
                .background(.ultraThinMaterial.opacity(0))
                .position(x: rect.midX, y: rect.midY)

            // Selection border
            Rectangle()
                .stroke(Color.white, lineWidth: 1)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)

            // Corner handles
            ForEach(corners, id: \.self) { corner in
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .position(cornerPosition(corner, in: rect))
            }
        }
    }

    private var corners: [Corner] {
        [.topLeft, .topRight, .bottomLeft, .bottomRight]
    }

    private enum Corner: Hashable {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    private func cornerPosition(_ corner: Corner, in rect: CGRect) -> CGPoint {
        switch corner {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }
}

struct CrosshairView: View {
    let position: CGPoint

    var body: some View {
        ZStack {
            // Horizontal line
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(height: 1)
                .offset(y: position.y - UIScreen.main.bounds.height / 2)

            // Vertical line
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 1)
                .offset(x: position.x - UIScreen.main.bounds.width / 2)
        }
    }
}

struct DimensionsView: View {
    let rect: CGRect

    var body: some View {
        Text("\(Int(rect.width)) × \(Int(rect.height))")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.7))
            .cornerRadius(4)
            .position(x: rect.midX, y: rect.midY)
    }
}

struct InstructionsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Click and drag to select an area")
                .font(.system(size: 14, weight: .medium))

            Text("Press Escape to cancel")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .foregroundColor(.white)
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
    }
}
```

---

### 2.3 Implement Window Picker

**Task**: Create window selection interface

**File**: `Features/Capture/WindowPicker/WindowPickerController.swift`

```swift
import AppKit
import ScreenCaptureKit

@MainActor
final class WindowPickerController {
    private var highlightWindow: NSWindow?
    private var currentWindow: SCWindow?

    func pickWindow(from windows: [SCWindow]) async -> SCWindow? {
        return await withCheckedContinuation { continuation in
            beginWindowSelection(windows: windows) { window in
                continuation.resume(returning: window)
            }
        }
    }

    private func beginWindowSelection(windows: [SCWindow], completion: @escaping (SCWindow?) -> Void) {
        // Create transparent overlay for each screen
        for screen in NSScreen.screens {
            let overlay = WindowPickerOverlay(
                screen: screen,
                windows: windows
            ) { [weak self] window in
                self?.cleanup()
                completion(window)
            }
            overlay.makeKeyAndOrderFront(nil)
        }

        NSCursor.pointingHand.set()
    }

    private func cleanup() {
        highlightWindow?.close()
        highlightWindow = nil
        NSCursor.arrow.set()
    }

    func highlightWindow(_ window: SCWindow) {
        highlightWindow?.close()

        let highlight = NSWindow(
            contentRect: window.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        highlight.level = .floating
        highlight.isOpaque = false
        highlight.backgroundColor = .clear
        highlight.ignoresMouseEvents = true

        let view = NSView(frame: window.frame)
        view.wantsLayer = true
        view.layer?.borderColor = NSColor.systemBlue.cgColor
        view.layer?.borderWidth = 3
        view.layer?.cornerRadius = 8
        view.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.1).cgColor

        highlight.contentView = view
        highlight.orderFront(nil)

        highlightWindow = highlight
    }
}

final class WindowPickerOverlay: NSWindow {
    private let windows: [SCWindow]
    private let completion: (SCWindow?) -> Void
    private var trackingArea: NSTrackingArea?

    init(screen: NSScreen, windows: [SCWindow], completion: @escaping (SCWindow?) -> Void) {
        self.windows = windows
        self.completion = completion

        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        isOpaque = false
        backgroundColor = NSColor.black.withAlphaComponent(0.01)  // Nearly transparent
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
    }

    override func mouseMoved(with event: NSEvent) {
        let point = NSEvent.mouseLocation

        // Find window under cursor
        if let window = windowAt(point) {
            // Highlight it
            NotificationCenter.default.post(
                name: .highlightWindow,
                object: window
            )
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = NSEvent.mouseLocation

        if let window = windowAt(point) {
            completion(window)
        } else {
            completion(nil)
        }

        close()
    }

    override func cancelOperation(_ sender: Any?) {
        completion(nil)
        close()
    }

    private func windowAt(_ point: CGPoint) -> SCWindow? {
        // Find topmost window containing point
        windows.first { window in
            window.frame.contains(point)
        }
    }
}

extension Notification.Name {
    static let highlightWindow = Notification.Name("highlightWindow")
}
```

---

### 2.4 Implement Magnifier View

**Task**: Create magnifying glass for precise selection

**File**: `Features/Capture/SelectionOverlay/MagnifierView.swift`

```swift
import SwiftUI
import AppKit

struct MagnifierView: View {
    let position: CGPoint
    let magnification: CGFloat = 4.0
    let size: CGFloat = 120

    @State private var capturedImage: NSImage?

    var body: some View {
        ZStack {
            // Magnified content
            if let image = capturedImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)  // Pixel-perfect
                    .frame(width: size, height: size)
            }

            // Crosshair in center
            ZStack {
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 1, height: size)
                Rectangle()
                    .fill(Color.red)
                    .frame(width: size, height: 1)
            }

            // Border
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(radius: 4)
        .offset(x: 60, y: -60)  // Position relative to cursor
        .onChange(of: position) { _, newPosition in
            updateCapture(at: newPosition)
        }
    }

    private func updateCapture(at point: CGPoint) {
        // Capture small area around cursor
        let captureSize = size / magnification
        let captureRect = CGRect(
            x: point.x - captureSize / 2,
            y: point.y - captureSize / 2,
            width: captureSize,
            height: captureSize
        )

        // Use CGWindowListCreateImage for quick capture
        if let cgImage = CGWindowListCreateImage(
            captureRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.boundsIgnoreFraming]
        ) {
            capturedImage = NSImage(cgImage: cgImage, size: NSSize(width: captureSize, height: captureSize))
        }
    }
}

// Coordinate display
struct CoordinateView: View {
    let position: CGPoint

    var body: some View {
        HStack(spacing: 8) {
            Text("X: \(Int(position.x))")
            Text("Y: \(Int(position.y))")
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.7))
        .cornerRadius(4)
    }
}
```

---

### 2.5 Update AppCoordinator

**Task**: Integrate capture service with coordinator

**File**: Update `Core/AppCoordinator.swift`

```swift
// Add to AppCoordinator class:

// MARK: - Capture Service

private(set) lazy var captureService: CaptureService = {
    CaptureService(
        settingsManager: settingsManager,
        storageService: storageService
    )
}()

private var selectionWindows: [SelectionWindow] = []
private var windowPickerController: WindowPickerController?

// MARK: - Capture Actions

func captureArea() {
    guard isReady else {
        requestPermission()
        return
    }

    state = .selectingArea
    beginAreaSelection()
}

func captureWindow() {
    guard isReady else {
        requestPermission()
        return
    }

    state = .selectingWindow
    beginWindowSelection()
}

func captureFullscreen() {
    guard isReady else {
        requestPermission()
        return
    }

    state = .capturing
    Task {
        await performFullscreenCapture()
    }
}

// MARK: - Selection

private func beginAreaSelection() {
    // Create selection window for each screen
    selectionWindows = NSScreen.screens.map { screen in
        let window = SelectionWindow(for: screen)
        return window
    }

    // Begin selection on main screen
    selectionWindows.first?.beginSelection { [weak self] rect in
        self?.handleAreaSelected(rect)
    }
}

private func handleAreaSelected(_ rect: CGRect?) {
    // Close all selection windows
    selectionWindows.forEach { $0.close() }
    selectionWindows.removeAll()

    guard let rect = rect else {
        state = .idle
        return
    }

    state = .capturing
    Task {
        await performAreaCapture(rect)
    }
}

private func beginWindowSelection() {
    windowPickerController = WindowPickerController()

    Task {
        do {
            try await captureService.refreshAvailableContent()
            let windows = captureService.availableWindows

            if let window = await windowPickerController?.pickWindow(from: windows) {
                await performWindowCapture(window)
            } else {
                state = .idle
            }
        } catch {
            handleCaptureError(error)
        }
    }
}

// MARK: - Capture Execution

private func performAreaCapture(_ rect: CGRect) async {
    do {
        let result = try await captureService.captureArea(rect)
        handleCaptureResult(result)
    } catch {
        handleCaptureError(error)
    }
}

private func performWindowCapture(_ window: SCWindow) async {
    do {
        let result = try await captureService.captureWindow(window)
        handleCaptureResult(result)
    } catch {
        handleCaptureError(error)
    }
}

private func performFullscreenCapture() async {
    do {
        let result = try await captureService.captureDisplay()
        handleCaptureResult(result)
    } catch {
        handleCaptureError(error)
    }
}

// MARK: - Result Handling

private func handleCaptureResult(_ result: CaptureService.CaptureResult) {
    state = .idle

    // For now, save to file and copy to clipboard
    // Quick Access Overlay will be added in Milestone 3
    do {
        let url = try captureService.save(result)
        captureService.copyToClipboard(result)

        showNotification(title: "Screenshot saved", body: url.lastPathComponent)
    } catch {
        handleCaptureError(error)
    }
}

private func handleCaptureError(_ error: Error) {
    state = .idle

    // Show error notification
    showNotification(
        title: "Capture failed",
        body: error.localizedDescription
    )
}

private func showNotification(title: String, body: String) {
    let notification = NSUserNotification()
    notification.title = title
    notification.informativeText = body
    notification.soundName = nil
    NSUserNotificationCenter.default.deliver(notification)
}
```

---

### 2.6 Implement Multi-Monitor Support

**Task**: Handle multiple displays correctly

**File**: `Features/Capture/MultiMonitorSupport.swift`

```swift
import AppKit
import ScreenCaptureKit

struct DisplayInfo {
    let screen: NSScreen
    let scDisplay: SCDisplay?
    let frame: CGRect
    let isMain: Bool

    var displayID: CGDirectDisplayID {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }
}

@MainActor
final class DisplayManager {
    static let shared = DisplayManager()

    var displays: [DisplayInfo] {
        NSScreen.screens.map { screen in
            DisplayInfo(
                screen: screen,
                scDisplay: nil,  // Will be populated from SCShareableContent
                frame: screen.frame,
                isMain: screen == NSScreen.main
            )
        }
    }

    var mainDisplay: DisplayInfo? {
        displays.first { $0.isMain }
    }

    func display(containing point: CGPoint) -> DisplayInfo? {
        displays.first { $0.frame.contains(point) }
    }

    func display(for rect: CGRect) -> DisplayInfo? {
        // Find display with largest intersection
        displays.max { d1, d2 in
            d1.frame.intersection(rect).area < d2.frame.intersection(rect).area
        }
    }
}

extension CGRect {
    var area: CGFloat {
        width * height
    }
}
```

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Capture Flow                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  User Action (Menu/Shortcut)                                        │
│         │                                                           │
│         ▼                                                           │
│  ┌─────────────────┐                                               │
│  │ AppCoordinator  │                                               │
│  │ state = .selecting │                                            │
│  └────────┬────────┘                                               │
│           │                                                         │
│           ▼                                                         │
│  ┌─────────────────────────────────────────────┐                   │
│  │         Selection UI                         │                   │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐  │                   │
│  │  │   Area    │ │  Window   │ │ Fullscreen│  │                   │
│  │  │  Overlay  │ │  Picker   │ │  (none)   │  │                   │
│  │  └─────┬─────┘ └─────┬─────┘ └─────┬─────┘  │                   │
│  └────────┼─────────────┼─────────────┼────────┘                   │
│           │             │             │                             │
│           └─────────────┴─────────────┘                             │
│                         │                                           │
│                         ▼                                           │
│           ┌─────────────────────────┐                              │
│           │    CaptureService       │                              │
│           │  captureArea/Window/... │                              │
│           └────────────┬────────────┘                              │
│                        │                                            │
│                        ▼                                            │
│           ┌─────────────────────────┐                              │
│           │   ScreenCaptureKit      │                              │
│           │  SCScreenshotManager    │                              │
│           └────────────┬────────────┘                              │
│                        │                                            │
│                        ▼                                            │
│           ┌─────────────────────────┐                              │
│           │    CaptureResult        │                              │
│           │  (CGImage + metadata)   │                              │
│           └────────────┬────────────┘                              │
│                        │                                            │
│           ┌────────────┴────────────┐                              │
│           ▼                         ▼                               │
│  ┌─────────────────┐      ┌─────────────────┐                      │
│  │  Save to File   │      │ Copy to Clipboard│                      │
│  │ StorageService  │      │ StorageService   │                      │
│  └─────────────────┘      └─────────────────┘                      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## File Structure After Milestone 2

```
ScreenPro/
├── ... (Milestone 1 files)
│
├── Features/
│   ├── Capture/
│   │   ├── CaptureService.swift
│   │   ├── MultiMonitorSupport.swift
│   │   ├── SelectionOverlay/
│   │   │   ├── SelectionWindow.swift
│   │   │   ├── SelectionOverlayView.swift
│   │   │   ├── MagnifierView.swift
│   │   │   └── CrosshairView.swift
│   │   └── WindowPicker/
│   │       └── WindowPickerController.swift
│   └── ... (other features)
```

---

## Testing Checklist

### Manual Testing

- [ ] Area capture works with click-and-drag
- [ ] Selection shows dimensions in real-time
- [ ] Crosshair appears during selection
- [ ] Escape cancels selection
- [ ] Window capture highlights hovered window
- [ ] Click selects and captures window
- [ ] Fullscreen captures entire display
- [ ] Capture sound plays (when enabled)
- [ ] File saves to configured location
- [ ] Clipboard contains captured image
- [ ] Multi-monitor: selection works across displays
- [ ] Multi-monitor: window picker shows all windows
- [ ] Retina displays capture at correct resolution

### Unit Tests

```swift
final class CaptureServiceTests: XCTestCase {
    func testCaptureResultCreation() {
        // Test that capture results have correct metadata
    }

    func testImageCropping() {
        // Test crop function with various rects
    }

    func testCoordinateConversion() {
        // Test screen coordinate conversions
    }
}
```

---

## Exit Criteria

| Criterion | Verification |
|-----------|--------------|
| Area capture works | Select region, verify image |
| Window capture works | Click window, verify captured |
| Fullscreen works | Trigger, verify full display |
| Dimensions display | Selection shows W×H |
| Crosshair visible | Lines extend to edges |
| Sound plays | Audio feedback on capture |
| File saves | Check save location |
| Clipboard works | Paste in another app |
| Multi-monitor | Test on external display |
| Performance | Capture < 100ms |

---

## Next Steps

After completing Milestone 2, proceed to [Milestone 3: Quick Access Overlay](./03-quick-access-overlay.md) to implement the post-capture floating UI.
