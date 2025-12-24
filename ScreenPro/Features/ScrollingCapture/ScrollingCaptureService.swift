import Foundation
import ScreenCaptureKit
import AppKit
import Combine

// MARK: - ScrollingCaptureService (T025)

/// Service managing scrolling capture operations with frame capture and scroll monitoring.
@MainActor
final class ScrollingCaptureService: ObservableObject {
    // MARK: - Published Properties

    /// Whether a scrolling capture is currently in progress.
    @Published private(set) var isCapturing = false

    /// Captured frames during the current session.
    @Published private(set) var frames: [CapturedFrame] = []

    /// Preview image of the current stitched result.
    @Published private(set) var previewImage: CGImage?

    /// Current scroll offset tracked during capture.
    @Published private(set) var currentScrollOffset: CGFloat = 0

    /// Progress of the current capture (0.0 to 1.0).
    @Published private(set) var captureProgress: Double = 0

    // MARK: - Properties

    /// The current stitch configuration.
    private var config: StitchConfig = .default

    /// The image stitcher for combining frames.
    private let stitcher: ImageStitcher

    /// The capture region.
    private var captureRegion: CGRect = .zero

    /// The display to capture from.
    private var captureDisplay: SCDisplay?

    /// Timer for periodic frame capture.
    private var captureTimer: Timer?

    /// Event monitor for scroll detection.
    private var scrollMonitor: Any?

    /// Last captured scroll position.
    private var lastScrollPosition: CGFloat = 0

    /// Minimum scroll delta to trigger a new frame capture.
    private let minScrollDelta: CGFloat = 20

    // MARK: - Initialization

    /// Creates a new scrolling capture service.
    init() {
        self.stitcher = ImageStitcher()
    }

    // MARK: - Public Methods

    /// Starts a scrolling capture session.
    /// - Parameters:
    ///   - region: The screen region to capture.
    ///   - display: The display containing the region.
    ///   - config: The stitch configuration to use.
    func startCapture(region: CGRect, display: SCDisplay, config: StitchConfig = .default) async throws {
        guard !isCapturing else { return }

        // Validate inputs
        guard region.width >= 50 && region.height >= 50 else {
            throw ScrollingCaptureError.invalidRegion
        }

        self.config = config
        self.captureRegion = region
        self.captureDisplay = display
        self.frames.removeAll()
        self.currentScrollOffset = 0
        self.lastScrollPosition = 0
        self.captureProgress = 0
        self.previewImage = nil

        isCapturing = true

        // Capture initial frame
        try await captureFrame()

        // Start scroll monitoring
        startScrollMonitoring()

        // Start periodic capture timer as backup
        startCaptureTimer()
    }

    /// Manually captures a frame at the current scroll position.
    func captureFrame() async throws {
        guard isCapturing, let display = captureDisplay else {
            throw ScrollingCaptureError.noFrames
        }

        // Check max frames limit
        if frames.count >= config.maxFrames {
            throw ScrollingCaptureError.maxFramesReached
        }

        // Create content filter for the display
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // Configure capture
        let streamConfig = SCStreamConfiguration()
        streamConfig.width = Int(captureRegion.width * 2) // Retina
        streamConfig.height = Int(captureRegion.height * 2)
        streamConfig.showsCursor = false
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA

        // Capture the region
        let fullImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: streamConfig
        )

        // Crop to capture region
        let croppedImage = try cropToRegion(fullImage, region: captureRegion, display: display)

        // Create frame
        let frame = CapturedFrame(
            image: croppedImage,
            scrollOffset: currentScrollOffset,
            timestamp: Date()
        )

        frames.append(frame)
        captureProgress = stitcher.estimateProgress(frameCount: frames.count, maxFrames: config.maxFrames)

        // Update preview periodically (every 3 frames)
        if frames.count % 3 == 0 {
            Task {
                previewImage = await stitcher.generatePreview(frames: frames)
            }
        }
    }

    /// Finishes the capture session and returns the stitched image.
    /// - Returns: The final stitched CGImage.
    func finishCapture() async throws -> CGImage {
        guard isCapturing else {
            throw ScrollingCaptureError.noFrames
        }

        stopCaptureTimer()
        stopScrollMonitoring()
        isCapturing = false

        guard !frames.isEmpty else {
            throw ScrollingCaptureError.noFrames
        }

        // Stitch all frames
        let stitchedImage = try await stitcher.stitch(frames: frames)

        // Clear state
        let result = stitchedImage
        frames.removeAll()
        previewImage = nil
        captureProgress = 0

        return result
    }

    /// Cancels the current capture session.
    func cancelCapture() {
        stopCaptureTimer()
        stopScrollMonitoring()
        isCapturing = false
        frames.removeAll()
        previewImage = nil
        captureProgress = 0
    }

    // MARK: - Private Methods - Scroll Monitoring

    /// Starts monitoring scroll events.
    private func startScrollMonitoring() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleScrollEvent(event)
            }
            return event
        }
    }

    /// Stops monitoring scroll events.
    private func stopScrollMonitoring() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }

    /// Handles a scroll event.
    private func handleScrollEvent(_ event: NSEvent) {
        guard isCapturing else { return }

        // Update scroll offset based on direction
        switch config.direction {
        case .vertical:
            currentScrollOffset += event.scrollingDeltaY
        case .horizontal:
            currentScrollOffset += event.scrollingDeltaX
        case .both:
            currentScrollOffset += hypot(event.scrollingDeltaX, event.scrollingDeltaY)
        }

        // Check if we've scrolled enough to capture a new frame
        let scrollDelta = abs(currentScrollOffset - lastScrollPosition)
        if scrollDelta >= minScrollDelta {
            lastScrollPosition = currentScrollOffset

            Task {
                do {
                    try await captureFrame()
                } catch ScrollingCaptureError.maxFramesReached {
                    // Auto-finish when max frames reached
                    _ = try? await finishCapture()
                } catch {
                    print("Frame capture failed: \(error)")
                }
            }
        }
    }

    // MARK: - Private Methods - Timer

    /// Starts the periodic capture timer.
    private func startCaptureTimer() {
        captureTimer = Timer.scheduledTimer(withTimeInterval: config.captureInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isCapturing else { return }

                // Only capture if scroll position changed
                if self.currentScrollOffset != self.lastScrollPosition {
                    self.lastScrollPosition = self.currentScrollOffset
                    try? await self.captureFrame()
                }
            }
        }
    }

    /// Stops the capture timer.
    private func stopCaptureTimer() {
        captureTimer?.invalidate()
        captureTimer = nil
    }

    // MARK: - Private Methods - Image Processing

    /// Crops a full display capture to the specified region.
    private func cropToRegion(_ image: CGImage, region: CGRect, display: SCDisplay) throws -> CGImage {
        let scaleFactor: CGFloat = 2.0 // Retina

        // Convert region to image coordinates (flip Y)
        let displayHeight = CGFloat(display.height)
        let imageX = region.origin.x * scaleFactor
        let imageY = (displayHeight - region.origin.y - region.height) * scaleFactor
        let imageWidth = region.width * scaleFactor
        let imageHeight = region.height * scaleFactor

        let cropRect = CGRect(x: imageX, y: imageY, width: imageWidth, height: imageHeight)

        // Clamp to image bounds
        let imageBounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let clampedRect = cropRect.intersection(imageBounds)

        guard !clampedRect.isEmpty, let cropped = image.cropping(to: clampedRect) else {
            throw ScrollingCaptureError.stitchingFailed
        }

        return cropped
    }
}
