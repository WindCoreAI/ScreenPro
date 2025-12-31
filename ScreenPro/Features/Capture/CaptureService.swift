import Foundation
import ScreenCaptureKit
import AppKit
import CoreImage
import UniformTypeIdentifiers

// MARK: - CaptureService Protocol

/// Protocol defining the public interface for capture operations.
/// All methods are MainActor-isolated for UI safety.
@MainActor
protocol CaptureServiceProtocol: ObservableObject {
    // MARK: - Published Properties

    /// Available displays for capture.
    var availableDisplays: [SCDisplay] { get }

    /// Available windows for capture.
    /// Filtered to exclude system windows and self.
    var availableWindows: [SCWindow] { get }

    // MARK: - Content Discovery

    /// Refreshes the list of available displays and windows.
    func refreshAvailableContent() async throws

    // MARK: - Capture Operations

    /// Captures a rectangular area of the screen.
    func captureArea(_ rect: CGRect) async throws -> CaptureResult

    /// Captures a specific window.
    func captureWindow(_ window: SCWindow) async throws -> CaptureResult

    /// Captures an entire display.
    func captureDisplay(_ display: SCDisplay?) async throws -> CaptureResult

    // MARK: - Output Operations

    /// Saves the capture result to disk.
    func save(_ result: CaptureResult) throws -> URL

    /// Copies the capture result to the system clipboard.
    func copyToClipboard(_ result: CaptureResult)

    /// Plays the capture sound if enabled in settings.
    func playCaptureSound()
}

// MARK: - CaptureService Implementation

/// Core service managing screenshot operations, content discovery, and image output.
@MainActor
final class CaptureService: ObservableObject, CaptureServiceProtocol {
    // MARK: - Published Properties

    @Published private(set) var availableDisplays: [SCDisplay] = []
    @Published private(set) var availableWindows: [SCWindow] = []

    // MARK: - Dependencies

    private let displayManager: DisplayManager
    private let storageService: StorageServiceProtocol
    private let settingsManager: SettingsManager

    // MARK: - Private Properties

    private var shareableContent: SCShareableContent?

    // MARK: - Initialization

    init(
        displayManager: DisplayManager = DisplayManager(),
        storageService: StorageServiceProtocol = StorageService(),
        settingsManager: SettingsManager
    ) {
        self.displayManager = displayManager
        self.storageService = storageService
        self.settingsManager = settingsManager
    }

    // MARK: - Content Discovery (T010)

    /// Refreshes the list of available displays and windows.
    func refreshAvailableContent() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        self.shareableContent = content
        self.availableDisplays = content.displays

        // Filter windows: exclude self, system windows, and small windows
        self.availableWindows = content.windows.filter { window in
            guard let app = window.owningApplication else { return false }
            guard window.frame.width >= 50 && window.frame.height >= 50 else { return false }
            guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return false }
            guard !(window.title?.isEmpty ?? true) || window.owningApplication != nil else { return false }
            return true
        }

        // Update display manager with SC displays
        displayManager.refresh(with: content.displays)
    }

    // MARK: - Stream Configuration Helper (T011)

    /// Creates a stream configuration for capture with Retina support.
    private func createStreamConfiguration(
        for display: SCDisplay,
        config: CaptureConfig
    ) -> SCStreamConfiguration {
        let streamConfig = SCStreamConfiguration()

        // Set resolution with scale factor for Retina
        streamConfig.width = Int(CGFloat(display.width) * config.scaleFactor)
        streamConfig.height = Int(CGFloat(display.height) * config.scaleFactor)

        // Configure capture settings
        streamConfig.showsCursor = config.includeCursor
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfig.colorSpaceName = CGColorSpace.sRGB

        // Don't scale to fit - capture at native resolution
        streamConfig.scalesToFit = false

        return streamConfig
    }

    /// Creates a stream configuration for window capture.
    private func createStreamConfiguration(
        for window: SCWindow,
        config: CaptureConfig
    ) -> SCStreamConfiguration {
        let streamConfig = SCStreamConfiguration()

        // Set resolution with scale factor for Retina
        streamConfig.width = Int(window.frame.width * config.scaleFactor)
        streamConfig.height = Int(window.frame.height * config.scaleFactor)

        // Configure capture settings
        streamConfig.showsCursor = config.includeCursor
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfig.colorSpaceName = CGColorSpace.sRGB
        streamConfig.scalesToFit = false

        return streamConfig
    }

    // MARK: - Image Cropping Helper (T012)

    /// Crops a CGImage to the specified rect with Y-axis coordinate flip.
    private func cropImage(
        _ image: CGImage,
        to rect: CGRect,
        in displayFrame: CGRect,
        scaleFactor: CGFloat
    ) throws -> CGImage {
        // Validate input rect has positive dimensions
        guard rect.width > 0 && rect.height > 0 else {
            throw CaptureError.cropFailed
        }

        // Convert screen coordinates to image coordinates
        let imageSize = CGSize(width: image.width, height: image.height)

        // Validate image has valid dimensions
        guard imageSize.width > 0 && imageSize.height > 0 else {
            throw CaptureError.cropFailed
        }

        let imageRect = DisplayManager.convertToImageCoordinates(
            rect,
            in: displayFrame,
            imageSize: imageSize
        )

        // Validate converted rect has positive dimensions and valid origin
        guard imageRect.width > 0 && imageRect.height > 0 &&
              imageRect.origin.x.isFinite && imageRect.origin.y.isFinite else {
            throw CaptureError.cropFailed
        }

        // Validate crop rect is within image bounds
        let imageBounds = CGRect(origin: .zero, size: imageSize)
        let clampedRect = imageRect.intersection(imageBounds)

        guard !clampedRect.isEmpty && clampedRect.width >= 1 && clampedRect.height >= 1 else {
            throw CaptureError.cropFailed
        }

        // Ensure integer pixel boundaries for cropping
        let integralRect = CGRect(
            x: floor(clampedRect.origin.x),
            y: floor(clampedRect.origin.y),
            width: ceil(clampedRect.width),
            height: ceil(clampedRect.height)
        ).intersection(imageBounds)

        guard !integralRect.isEmpty else {
            throw CaptureError.cropFailed
        }

        // Perform the crop
        guard let cropped = image.cropping(to: integralRect) else {
            throw CaptureError.cropFailed
        }

        return cropped
    }

    // MARK: - Capture Operations

    /// Captures a rectangular area of the screen.
    func captureArea(_ rect: CGRect) async throws -> CaptureResult {
        // Validate selection size
        guard rect.width >= 5 && rect.height >= 5 else {
            throw CaptureError.invalidSelection
        }

        // Find the display containing the selection
        guard let displayInfo = displayManager.display(for: rect),
              let scDisplay = displayInfo.scDisplay else {
            throw CaptureError.noDisplayFound
        }

        let config = CaptureConfig.from(settings: settingsManager.settings)

        // Create content filter for the display
        let filter = SCContentFilter(display: scDisplay, excludingWindows: [])

        // Create stream configuration
        let streamConfig = createStreamConfiguration(for: scDisplay, config: config)

        // Capture the display
        let capturedImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: streamConfig
        )

        // Crop to selection
        let croppedImage = try cropImage(
            capturedImage,
            to: rect,
            in: displayInfo.frame,
            scaleFactor: config.scaleFactor
        )

        return CaptureResult(
            image: croppedImage,
            mode: .area(rect),
            sourceRect: rect,
            scaleFactor: config.scaleFactor
        )
    }

    /// Captures a specific window.
    func captureWindow(_ window: SCWindow) async throws -> CaptureResult {
        let config = CaptureConfig.from(settings: settingsManager.settings)

        // Create content filter for the window (desktop-independent)
        let filter = SCContentFilter(desktopIndependentWindow: window)

        // Create stream configuration
        let streamConfig = createStreamConfiguration(for: window, config: config)

        // Capture the window
        let capturedImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: streamConfig
        )

        return CaptureResult(
            image: capturedImage,
            mode: .window(window),
            sourceRect: window.frame,
            scaleFactor: config.scaleFactor
        )
    }

    /// Captures an entire display.
    func captureDisplay(_ display: SCDisplay?) async throws -> CaptureResult {
        // Get the display to capture
        let targetDisplay: SCDisplay
        if let display = display {
            targetDisplay = display
        } else {
            // Use the display at cursor or main display
            if let displayInfo = displayManager.displayAtCursor(),
               let scDisplay = displayInfo.scDisplay {
                targetDisplay = scDisplay
            } else if let mainDisplay = availableDisplays.first {
                targetDisplay = mainDisplay
            } else {
                throw CaptureError.noDisplayFound
            }
        }

        let config = CaptureConfig.from(settings: settingsManager.settings)

        // Create content filter for the display
        let filter = SCContentFilter(display: targetDisplay, excludingWindows: [])

        // Create stream configuration
        let streamConfig = createStreamConfiguration(for: targetDisplay, config: config)

        // Capture the display
        let capturedImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: streamConfig
        )

        // Find the display frame for the result
        let displayFrame = CGRect(
            x: 0,
            y: 0,
            width: targetDisplay.width,
            height: targetDisplay.height
        )

        return CaptureResult(
            image: capturedImage,
            mode: .display(targetDisplay),
            sourceRect: displayFrame,
            scaleFactor: config.scaleFactor
        )
    }

    // MARK: - Output Operations (T013)

    /// Saves the capture result to disk.
    func save(_ result: CaptureResult) throws -> URL {
        let settings = settingsManager.settings
        let filename = settingsManager.generateFilename(for: .screenshot)

        // Convert CGImage to Data based on format
        guard let imageData = createImageData(
            from: result.image,
            format: settings.defaultImageFormat
        ) else {
            throw CaptureError.saveFailed("Failed to encode image")
        }

        // Save using StorageService
        let url = try storageService.save(
            imageData: imageData,
            filename: filename,
            to: settings.defaultSaveLocation
        )

        return url
    }

    /// Copies the capture result to the system clipboard.
    func copyToClipboard(_ result: CaptureResult) {
        storageService.copyToClipboard(image: result.nsImage)
    }

    /// Plays the capture sound if enabled in settings.
    func playCaptureSound() {
        guard settingsManager.settings.playCaptureSound else { return }
        NSSound(named: "Grab")?.play()
    }

    // MARK: - Image Encoding Helper

    /// Creates image data in the specified format.
    private func createImageData(from image: CGImage, format: ImageFormat) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: image)

        switch format {
        case .png:
            return bitmapRep.representation(using: .png, properties: [:])
        case .jpeg:
            return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        case .tiff:
            return bitmapRep.representation(using: .tiff, properties: [:])
        case .heic:
            // HEIC requires special handling, fall back to PNG for now
            return bitmapRep.representation(using: .png, properties: [:])
        }
    }
}
