import Foundation
import ScreenCaptureKit

// MARK: - Capture Mode

/// Defines the type of capture operation to perform.
enum CaptureMode: Sendable {
    /// Capture a user-selected rectangular area on screen.
    /// The CGRect is in screen coordinates.
    case area(CGRect)

    /// Capture a specific application window.
    case window(SCWindow)

    /// Capture an entire display.
    case display(SCDisplay)
}

// MARK: - Capture Configuration

/// Configuration options for capture operations.
/// Populated from user settings.
struct CaptureConfig: Sendable {
    /// Whether to include the cursor in the capture.
    var includeCursor: Bool = false

    /// Output image format.
    var imageFormat: ImageFormat = .png

    /// Retina scale factor (typically 2.0 for Retina displays).
    var scaleFactor: CGFloat = 2.0

    /// Creates a configuration from current settings.
    @MainActor
    static func from(settings: Settings) -> CaptureConfig {
        CaptureConfig(
            includeCursor: settings.includeCursor,
            imageFormat: settings.defaultImageFormat,
            scaleFactor: NSScreen.main?.backingScaleFactor ?? 2.0
        )
    }
}
