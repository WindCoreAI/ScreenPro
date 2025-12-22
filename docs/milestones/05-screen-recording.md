# Milestone 5: Screen Recording

## Overview

**Goal**: Implement video recording, GIF creation, and audio capture using ScreenCaptureKit and AVFoundation.

**Prerequisites**: Milestone 4 completed

---

## Deliverables

| Deliverable | Description | Priority |
|-------------|-------------|----------|
| RecordingService | Core recording logic | P0 |
| Video Recording | MP4/H.264 output | P0 |
| GIF Recording | Animated GIF output | P0 |
| Microphone Audio | Voice capture | P0 |
| System Audio | Computer audio capture | P1 |
| Recording Controls | Start/stop/pause UI | P0 |
| Click Visualization | Show mouse clicks | P1 |
| Keystroke Overlay | Show key presses | P2 |
| Video Trimming | Basic editing | P2 |

---

## Implementation Tasks

### 5.1 Implement Recording Service

**File**: `Features/Recording/RecordingService.swift`

```swift
import ScreenCaptureKit
import AVFoundation
import Combine

@MainActor
final class RecordingService: NSObject, ObservableObject {
    // MARK: - Types

    enum RecordingFormat {
        case video(VideoConfig)
        case gif(GIFConfig)
    }

    struct VideoConfig {
        var resolution: Resolution = .r1080p
        var frameRate: Int = 30
        var quality: Quality = .high
        var includeSystemAudio: Bool = false
        var includeMicrophone: Bool = false
        var showClicks: Bool = false
        var showKeystrokes: Bool = false

        enum Resolution: String, CaseIterable {
            case r480p, r720p, r1080p, r4k

            var size: CGSize {
                switch self {
                case .r480p: return CGSize(width: 854, height: 480)
                case .r720p: return CGSize(width: 1280, height: 720)
                case .r1080p: return CGSize(width: 1920, height: 1080)
                case .r4k: return CGSize(width: 3840, height: 2160)
                }
            }
        }

        enum Quality: String, CaseIterable {
            case low, medium, high, maximum
        }
    }

    struct GIFConfig {
        var frameRate: Int = 15
        var maxColors: Int = 256
        var loopCount: Int = 0  // 0 = infinite
        var scale: CGFloat = 1.0
    }

    enum RecordingRegion {
        case display(SCDisplay)
        case window(SCWindow)
        case area(CGRect, SCDisplay)
    }

    struct RecordingResult {
        let id: UUID
        let url: URL
        let duration: TimeInterval
        let format: RecordingFormat
        let timestamp: Date
    }

    // MARK: - State

    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var recordingRegion: RecordingRegion?

    // MARK: - Private Properties

    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var outputURL: URL?
    private var startTime: CMTime?
    private var pausedTime: CMTime = .zero
    private var durationTimer: Timer?

    private var gifFrames: [CGImage] = []
    private var gifConfig: GIFConfig?

    private let settingsManager: SettingsManager
    private let storageService: StorageService

    // Audio
    private var audioEngine: AVAudioEngine?
    private var microphoneInput: AVAudioInputNode?

    // Overlays
    private var clickOverlay: ClickOverlayController?
    private var keystrokeOverlay: KeystrokeOverlayController?

    // MARK: - Initialization

    init(settingsManager: SettingsManager, storageService: StorageService) {
        self.settingsManager = settingsManager
        self.storageService = storageService
        super.init()
    }

    // MARK: - Public Methods

    func startRecording(
        region: RecordingRegion,
        format: RecordingFormat
    ) async throws {
        guard !isRecording else { return }

        recordingRegion = region
        isRecording = true
        isPaused = false
        duration = 0

        switch format {
        case .video(let config):
            try await startVideoRecording(region: region, config: config)
        case .gif(let config):
            try await startGIFRecording(region: region, config: config)
        }

        startDurationTimer()
    }

    func pauseRecording() {
        guard isRecording, !isPaused else { return }

        isPaused = true
        pausedTime = CMClockGetTime(CMClockGetHostTimeClock())

        stream?.stopCapture()
        durationTimer?.invalidate()
    }

    func resumeRecording() {
        guard isRecording, isPaused else { return }

        isPaused = false

        Task {
            try? await stream?.startCapture()
        }

        startDurationTimer()
    }

    func stopRecording() async throws -> RecordingResult {
        guard isRecording else {
            throw RecordingError.notRecording
        }

        durationTimer?.invalidate()
        stream?.stopCapture()

        // Cleanup overlays
        clickOverlay?.stop()
        keystrokeOverlay?.stop()

        let result: RecordingResult

        if let gifConfig = gifConfig {
            // Finalize GIF
            result = try await finalizeGIF(config: gifConfig)
        } else {
            // Finalize video
            result = try await finalizeVideo()
        }

        // Reset state
        isRecording = false
        isPaused = false
        recordingRegion = nil
        stream = nil
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        pixelBufferAdaptor = nil
        outputURL = nil
        startTime = nil
        pausedTime = .zero
        gifFrames.removeAll()
        gifConfig = nil

        return result
    }

    func cancelRecording() {
        durationTimer?.invalidate()
        stream?.stopCapture()

        clickOverlay?.stop()
        keystrokeOverlay?.stop()

        // Delete partial file
        if let url = outputURL {
            try? FileManager.default.removeItem(at: url)
        }

        // Reset state
        isRecording = false
        isPaused = false
        recordingRegion = nil
        stream = nil
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        outputURL = nil
        startTime = nil
        gifFrames.removeAll()
        gifConfig = nil
    }

    // MARK: - Video Recording

    private func startVideoRecording(region: RecordingRegion, config: VideoConfig) async throws {
        // Create output URL
        let filename = settingsManager.generateFilename(for: .video)
        outputURL = settingsManager.settings.defaultSaveLocation.appendingPathComponent(filename)

        // Setup AVAssetWriter
        try setupAssetWriter(config: config)

        // Setup ScreenCaptureKit stream
        let streamConfig = createStreamConfiguration(for: region, videoConfig: config)
        let filter = try await createContentFilter(for: region)

        stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)

        // Add stream outputs
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)

        if config.includeSystemAudio {
            try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: .main)
        }

        // Setup microphone if needed
        if config.includeMicrophone {
            try setupMicrophoneCapture()
        }

        // Setup overlays
        if config.showClicks {
            clickOverlay = ClickOverlayController()
            clickOverlay?.start()
        }

        if config.showKeystrokes {
            keystrokeOverlay = KeystrokeOverlayController()
            keystrokeOverlay?.start()
        }

        // Start capture
        try await stream?.startCapture()
    }

    private func setupAssetWriter(config: VideoConfig) throws {
        guard let url = outputURL else { throw RecordingError.noOutputURL }

        assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)

        // Video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: config.resolution.size.width,
            AVVideoHeightKey: config.resolution.size.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitRate(for: config),
                AVVideoExpectedSourceFrameRateKey: config.frameRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: config.resolution.size.width,
            kCVPixelBufferHeightKey as String: config.resolution.size.height
        ]

        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        if assetWriter?.canAdd(videoInput!) == true {
            assetWriter?.add(videoInput!)
        }

        // Audio settings
        if config.includeSystemAudio || config.includeMicrophone {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128000
            ]

            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = true

            if assetWriter?.canAdd(audioInput!) == true {
                assetWriter?.add(audioInput!)
            }
        }
    }

    private func bitRate(for config: VideoConfig) -> Int {
        let baseRate: Int
        switch config.resolution {
        case .r480p: baseRate = 2_500_000
        case .r720p: baseRate = 5_000_000
        case .r1080p: baseRate = 10_000_000
        case .r4k: baseRate = 35_000_000
        }

        let qualityMultiplier: Double
        switch config.quality {
        case .low: qualityMultiplier = 0.5
        case .medium: qualityMultiplier = 0.75
        case .high: qualityMultiplier = 1.0
        case .maximum: qualityMultiplier = 1.5
        }

        return Int(Double(baseRate) * qualityMultiplier)
    }

    private func finalizeVideo() async throws -> RecordingResult {
        guard let assetWriter = assetWriter,
              let url = outputURL else {
            throw RecordingError.noOutputURL
        }

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        await assetWriter.finishWriting()

        if assetWriter.status == .failed {
            throw assetWriter.error ?? RecordingError.unknown
        }

        return RecordingResult(
            id: UUID(),
            url: url,
            duration: duration,
            format: .video(VideoConfig()),
            timestamp: Date()
        )
    }

    // MARK: - GIF Recording

    private func startGIFRecording(region: RecordingRegion, config: GIFConfig) async throws {
        gifConfig = config
        gifFrames.removeAll()

        let streamConfig = createStreamConfiguration(for: region, gifConfig: config)
        let filter = try await createContentFilter(for: region)

        stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)

        try await stream?.startCapture()
    }

    private func finalizeGIF(config: GIFConfig) async throws -> RecordingResult {
        let filename = settingsManager.generateFilename(for: .gif)
        let url = settingsManager.settings.defaultSaveLocation.appendingPathComponent(filename)

        try await Task.detached(priority: .userInitiated) {
            try GIFEncoder.encode(
                frames: self.gifFrames,
                frameDelay: 1.0 / Double(config.frameRate),
                loopCount: config.loopCount,
                to: url
            )
        }.value

        return RecordingResult(
            id: UUID(),
            url: url,
            duration: duration,
            format: .gif(config),
            timestamp: Date()
        )
    }

    // MARK: - Stream Configuration

    private func createStreamConfiguration(
        for region: RecordingRegion,
        videoConfig: VideoConfig? = nil,
        gifConfig: GIFConfig? = nil
    ) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0

        if let videoConfig = videoConfig {
            config.width = Int(videoConfig.resolution.size.width)
            config.height = Int(videoConfig.resolution.size.height)
            config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(videoConfig.frameRate))
            config.capturesAudio = videoConfig.includeSystemAudio
        } else if let gifConfig = gifConfig {
            let regionSize = regionBounds(region).size
            config.width = Int(regionSize.width * gifConfig.scale * scale)
            config.height = Int(regionSize.height * gifConfig.scale * scale)
            config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(gifConfig.frameRate))
            config.capturesAudio = false
        }

        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = settingsManager.settings.includeCursor
        config.queueDepth = 5

        return config
    }

    private func createContentFilter(for region: RecordingRegion) async throws -> SCContentFilter {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        switch region {
        case .display(let display):
            return SCContentFilter(display: display, excludingWindows: [])

        case .window(let window):
            return SCContentFilter(desktopIndependentWindow: window)

        case .area(_, let display):
            return SCContentFilter(display: display, excludingWindows: [])
        }
    }

    private func regionBounds(_ region: RecordingRegion) -> CGRect {
        switch region {
        case .display(let display):
            return display.frame
        case .window(let window):
            return window.frame
        case .area(let rect, _):
            return rect
        }
    }

    // MARK: - Microphone

    private func setupMicrophoneCapture() throws {
        audioEngine = AVAudioEngine()
        microphoneInput = audioEngine?.inputNode

        let format = microphoneInput?.outputFormat(forBus: 0)

        microphoneInput?.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.handleMicrophoneBuffer(buffer, time: time)
        }

        try audioEngine?.start()
    }

    private func handleMicrophoneBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Mix with system audio or write directly
        guard let audioInput = audioInput,
              audioInput.isReadyForMoreMediaData else { return }

        if let sampleBuffer = buffer.asSampleBuffer(at: time) {
            audioInput.append(sampleBuffer)
        }
    }

    // MARK: - Timer

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.duration += 0.1
            }
        }
    }

    // MARK: - Errors

    enum RecordingError: LocalizedError {
        case notRecording
        case noOutputURL
        case encodingFailed
        case unknown

        var errorDescription: String? {
            switch self {
            case .notRecording: return "No recording in progress"
            case .noOutputURL: return "No output URL configured"
            case .encodingFailed: return "Failed to encode recording"
            case .unknown: return "An unknown error occurred"
            }
        }
    }
}

// MARK: - SCStreamDelegate

extension RecordingService: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            self.cancelRecording()
        }
    }
}

// MARK: - SCStreamOutput

extension RecordingService: SCStreamOutput {
    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }

        Task { @MainActor in
            switch type {
            case .screen:
                handleVideoSample(sampleBuffer)
            case .audio:
                handleAudioSample(sampleBuffer)
            @unknown default:
                break
            }
        }
    }

    @MainActor
    private func handleVideoSample(_ sampleBuffer: CMSampleBuffer) {
        guard !isPaused else { return }

        if gifConfig != nil {
            // GIF mode - collect frames
            if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                let ciImage = CIImage(cvPixelBuffer: imageBuffer)
                let context = CIContext()
                if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                    gifFrames.append(cgImage)
                }
            }
        } else {
            // Video mode - write to asset writer
            guard let videoInput = videoInput,
                  videoInput.isReadyForMoreMediaData else { return }

            // Start writing if not started
            if assetWriter?.status == .unknown {
                startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                assetWriter?.startWriting()
                assetWriter?.startSession(atSourceTime: startTime!)
            }

            videoInput.append(sampleBuffer)
        }
    }

    @MainActor
    private func handleAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard !isPaused,
              let audioInput = audioInput,
              audioInput.isReadyForMoreMediaData else { return }

        audioInput.append(sampleBuffer)
    }
}
```

---

### 5.2 Implement GIF Encoder

**File**: `Features/Recording/GIFEncoder.swift`

```swift
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum GIFEncoder {
    static func encode(
        frames: [CGImage],
        frameDelay: Double,
        loopCount: Int,
        to url: URL
    ) throws {
        guard !frames.isEmpty else {
            throw GIFError.noFrames
        }

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.gif.identifier as CFString,
            frames.count,
            nil
        ) else {
            throw GIFError.failedToCreateDestination
        }

        // File-level properties
        let fileProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: loopCount
            ]
        ]
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)

        // Frame properties
        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay,
                kCGImagePropertyGIFUnclampedDelayTime as String: frameDelay
            ]
        ]

        // Add frames
        for frame in frames {
            CGImageDestinationAddImage(destination, frame, frameProperties as CFDictionary)
        }

        // Finalize
        guard CGImageDestinationFinalize(destination) else {
            throw GIFError.failedToFinalize
        }
    }

    enum GIFError: LocalizedError {
        case noFrames
        case failedToCreateDestination
        case failedToFinalize

        var errorDescription: String? {
            switch self {
            case .noFrames: return "No frames to encode"
            case .failedToCreateDestination: return "Failed to create GIF destination"
            case .failedToFinalize: return "Failed to finalize GIF"
            }
        }
    }
}

// MARK: - Frame Rate Reduction

extension GIFEncoder {
    /// Reduce frame count for smaller file size
    static func reduceFrames(_ frames: [CGImage], targetFPS: Int, sourceFPS: Int) -> [CGImage] {
        guard sourceFPS > targetFPS else { return frames }

        let ratio = Double(sourceFPS) / Double(targetFPS)
        var result: [CGImage] = []

        var accumulated: Double = 0
        for (index, frame) in frames.enumerated() {
            accumulated += 1
            if accumulated >= ratio {
                result.append(frame)
                accumulated -= ratio
            }
        }

        return result
    }
}
```

---

### 5.3 Implement Recording Controls UI

**File**: `Features/Recording/RecordingControlsView.swift`

```swift
import SwiftUI

struct RecordingControlsView: View {
    @ObservedObject var service: RecordingService
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Recording indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(service.isPaused ? Color.yellow : Color.red)
                    .frame(width: 10, height: 10)
                    .opacity(service.isPaused ? 1 : pulsingOpacity)

                Text(formattedDuration)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }

            Divider()
                .frame(height: 20)

            // Controls
            HStack(spacing: 12) {
                // Pause/Resume
                Button {
                    if service.isPaused {
                        service.resumeRecording()
                    } else {
                        service.pauseRecording()
                    }
                } label: {
                    Image(systemName: service.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)

                // Stop
                Button {
                    onStop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.7))
        )
    }

    private var formattedDuration: String {
        let minutes = Int(service.duration) / 60
        let seconds = Int(service.duration) % 60
        let tenths = Int((service.duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }

    @State private var pulsingOpacity: Double = 1.0

    private var pulsingAnimation: Animation {
        Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
    }
}

// MARK: - Recording Controls Window

final class RecordingControlsWindow: NSWindow {
    init(service: RecordingService, onStop: @escaping () -> Void) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 44),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]

        contentView = NSHostingView(
            rootView: RecordingControlsView(service: service, onStop: onStop)
        )

        // Position at top center
        if let screen = NSScreen.main {
            let x = screen.frame.midX - frame.width / 2
            let y = screen.frame.maxY - frame.height - 50
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
```

---

### 5.4 Implement Click Overlay

**File**: `Features/Recording/ClickOverlayController.swift`

```swift
import AppKit
import SwiftUI

@MainActor
final class ClickOverlayController {
    private var overlayWindow: NSWindow?
    private var eventMonitor: Any?
    private var clicks: [ClickEffect] = []

    struct ClickEffect: Identifiable {
        let id = UUID()
        let position: CGPoint
        let timestamp: Date
        let isLeftClick: Bool
    }

    func start() {
        createOverlayWindow()

        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleClick(event)
            }
        }
    }

    func stop() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        overlayWindow?.close()
        overlayWindow = nil
    }

    private func createOverlayWindow() {
        guard let screen = NSScreen.main else { return }

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let contentView = ClickOverlayView(clicks: .constant(clicks))
        window.contentView = NSHostingView(rootView: contentView)
        window.orderFront(nil)

        overlayWindow = window
    }

    private func handleClick(_ event: NSEvent) {
        let position = NSEvent.mouseLocation
        let click = ClickEffect(
            position: position,
            timestamp: Date(),
            isLeftClick: event.type == .leftMouseDown
        )

        clicks.append(click)
        updateOverlay()

        // Remove after animation
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            clicks.removeAll { $0.id == click.id }
            updateOverlay()
        }
    }

    private func updateOverlay() {
        if let hostingView = overlayWindow?.contentView as? NSHostingView<ClickOverlayView> {
            hostingView.rootView = ClickOverlayView(clicks: .constant(clicks))
        }
    }
}

struct ClickOverlayView: View {
    @Binding var clicks: [ClickOverlayController.ClickEffect]

    var body: some View {
        GeometryReader { geometry in
            ForEach(clicks) { click in
                ClickRipple(isLeftClick: click.isLeftClick)
                    .position(
                        x: click.position.x,
                        y: geometry.size.height - click.position.y
                    )
            }
        }
    }
}

struct ClickRipple: View {
    let isLeftClick: Bool

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1.0

    var body: some View {
        Circle()
            .stroke(isLeftClick ? Color.blue : Color.green, lineWidth: 3)
            .frame(width: 40, height: 40)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) {
                    scale = 1.5
                    opacity = 0
                }
            }
    }
}
```

---

### 5.5 Implement Keystroke Overlay

**File**: `Features/Recording/KeystrokeOverlayController.swift`

```swift
import AppKit
import SwiftUI
import Carbon

@MainActor
final class KeystrokeOverlayController {
    private var overlayWindow: NSWindow?
    private var eventMonitor: Any?
    private var currentKeys: [KeyPress] = []

    struct KeyPress: Identifiable {
        let id = UUID()
        let key: String
        let modifiers: NSEvent.ModifierFlags
        let timestamp: Date

        var displayString: String {
            var parts: [String] = []

            if modifiers.contains(.command) { parts.append("⌘") }
            if modifiers.contains(.shift) { parts.append("⇧") }
            if modifiers.contains(.option) { parts.append("⌥") }
            if modifiers.contains(.control) { parts.append("⌃") }

            parts.append(key.uppercased())
            return parts.joined()
        }
    }

    func start() {
        createOverlayWindow()

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyPress(event)
            }
        }
    }

    func stop() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        overlayWindow?.close()
        overlayWindow = nil
    }

    private func createOverlayWindow() {
        guard let screen = NSScreen.main else { return }

        let window = NSWindow(
            contentRect: NSRect(
                x: screen.frame.midX - 150,
                y: screen.frame.minY + 100,
                width: 300,
                height: 60
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        updateOverlay()
        window.orderFront(nil)

        overlayWindow = window
    }

    private func handleKeyPress(_ event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers else { return }

        let keyPress = KeyPress(
            key: characters,
            modifiers: event.modifierFlags,
            timestamp: Date()
        )

        currentKeys.append(keyPress)

        // Keep only recent keys
        if currentKeys.count > 5 {
            currentKeys.removeFirst()
        }

        updateOverlay()

        // Clear after delay
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            currentKeys.removeAll { $0.id == keyPress.id }
            updateOverlay()
        }
    }

    private func updateOverlay() {
        let contentView = KeystrokeOverlayView(keys: currentKeys)
        overlayWindow?.contentView = NSHostingView(rootView: contentView)
    }
}

struct KeystrokeOverlayView: View {
    let keys: [KeystrokeOverlayController.KeyPress]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys) { key in
                Text(key.displayString)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.7))
                    )
            }
        }
        .padding(8)
    }
}
```

---

## File Structure After Milestone 5

```
ScreenPro/
├── Features/
│   ├── Recording/
│   │   ├── RecordingService.swift
│   │   ├── GIFEncoder.swift
│   │   ├── RecordingControlsView.swift
│   │   ├── ClickOverlayController.swift
│   │   ├── KeystrokeOverlayController.swift
│   │   └── VideoTrimmerView.swift
│   └── ...
```

---

## Testing Checklist

- [ ] Video recording produces valid MP4
- [ ] GIF recording produces animated GIF
- [ ] Pause/resume works correctly
- [ ] Duration counter updates
- [ ] System audio captures
- [ ] Microphone audio captures
- [ ] Audio syncs with video
- [ ] Click overlay shows clicks
- [ ] Keystroke overlay shows keys
- [ ] Multi-monitor recording works
- [ ] Window recording works
- [ ] Area recording works
- [ ] Recording controls are draggable
- [ ] Cancel recording deletes file

---

## Exit Criteria

| Criterion | Verification |
|-----------|--------------|
| Video records | 30fps 1080p MP4 |
| GIF records | 15fps animated GIF |
| Audio works | System + mic capture |
| Controls work | Start/pause/stop |
| Overlays work | Clicks and keys visible |
| Performance | No frame drops |

---

## Next Steps

Proceed to [Milestone 6: Advanced Features](./06-advanced-features.md).
