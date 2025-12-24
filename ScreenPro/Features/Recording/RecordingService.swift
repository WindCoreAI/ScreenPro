import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreMedia
import CoreGraphics
import Combine

// MARK: - RecordingServiceProtocol

@MainActor
protocol RecordingServiceProtocol: AnyObject, ObservableObject {
    var state: RecordingState { get }
    var duration: TimeInterval { get }
    var recordingRegion: RecordingRegion? { get }
    var gifFrameCount: Int { get }
    var isGIFMemoryWarningShown: Bool { get }

    func startRecording(region: RecordingRegion, format: RecordingFormat) async throws
    func stopRecording() async throws -> RecordingResult
    func pauseRecording() throws
    func resumeRecording() throws
    func cancelRecording() async throws
}

// MARK: - RecordingService Implementation (T009)

@MainActor
final class RecordingService: NSObject, ObservableObject, RecordingServiceProtocol {
    // MARK: - Published Properties

    @Published private(set) var state: RecordingState = .idle
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var recordingRegion: RecordingRegion?
    @Published private(set) var gifFrameCount: Int = 0
    @Published private(set) var isGIFMemoryWarningShown: Bool = false

    // MARK: - Dependencies

    private let storageService: StorageService
    private let settingsManager: SettingsManager
    private let permissionManager: PermissionManager

    // MARK: - Capture Components

    private var stream: SCStream?
    private var streamOutput: RecordingStreamOutput?

    // MARK: - Asset Writer Components (T016, T017)

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    // MARK: - GIF Recording Components (T044)

    private var gifFrames: [CGImage] = []
    private var gifConfig: GIFConfig?
    private var gifSourceFPS: Int = 15

    /// Memory warning threshold: ~30 seconds at 15fps (450 frames)
    private static let gifMemoryWarningFrameThreshold = 450

    // MARK: - Microphone Audio Components (T053)

    private var audioEngine: AVAudioEngine?
    private var microphoneInput: AVAssetWriterInput?
    private var isMicrophoneEnabled: Bool = false

    // MARK: - Click Visualization (T072)

    private var clickOverlayController: ClickOverlayController?
    private var isClickVisualizationEnabled: Bool = false

    // MARK: - Keystroke Visualization (T081)

    private var keystrokeOverlayController: KeystrokeOverlayController?
    private var isKeystrokeVisualizationEnabled: Bool = false

    // MARK: - Recording State

    private var outputURL: URL?
    private var recordingFormat: RecordingFormat?
    private var recordingStartTime: Date?

    // MARK: - Timer

    private var durationTimer: Timer?
    private var pauseOffset: CMTime = .zero
    private var pauseStartTime: CMTime?
    private var sessionStartTime: CMTime?
    private var hasStartedSession: Bool = false

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        storageService: StorageService,
        settingsManager: SettingsManager,
        permissionManager: PermissionManager
    ) {
        self.storageService = storageService
        self.settingsManager = settingsManager
        self.permissionManager = permissionManager
        super.init()
    }

    // MARK: - Public Methods

    /// Starts recording the specified region with the given format (T019)
    func startRecording(region: RecordingRegion, format: RecordingFormat) async throws {
        guard state == .idle else {
            throw RecordingError.alreadyRecording
        }

        // Check screen recording permission
        guard permissionManager.screenRecordingStatus == .authorized else {
            throw RecordingError.screenCaptureNotAuthorized
        }

        // Check microphone permission if needed
        if case .video(let config) = format, config.includeMicrophone {
            let micStatus = permissionManager.checkMicrophonePermission()
            guard micStatus == .authorized else {
                throw RecordingError.microphoneNotAuthorized
            }
        }

        // Check disk space before recording (T084)
        let saveLocation = settingsManager.settings.defaultSaveLocation
        guard hasSufficientDiskSpace(at: saveLocation) else {
            throw RecordingError.insufficientDiskSpace
        }

        state = .starting
        recordingRegion = region
        recordingFormat = format

        do {
            // Generate output URL
            let filename = settingsManager.generateFilename(for: format.fileExtension == "gif" ? .gif : .video)
            outputURL = storageService.uniqueURL(for: filename, in: settingsManager.settings.defaultSaveLocation)

            guard let outputURL = outputURL else {
                throw RecordingError.cannotCreateFile(settingsManager.settings.defaultSaveLocation)
            }

            // Ensure directory exists
            try storageService.ensureDirectoryExists(at: settingsManager.settings.defaultSaveLocation)

            // Setup based on format (T044)
            if case .gif(let config) = format {
                // GIF recording: store config and prepare frame buffer
                gifConfig = config
                gifSourceFPS = config.frameRate
                gifFrames = []
                gifFrameCount = 0
                isGIFMemoryWarningShown = false
            } else {
                // Video recording: setup asset writer
                try setupAssetWriter(at: outputURL, format: format)
            }

            // Setup and start stream
            try await setupStream(for: region, format: format)
            try await stream?.startCapture()

            // Start microphone capture if enabled (T057)
            if case .video(let config) = format, config.includeMicrophone {
                try setupMicrophoneCapture()
            }

            // Start click visualization if enabled (T072)
            if case .video(let config) = format, config.showClicks {
                startClickVisualization()
            }

            // Start keystroke visualization if enabled (T081)
            if case .video(let config) = format, config.showKeystrokes {
                startKeystrokeVisualization()
            }

            // Update state
            state = .recording
            recordingStartTime = Date()
            startDurationTimer()

        } catch {
            await cleanup()
            state = .idle
            throw error
        }
    }

    /// Stops recording and returns the result (T020, T046)
    func stopRecording() async throws -> RecordingResult {
        guard state == .recording || state == .paused else {
            throw RecordingError.notRecording
        }

        state = .stopping
        stopDurationTimer()

        // Stop microphone capture (T058)
        stopMicrophoneCapture()

        // Stop capture stream
        try? await stream?.stopCapture()

        guard let outputURL = outputURL else {
            await cleanup()
            throw RecordingError.cannotCreateFile(settingsManager.settings.defaultSaveLocation)
        }

        // Handle GIF finalization (T046)
        if case .gif(let config) = recordingFormat {
            return try await finalizeGIF(config: config, outputURL: outputURL)
        }

        // Finalize video asset writer
        guard let assetWriter = assetWriter else {
            await cleanup()
            throw RecordingError.encodingFailed(underlying: "Asset writer not initialized")
        }

        // Mark inputs as finished
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        microphoneInput?.markAsFinished()

        // Wait for writing to complete
        await assetWriter.finishWriting()

        guard assetWriter.status == .completed else {
            let error = assetWriter.error?.localizedDescription
            await cleanup()
            throw RecordingError.encodingFailed(underlying: error)
        }

        // Create result
        let finalDuration = duration
        let result = RecordingResult(
            url: outputURL,
            duration: finalDuration,
            format: recordingFormat ?? .defaultVideo,
            timestamp: recordingStartTime ?? Date()
        )

        await cleanup()
        state = .idle

        return result
    }

    /// Pauses the current recording (T032)
    func pauseRecording() throws {
        guard state == .recording else {
            throw RecordingError.notRecording
        }

        state = .paused
        pauseStartTime = CMClockGetTime(CMClockGetHostTimeClock())
        stopDurationTimer()
    }

    /// Resumes a paused recording (T033)
    func resumeRecording() throws {
        guard state == .paused else {
            throw RecordingError.notRecording
        }

        // Calculate pause duration and add to offset
        if let pauseStart = pauseStartTime {
            let now = CMClockGetTime(CMClockGetHostTimeClock())
            let pauseDuration = CMTimeSubtract(now, pauseStart)
            pauseOffset = CMTimeAdd(pauseOffset, pauseDuration)
        }
        pauseStartTime = nil

        state = .recording
        startDurationTimer()
    }

    /// Cancels the current recording without saving (T034)
    func cancelRecording() async throws {
        guard state != .idle else {
            return
        }

        stopDurationTimer()

        // Stop capture
        try? await stream?.stopCapture()

        // Cancel and discard the asset writer
        assetWriter?.cancelWriting()

        // Delete partial file
        if let url = outputURL {
            try? FileManager.default.removeItem(at: url)
        }

        await cleanup()
        state = .idle
    }

    // MARK: - Stream Configuration (T010, T011)

    /// Creates an SCStreamConfiguration for the given format (T010)
    private func createStreamConfiguration(for format: RecordingFormat, region: RecordingRegion) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()

        switch format {
        case .video(let videoConfig):
            // Set resolution based on config or use native resolution
            let targetSize = videoConfig.resolution.size
            config.width = Int(targetSize.width)
            config.height = Int(targetSize.height)

            // Frame rate
            config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(videoConfig.frameRate))

            // Pixel format for hardware encoding
            config.pixelFormat = kCVPixelFormatType_32BGRA

            // Audio settings
            config.capturesAudio = videoConfig.includeSystemAudio
            config.excludesCurrentProcessAudio = true

            // Cursor visibility
            config.showsCursor = videoConfig.showCursor

            // Queue depth for handling encoding latency
            config.queueDepth = 8

        case .gif(let gifConfig):
            // GIF typically uses lower frame rate and possibly scaled resolution
            config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(gifConfig.frameRate))
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.capturesAudio = false
            config.showsCursor = true
            config.queueDepth = 5

            // Apply scale factor if needed
            if gifConfig.scale < 1.0 {
                // Scale will be applied during frame processing
            }
        }

        return config
    }

    /// Creates an SCContentFilter for the specified region (T011)
    private func createContentFilter(for region: RecordingRegion) throws -> SCContentFilter {
        switch region {
        case .display(let display):
            return SCContentFilter(display: display, excludingWindows: [])

        case .window(let window):
            return SCContentFilter(desktopIndependentWindow: window)

        case .area(let rect, let display):
            // For area capture, we capture the full display and crop
            let filter = SCContentFilter(display: display, excludingWindows: [])
            // Note: cropping is handled via stream configuration contentRect
            return filter
        }
    }

    /// Sets up the SCStream for capture
    private func setupStream(for region: RecordingRegion, format: RecordingFormat) async throws {
        let configuration = createStreamConfiguration(for: format, region: region)
        let filter = try createContentFilter(for: region)

        // Handle area capture by setting crop rect
        if case .area(let rect, _) = region {
            configuration.sourceRect = rect
            configuration.width = Int(rect.width)
            configuration.height = Int(rect.height)
        }

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        self.stream = stream

        // Create and add stream output
        let output = RecordingStreamOutput(
            onVideoSample: { [weak self] sampleBuffer in
                self?.handleVideoSample(sampleBuffer)
            },
            onAudioSample: { [weak self] sampleBuffer in
                self?.handleAudioSample(sampleBuffer)
            }
        )
        self.streamOutput = output

        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))

        // Add audio output if capturing audio
        if case .video(let config) = format, config.includeSystemAudio {
            try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))
        }
    }

    // MARK: - Asset Writer Setup (T016, T017)

    /// Sets up AVAssetWriter for video encoding
    private func setupAssetWriter(at url: URL, format: RecordingFormat) throws {
        guard case .video(let config) = format else {
            // GIF doesn't use asset writer
            return
        }

        do {
            assetWriter = try AVAssetWriter(url: url, fileType: .mp4)
        } catch {
            throw RecordingError.assetWriterSetupFailed(underlying: error.localizedDescription)
        }

        guard let assetWriter = assetWriter else {
            throw RecordingError.assetWriterSetupFailed(underlying: nil)
        }

        // Video input settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: config.resolution.size.width,
            AVVideoHeightKey: config.resolution.size.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: config.targetBitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: config.frameRate
            ]
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        // Create pixel buffer adaptor for efficient frame writing (T017)
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: config.resolution.size.width,
            kCVPixelBufferHeightKey as String: config.resolution.size.height
        ]

        if let videoInput = videoInput {
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput,
                sourcePixelBufferAttributes: sourcePixelBufferAttributes
            )

            if assetWriter.canAdd(videoInput) {
                assetWriter.add(videoInput)
            }
        }

        // Audio input settings (if system audio enabled) (T050, T051)
        if config.includeSystemAudio {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128000
            ]

            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = true

            if let audioInput = audioInput, assetWriter.canAdd(audioInput) {
                assetWriter.add(audioInput)
            }
        }

        // Microphone input settings (if microphone enabled) (T053)
        if config.includeMicrophone {
            isMicrophoneEnabled = true

            let micAudioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1, // Mono for microphone
                AVEncoderBitRateKey: 64000
            ]

            microphoneInput = AVAssetWriterInput(mediaType: .audio, outputSettings: micAudioSettings)
            microphoneInput?.expectsMediaDataInRealTime = true

            if let microphoneInput = microphoneInput, assetWriter.canAdd(microphoneInput) {
                assetWriter.add(microphoneInput)
            }
        }
    }

    // MARK: - Microphone Setup (T053, T054)

    /// Sets up AVAudioEngine for microphone capture
    private func setupMicrophoneCapture() throws {
        guard isMicrophoneEnabled else { return }

        let engine = AVAudioEngine()
        audioEngine = engine

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Validate format
        guard format.sampleRate > 0 && format.channelCount > 0 else {
            throw RecordingError.microphoneNotAuthorized
        }

        // Install tap on input node (T054)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, time in
            self?.handleMicrophoneBuffer(buffer, time: time)
        }

        // Prepare and start engine
        engine.prepare()
        try engine.start()
    }

    /// Stops microphone capture
    private func stopMicrophoneCapture() {
        if let engine = audioEngine, engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil
    }

    /// Handles incoming microphone audio buffers (T056)
    private func handleMicrophoneBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard state == .recording,
              hasStartedSession,
              let micInput = microphoneInput,
              micInput.isReadyForMoreMediaData else { return }

        // Convert AVAudioPCMBuffer to CMSampleBuffer (T055)
        guard let sampleBuffer = buffer.toCMSampleBuffer(at: time) else { return }

        // Append to microphone track
        micInput.append(sampleBuffer)
    }

    // MARK: - Click Visualization (T072)

    /// Starts click visualization overlay
    private func startClickVisualization() {
        isClickVisualizationEnabled = true
        clickOverlayController = ClickOverlayController()
        clickOverlayController?.start()
    }

    /// Stops click visualization overlay
    private func stopClickVisualization() {
        clickOverlayController?.stop()
        clickOverlayController = nil
        isClickVisualizationEnabled = false
    }

    // MARK: - Keystroke Visualization (T081)

    /// Starts keystroke visualization overlay
    private func startKeystrokeVisualization() {
        isKeystrokeVisualizationEnabled = true
        keystrokeOverlayController = KeystrokeOverlayController()
        keystrokeOverlayController?.start()
    }

    /// Stops keystroke visualization overlay
    private func stopKeystrokeVisualization() {
        keystrokeOverlayController?.stop()
        keystrokeOverlayController = nil
        isKeystrokeVisualizationEnabled = false
    }

    // MARK: - Sample Handling (T018, T021, T045)

    /// Handles incoming video samples (T021, T045)
    private func handleVideoSample(_ sampleBuffer: CMSampleBuffer) {
        guard state == .recording else { return }

        // Handle GIF frame capture (T045)
        if gifConfig != nil {
            handleGIFSample(sampleBuffer)
            return
        }

        // Handle video frame capture
        guard let assetWriter = assetWriter,
              let videoInput = videoInput,
              videoInput.isReadyForMoreMediaData else { return }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Start session at first frame (T021)
        if !hasStartedSession {
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: presentationTime)
            sessionStartTime = presentationTime
            hasStartedSession = true
        }

        // Adjust timestamp for any pause offset
        let adjustedTime = CMTimeSubtract(presentationTime, pauseOffset)

        // Get the image buffer and append
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            if pixelBufferAdaptor?.assetWriterInput.isReadyForMoreMediaData == true {
                pixelBufferAdaptor?.append(imageBuffer, withPresentationTime: adjustedTime)
            }
        } else {
            // Fallback: append sample buffer directly
            videoInput.append(sampleBuffer)
        }
    }

    /// Handles incoming GIF frames (T045)
    private func handleGIFSample(_ sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Convert CVPixelBuffer to CGImage
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        // Store frame (T044)
        gifFrames.append(cgImage)

        // Update frame count on main thread
        Task { @MainActor in
            self.gifFrameCount = self.gifFrames.count

            // Check memory warning threshold (T048)
            if self.gifFrameCount >= Self.gifMemoryWarningFrameThreshold && !self.isGIFMemoryWarningShown {
                self.isGIFMemoryWarningShown = true
                // Warning will be observed by UI through the published property
            }
        }
    }

    /// Finalizes GIF encoding and returns result (T046)
    private func finalizeGIF(config: GIFConfig, outputURL: URL) async throws -> RecordingResult {
        guard !gifFrames.isEmpty else {
            await cleanup()
            throw RecordingError.noFramesToEncode
        }

        let finalDuration = duration
        let framesCopy = gifFrames
        let sourceFPS = gifSourceFPS

        do {
            // Encode GIF on background thread to avoid blocking main thread
            try await Task.detached(priority: .userInitiated) {
                try GIFEncoder.encode(
                    frames: framesCopy,
                    config: config,
                    sourceFPS: sourceFPS,
                    to: outputURL
                )
            }.value

            let result = RecordingResult(
                url: outputURL,
                duration: finalDuration,
                format: .gif(config),
                timestamp: recordingStartTime ?? Date()
            )

            await cleanup()
            state = .idle

            return result

        } catch {
            await cleanup()
            throw RecordingError.encodingFailed(underlying: error.localizedDescription)
        }
    }

    /// Handles incoming audio samples
    private func handleAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard state == .recording else { return }

        guard let audioInput = audioInput,
              audioInput.isReadyForMoreMediaData,
              hasStartedSession else { return }

        audioInput.append(sampleBuffer)
    }

    // MARK: - Duration Timer (T031)

    /// Starts the duration timer with 100ms update interval
    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.recordingStartTime else { return }
                self.duration = Date().timeIntervalSince(startTime)
            }
        }
    }

    /// Stops the duration timer
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    // MARK: - Disk Space Check (T084)

    /// Minimum required disk space for recording (500 MB)
    private static let minimumDiskSpaceBytes: Int64 = 500 * 1024 * 1024

    /// Checks if there is sufficient disk space at the given location
    private func hasSufficientDiskSpace(at url: URL) -> Bool {
        do {
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let availableSpace = values.volumeAvailableCapacityForImportantUsage {
                return availableSpace >= Self.minimumDiskSpaceBytes
            }
            // Fallback to volumeAvailableCapacityKey
            let fallbackValues = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let availableSpace = fallbackValues.volumeAvailableCapacity {
                return Int64(availableSpace) >= Self.minimumDiskSpaceBytes
            }
        } catch {
            // If we can't check, allow recording attempt
            print("Could not check disk space: \(error)")
        }
        return true
    }

    // MARK: - Cleanup

    /// Cleans up all recording resources
    private func cleanup() async {
        stopDurationTimer()
        stopMicrophoneCapture()
        stopClickVisualization()
        stopKeystrokeVisualization()

        stream = nil
        streamOutput = nil
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        microphoneInput = nil
        pixelBufferAdaptor = nil
        outputURL = nil
        recordingFormat = nil
        recordingStartTime = nil
        recordingRegion = nil
        duration = 0
        pauseOffset = .zero
        pauseStartTime = nil
        sessionStartTime = nil
        hasStartedSession = false
        isMicrophoneEnabled = false

        // Clear GIF state (T044)
        gifFrames = []
        gifConfig = nil
        gifFrameCount = 0
        isGIFMemoryWarningShown = false
    }
}

// MARK: - SCStreamDelegate (T018)

extension RecordingService: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            // Handle stream error
            print("Recording stream stopped with error: \(error)")
            if self.state == .recording {
                // Try to gracefully stop and save what we have
                try? await self.stopRecording()
            }
        }
    }
}

// MARK: - RecordingStreamOutput (T018)

/// Handles stream output samples
final class RecordingStreamOutput: NSObject, SCStreamOutput {
    private let onVideoSample: (CMSampleBuffer) -> Void
    private let onAudioSample: (CMSampleBuffer) -> Void

    init(
        onVideoSample: @escaping (CMSampleBuffer) -> Void,
        onAudioSample: @escaping (CMSampleBuffer) -> Void
    ) {
        self.onVideoSample = onVideoSample
        self.onAudioSample = onAudioSample
        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }

        switch type {
        case .screen:
            onVideoSample(sampleBuffer)
        case .audio:
            onAudioSample(sampleBuffer)
        case .microphone:
            // Microphone handled separately via AVAudioEngine
            break
        @unknown default:
            break
        }
    }
}
