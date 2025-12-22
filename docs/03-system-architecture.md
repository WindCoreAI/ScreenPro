# System Architecture

## Overview

ScreenPro is a native macOS application built with Swift and SwiftUI, leveraging Apple's modern frameworks for screen capture, media processing, and system integration.

---

## Technology Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| **UI Framework** | SwiftUI + AppKit | Modern declarative UI with AppKit for system integration |
| **Language** | Swift 5.9+ | Type safety, performance, modern concurrency |
| **Screen Capture** | ScreenCaptureKit | Apple's recommended framework (macOS 12.3+) |
| **Video Processing** | AVFoundation | Video encoding, audio capture |
| **Image Processing** | Core Image, Core Graphics | Filters, annotations, transformations |
| **Text Recognition** | Vision Framework | On-device OCR |
| **GIF Creation** | ImageIO | Native GIF encoding |
| **Persistence** | SwiftData / Core Data | Capture history, settings |
| **Networking** | URLSession | Cloud uploads |

### Minimum System Requirements

- **macOS**: 14.0 (Sonoma) - For full ScreenCaptureKit screenshot API
- **Fallback**: macOS 12.3 (Monterey) - Basic capture support
- **Architecture**: Universal (Apple Silicon + Intel)

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          ScreenPro App                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │
│  │  Menu Bar   │  │   Quick     │  │ Annotation  │  │ Settings  │  │
│  │   Module    │  │   Access    │  │   Editor    │  │  Window   │  │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────┬─────┘  │
│         │                │                │               │        │
│  ───────┴────────────────┴────────────────┴───────────────┴─────   │
│                              │                                      │
│                    ┌─────────┴─────────┐                           │
│                    │   AppCoordinator  │                           │
│                    │   (State Machine) │                           │
│                    └─────────┬─────────┘                           │
│                              │                                      │
│  ┌───────────────────────────┴───────────────────────────────────┐ │
│  │                     Core Services Layer                        │ │
│  ├───────────────┬───────────────┬───────────────┬───────────────┤ │
│  │   Capture     │   Recording   │   Processing  │   Storage     │ │
│  │   Service     │   Service     │   Pipeline    │   Service     │ │
│  └───────┬───────┴───────┬───────┴───────┬───────┴───────┬───────┘ │
│          │               │               │               │         │
│  ┌───────┴───────┬───────┴───────┬───────┴───────┬───────┴───────┐ │
│  │ScreenCapture  │ AVFoundation  │  Core Image   │  FileManager  │ │
│  │    Kit        │               │  Vision       │  SwiftData    │ │
│  └───────────────┴───────────────┴───────────────┴───────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Module Breakdown

### 1. App Coordinator

Central state machine managing application flow and inter-module communication.

```swift
@MainActor
final class AppCoordinator: ObservableObject {
    enum State {
        case idle
        case capturing(CaptureMode)
        case recording
        case annotating(CaptureResult)
        case uploading(CaptureResult)
    }

    @Published private(set) var state: State = .idle

    // Services
    private let captureService: CaptureService
    private let recordingService: RecordingService
    private let storageService: StorageService
    private let cloudService: CloudService

    // Cross-module communication
    func handleCapture(_ mode: CaptureMode) async throws -> CaptureResult
    func handleRecording(_ config: RecordingConfig) async throws -> RecordingResult
    func openAnnotationEditor(for result: CaptureResult)
}
```

### 2. Menu Bar Module

Lives in the system menu bar, provides quick access to all features.

```swift
struct MenuBarModule {
    // Components
    - MenuBarIcon: NSStatusItem
    - MenuBarMenu: NSMenu with capture options
    - GlobalShortcutManager: Handles system-wide hotkeys

    // Responsibilities
    - Display app status (idle, recording, uploading)
    - Provide dropdown menu for all actions
    - Handle global keyboard shortcuts
    - Show notifications
}
```

### 3. Capture Service

Handles all screenshot capture operations using ScreenCaptureKit.

```swift
final class CaptureService {
    // Capture Modes
    enum CaptureMode {
        case area(CGRect?)        // nil = user selects
        case window(SCWindow?)    // nil = user selects
        case screen(SCDisplay?)   // nil = current screen
        case scrolling(SCWindow, ScrollDirection)
    }

    // Core API
    func capture(mode: CaptureMode, config: CaptureConfig) async throws -> CaptureResult

    // ScreenCaptureKit Integration
    private func setupContentFilter(for mode: CaptureMode) -> SCContentFilter
    private func configureStream(_ config: SCStreamConfiguration) -> SCStreamConfiguration

    // Selection UI
    func showSelectionOverlay() async -> CGRect?
    func showWindowPicker() async -> SCWindow?
}
```

#### ScreenCaptureKit Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      CaptureService                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Get Available Content                                       │
│     SCShareableContent.current → [SCDisplay], [SCWindow]        │
│                                                                 │
│  2. Create Filter                                               │
│     SCContentFilter(display:, excludingWindows:)                │
│     SCContentFilter(desktopIndependentWindow:)                  │
│                                                                 │
│  3. Configure Capture                                           │
│     SCStreamConfiguration()                                     │
│       .width, .height          // Resolution                    │
│       .pixelFormat             // BGRA, etc.                    │
│       .showsCursor             // Include cursor                │
│       .capturesAudio           // System audio                  │
│                                                                 │
│  4. Capture Screenshot (macOS 14+)                              │
│     SCScreenshotManager.captureImage(                           │
│         contentFilter:,                                         │
│         configuration:                                          │
│     ) → CGImage                                                 │
│                                                                 │
│  5. Or Stream for Recording                                     │
│     SCStream(filter:, configuration:, delegate:)                │
│       .addStreamOutput(_, type: .screen/.audio)                 │
│       .startCapture()                                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4. Recording Service

Handles screen recording, GIF creation, and audio capture.

```swift
final class RecordingService {
    enum RecordingFormat {
        case video(VideoConfig)  // MP4/H.264
        case gif(GIFConfig)      // Animated GIF
    }

    struct VideoConfig {
        var resolution: Resolution  // 480p to 4K
        var frameRate: Int          // 24, 30, 60
        var quality: Quality        // low, medium, high
        var includeSystemAudio: Bool
        var includeMicrophone: Bool
        var showClicks: Bool
        var showKeystrokes: Bool
    }

    // State
    @Published private(set) var isRecording: Bool
    @Published private(set) var isPaused: Bool
    @Published private(set) var duration: TimeInterval

    // Core API
    func startRecording(region: CaptureRegion, format: RecordingFormat) async throws
    func pauseRecording()
    func resumeRecording()
    func stopRecording() async throws -> RecordingResult
}
```

#### Recording Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                    Recording Pipeline                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────┐     ┌───────────────┐     ┌───────────────┐ │
│  │  SCStream     │────▶│  Frame Buffer │────▶│  Encoder      │ │
│  │  (Video)      │     │               │     │  (AVAsset     │ │
│  └───────────────┘     └───────────────┘     │   Writer)     │ │
│                                               └───────┬───────┘ │
│  ┌───────────────┐                                   │         │
│  │  SCStream     │─────────────────────────────────▶ │         │
│  │  (Audio)      │                                   │         │
│  └───────────────┘                                   │         │
│                                               ┌───────▼───────┐ │
│  ┌───────────────┐                            │   Output      │ │
│  │  AVCapture    │────────────────────────────│   .mp4        │ │
│  │  (Microphone) │                            │   .gif        │ │
│  └───────────────┘                            └───────────────┘ │
│                                                                 │
│  Overlays (Composited):                                         │
│  ┌───────────────┐     ┌───────────────┐                       │
│  │ Click Overlay │     │ Keystroke     │                       │
│  │ Renderer      │     │ Overlay       │                       │
│  └───────────────┘     └───────────────┘                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### GIF Creation Pipeline

```swift
final class GIFEncoder {
    struct Config {
        var frameRate: Int = 15       // Frames per second
        var loopCount: Int = 0        // 0 = infinite
        var quality: Float = 0.8      // Color quantization quality
    }

    func encode(frames: [CGImage], config: Config, to url: URL) throws {
        // 1. Create CGImageDestination with kUTTypeGIF
        // 2. Set file-level properties (loop count)
        // 3. For each frame:
        //    - Add image with delay time property
        // 4. Finalize destination
    }
}
```

### 5. Processing Pipeline

Handles image manipulation, annotations, and transformations.

```swift
final class ProcessingPipeline {
    // Image Operations
    func crop(_ image: CGImage, to rect: CGRect) -> CGImage
    func resize(_ image: CGImage, to size: CGSize) -> CGImage
    func addBackground(_ image: CGImage, config: BackgroundConfig) -> CGImage

    // Annotations
    func render(annotations: [Annotation], onto image: CGImage) -> CGImage

    // Privacy
    func blur(regions: [CGRect], in image: CGImage, intensity: Float) -> CGImage
    func pixelate(regions: [CGRect], in image: CGImage, blockSize: Int) -> CGImage

    // OCR
    func recognizeText(in image: CGImage) async throws -> [RecognizedText]
}
```

#### Vision Framework OCR Integration

```swift
final class TextRecognitionService {
    func recognizeText(in image: CGImage) async throws -> [RecognizedText] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate  // or .fast
        request.recognitionLanguages = ["en-US", "zh-Hans", "ja"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        guard let observations = request.results else { return [] }

        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return RecognizedText(
                text: candidate.string,
                confidence: candidate.confidence,
                boundingBox: observation.boundingBox
            )
        }
    }
}
```

### 6. Quick Access Overlay

Floating window showing recent captures with quick actions.

```swift
final class QuickAccessOverlay: NSWindow {
    // Window Configuration
    - Level: .floating
    - Style: borderless, non-activating
    - Backing: buffered

    // State
    @Published var captures: [CaptureResult]
    @Published var selectedIndex: Int

    // Behaviors
    - Appears at bottom-left after capture
    - Supports drag-and-drop
    - Queues multiple captures
    - Dismisses on action or timeout

    // SwiftUI Content
    var body: some View {
        VStack {
            ForEach(captures) { capture in
                QuickAccessThumbnail(capture: capture)
            }
        }
    }
}
```

### 7. Annotation Editor

Full-featured image editor for markup and modifications.

```swift
struct AnnotationEditor: View {
    @StateObject var document: AnnotationDocument

    // Tool State
    @State var selectedTool: AnnotationTool
    @State var toolConfig: ToolConfiguration

    // Canvas
    @State var canvasSize: CGSize
    @State var zoomLevel: CGFloat
    @State var panOffset: CGPoint

    var body: some View {
        VStack(spacing: 0) {
            Toolbar(selectedTool: $selectedTool, config: $toolConfig)

            GeometryReader { geometry in
                AnnotationCanvas(
                    document: document,
                    tool: selectedTool,
                    config: toolConfig
                )
                .frame(width: canvasSize.width * zoomLevel,
                       height: canvasSize.height * zoomLevel)
                .offset(panOffset)
            }

            PropertyPanel(tool: selectedTool, config: $toolConfig)
        }
    }
}
```

#### Annotation Data Model

```swift
protocol Annotation: Identifiable, Codable {
    var id: UUID { get }
    var bounds: CGRect { get set }
    var transform: CGAffineTransform { get set }
    var zIndex: Int { get set }

    func render(in context: CGContext)
}

struct ArrowAnnotation: Annotation {
    var startPoint: CGPoint
    var endPoint: CGPoint
    var style: ArrowStyle
    var color: Color
    var strokeWidth: CGFloat
}

struct TextAnnotation: Annotation {
    var text: String
    var font: NSFont
    var color: Color
    var backgroundColor: Color?
    var style: TextStyle  // preset styles
}

struct ShapeAnnotation: Annotation {
    var shapeType: ShapeType  // rectangle, ellipse, line
    var fillColor: Color?
    var strokeColor: Color
    var strokeWidth: CGFloat
}

struct BlurAnnotation: Annotation {
    var blurType: BlurType  // gaussian, pixelate
    var intensity: Float
}
```

### 8. Storage Service

Manages capture history, settings, and file operations.

```swift
final class StorageService {
    // File Management
    var defaultSaveDirectory: URL
    func generateFilename(for type: CaptureType) -> String
    func save(_ image: CGImage, as format: ImageFormat, to url: URL) throws
    func save(_ video: AVAsset, to url: URL) async throws

    // History (SwiftData)
    func addToHistory(_ result: CaptureResult)
    func fetchHistory(limit: Int, offset: Int) -> [CaptureHistoryItem]
    func deleteFromHistory(_ id: UUID)
    func clearHistory(olderThan: Date)

    // Settings (UserDefaults + Codable)
    var settings: AppSettings
    func saveSettings()
    func loadSettings()
}

@Model
final class CaptureHistoryItem {
    var id: UUID
    var captureDate: Date
    var captureType: CaptureType
    var thumbnailData: Data
    var filePath: String?
    var cloudURL: URL?
    var annotations: Data?  // Encoded annotation document
}
```

### 9. Cloud Service

Handles uploads to cloud storage.

```swift
final class CloudService {
    struct UploadConfig {
        var expiresIn: TimeInterval?
        var password: String?
        var customDomain: String?
    }

    struct UploadResult {
        var shareableURL: URL
        var expiresAt: Date?
        var deleteToken: String
    }

    func upload(_ data: Data, config: UploadConfig) async throws -> UploadResult
    func delete(token: String) async throws
    func checkQuota() async throws -> QuotaInfo
}
```

---

## Scrolling Capture Architecture

Scrolling capture requires a specialized approach combining user interaction with image stitching.

```
┌─────────────────────────────────────────────────────────────────┐
│                  Scrolling Capture Pipeline                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. User selects scrollable region                              │
│     └─▶ Capture initial frame as reference                      │
│                                                                 │
│  2. User scrolls content                                        │
│     └─▶ Capture frames at intervals                             │
│     └─▶ Show real-time preview                                  │
│                                                                 │
│  3. Detect overlapping regions                                  │
│     └─▶ Use feature matching (Vision framework)                 │
│     └─▶ Calculate vertical/horizontal offset                    │
│                                                                 │
│  4. Stitch frames                                               │
│     └─▶ Blend overlapping regions                               │
│     └─▶ Produce seamless long image                             │
│                                                                 │
│  5. Crop and finalize                                           │
│     └─▶ Remove duplicate header/footer if detected              │
│     └─▶ Output final image                                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

```swift
final class ScrollingCaptureService {
    struct Config {
        var direction: ScrollDirection  // vertical, horizontal, both
        var captureInterval: TimeInterval = 0.1
        var overlapThreshold: Float = 0.2
    }

    // Capture frames during scroll
    private var frames: [CapturedFrame] = []

    // Stitching engine
    private let stitcher = ImageStitcher()

    func startCapture(region: CGRect, config: Config) async
    func captureFrame() async
    func finishCapture() async throws -> CGImage
}

final class ImageStitcher {
    func stitch(frames: [CGImage], direction: ScrollDirection) throws -> CGImage {
        // 1. Detect overlap using feature matching
        // 2. Calculate transformation matrices
        // 3. Create output canvas
        // 4. Blend overlapping regions
        // 5. Return stitched result
    }
}
```

---

## Keyboard Shortcut System

```swift
final class ShortcutManager {
    // Global shortcuts using Carbon APIs or modern alternatives
    private var registeredShortcuts: [ShortcutID: KeyboardShortcut] = [:]

    func register(_ shortcut: KeyboardShortcut, for action: ShortcutAction)
    func unregister(_ id: ShortcutID)

    // Handle system conflicts
    func detectConflicts(with shortcut: KeyboardShortcut) -> [ConflictingApp]
}

struct KeyboardShortcut: Codable, Hashable {
    var key: KeyEquivalent
    var modifiers: EventModifiers
}

enum ShortcutAction {
    case captureArea
    case captureWindow
    case captureFullscreen
    case captureScrolling
    case startRecording
    case recordGIF
    case textRecognition
    case openHistory
}
```

---

## Permission Management

```swift
final class PermissionManager {
    enum Permission {
        case screenRecording
        case microphone
        case accessibility  // For keystroke capture
    }

    func checkPermission(_ permission: Permission) -> PermissionStatus
    func requestPermission(_ permission: Permission) async -> Bool
    func openSystemPreferences(for permission: Permission)

    // Observer for permission changes
    var permissionChangedPublisher: AnyPublisher<Permission, Never>
}

enum PermissionStatus {
    case authorized
    case denied
    case notDetermined
    case restricted
}
```

---

## File Structure

```
ScreenPro/
├── App/
│   ├── ScreenProApp.swift           # App entry point
│   ├── AppCoordinator.swift         # Central state machine
│   └── AppDelegate.swift            # NSApplicationDelegate
│
├── Features/
│   ├── MenuBar/
│   │   ├── MenuBarController.swift
│   │   ├── MenuBarMenu.swift
│   │   └── StatusItemView.swift
│   │
│   ├── Capture/
│   │   ├── CaptureService.swift
│   │   ├── SelectionOverlay/
│   │   │   ├── SelectionWindow.swift
│   │   │   ├── CrosshairView.swift
│   │   │   └── MagnifierView.swift
│   │   └── WindowPicker/
│   │       └── WindowPickerController.swift
│   │
│   ├── Recording/
│   │   ├── RecordingService.swift
│   │   ├── RecordingControlsView.swift
│   │   ├── ClickOverlay.swift
│   │   ├── KeystrokeOverlay.swift
│   │   └── GIFEncoder.swift
│   │
│   ├── QuickAccess/
│   │   ├── QuickAccessWindow.swift
│   │   ├── QuickAccessView.swift
│   │   └── ThumbnailView.swift
│   │
│   ├── Annotation/
│   │   ├── AnnotationEditor.swift
│   │   ├── AnnotationCanvas.swift
│   │   ├── AnnotationToolbar.swift
│   │   ├── Tools/
│   │   │   ├── ArrowTool.swift
│   │   │   ├── TextTool.swift
│   │   │   ├── ShapeTool.swift
│   │   │   ├── BlurTool.swift
│   │   │   └── HighlighterTool.swift
│   │   └── PropertyPanel/
│   │       └── PropertyPanelView.swift
│   │
│   ├── ScrollingCapture/
│   │   ├── ScrollingCaptureService.swift
│   │   ├── ImageStitcher.swift
│   │   └── ScrollingPreviewView.swift
│   │
│   ├── TextRecognition/
│   │   └── TextRecognitionService.swift
│   │
│   ├── History/
│   │   ├── HistoryView.swift
│   │   └── HistoryItemView.swift
│   │
│   └── Settings/
│       ├── SettingsWindow.swift
│       ├── GeneralSettingsView.swift
│       ├── CaptureSettingsView.swift
│       ├── RecordingSettingsView.swift
│       ├── ShortcutsSettingsView.swift
│       └── CloudSettingsView.swift
│
├── Core/
│   ├── Services/
│   │   ├── StorageService.swift
│   │   ├── CloudService.swift
│   │   ├── PermissionManager.swift
│   │   └── ShortcutManager.swift
│   │
│   ├── Processing/
│   │   ├── ProcessingPipeline.swift
│   │   ├── ImageFilters.swift
│   │   └── BackgroundRenderer.swift
│   │
│   ├── Models/
│   │   ├── CaptureResult.swift
│   │   ├── RecordingResult.swift
│   │   ├── Annotation.swift
│   │   ├── AppSettings.swift
│   │   └── CaptureHistoryItem.swift
│   │
│   └── Extensions/
│       ├── CGImage+Extensions.swift
│       ├── NSImage+Extensions.swift
│       └── URL+Extensions.swift
│
├── Resources/
│   ├── Assets.xcassets
│   ├── Localizable.strings
│   └── Credits.rtf
│
└── Supporting Files/
    ├── Info.plist
    ├── ScreenPro.entitlements
    └── ScreenProRelease.entitlements
```

---

## Dependencies

### Apple Frameworks (No External Dependencies)

| Framework | Usage |
|-----------|-------|
| ScreenCaptureKit | Screen capture, window detection |
| AVFoundation | Video encoding, audio recording |
| Vision | OCR, image analysis |
| Core Image | Image filters, blur effects |
| Core Graphics | Drawing, image manipulation |
| ImageIO | GIF encoding, image I/O |
| SwiftData | Capture history persistence |
| UniformTypeIdentifiers | File type handling |
| UserNotifications | Notifications |

### Optional Considerations

| Library | Purpose | Notes |
|---------|---------|-------|
| Sparkle | Auto-updates | If distributing outside App Store |
| Sentry/Crashlytics | Crash reporting | For production monitoring |

---

## Security Considerations

### Entitlements Required

```xml
<!-- ScreenPro.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <!-- App Sandbox -->
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- Screen Recording -->
    <key>com.apple.security.screen-recording</key>
    <true/>

    <!-- Microphone Access -->
    <key>com.apple.security.device.audio-input</key>
    <true/>

    <!-- File Access -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>

    <!-- Network (for cloud upload) -->
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

### Privacy Handling

- All OCR processing on-device
- No automatic data collection
- User-controlled cloud uploads
- Secure credential storage in Keychain

---

## Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Screenshot capture | < 50ms | Time from trigger to image ready |
| Quick Access display | < 200ms | Time to show thumbnail |
| Annotation tool switch | < 16ms | Tool selection response |
| Video encoding | Real-time | No frame drops at target FPS |
| GIF encoding | < 2s per second of video | Background processing |
| Memory (idle) | < 50MB | Menu bar only |
| Memory (editing) | < 300MB | Large image with annotations |

---

## Sources

- [Apple ScreenCaptureKit Documentation](https://developer.apple.com/documentation/screencapturekit/)
- [Meet ScreenCaptureKit - WWDC22](https://developer.apple.com/videos/play/wwdc2022/10156/)
- [What's New in ScreenCaptureKit - WWDC23](https://developer.apple.com/videos/play/wwdc2023/10136/)
- [Capturing Screen Content in macOS](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos)
- [Vision Framework - Text Recognition](https://developer.apple.com/documentation/vision/locating-and-displaying-recognized-text)
- [AVFoundation - Audio and Video Capture](https://developer.apple.com/documentation/avfoundation/audio-and-video-capture)
- [ScrollSnap - Open Source Reference](https://github.com/Brkgng/ScrollSnap)
- [GifCapture - Open Source Reference](https://github.com/onmyway133/GifCapture)
