// MARK: - CaptureService Contract
// Feature: 002-basic-capture
// This file defines the public interface for CaptureService.
// Implementation must conform to this protocol.

import Foundation
import ScreenCaptureKit
import AppKit

// MARK: - Capture Mode

/// Defines the type of capture operation to perform.
enum CaptureMode {
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
struct CaptureConfig {
    /// Whether to include the cursor in the capture.
    var includeCursor: Bool = false

    /// Output image format.
    var imageFormat: ImageFormat = .png

    /// Retina scale factor (typically 2.0 for Retina displays).
    var scaleFactor: CGFloat = 2.0
}

// MARK: - Capture Result

/// The result of a successful capture operation.
struct CaptureResult {
    /// Unique identifier for this capture.
    let id: UUID

    /// The captured image at native resolution.
    let image: CGImage

    /// The capture mode that was used.
    let mode: CaptureMode

    /// When the capture occurred.
    let timestamp: Date

    /// Original screen coordinates of the captured area.
    let sourceRect: CGRect

    /// Converts the CGImage to NSImage for clipboard/UI display.
    var nsImage: NSImage {
        // Scale to logical pixels (divide by scale factor)
        NSImage(cgImage: image, size: NSSize(
            width: CGFloat(image.width) / 2,
            height: CGFloat(image.height) / 2
        ))
    }
}

// MARK: - Capture Errors

/// Errors that can occur during capture operations.
enum CaptureError: LocalizedError {
    /// No display found for the specified capture area.
    case noDisplayFound

    /// Failed to crop the captured image to the selection.
    case cropFailed

    /// Screen recording permission was not granted.
    case permissionDenied

    /// Selection is too small (< 5x5 pixels).
    case invalidSelection

    /// User cancelled the capture operation.
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noDisplayFound:
            return "No display found for capture area"
        case .cropFailed:
            return "Failed to crop captured image"
        case .permissionDenied:
            return "Screen recording permission denied"
        case .invalidSelection:
            return "Selection too small (minimum 5x5 pixels)"
        case .cancelled:
            return "Capture cancelled"
        }
    }
}

// MARK: - CaptureService Protocol

/// Protocol defining the public interface for capture operations.
/// All methods are MainActor-isolated for UI safety.
@MainActor
protocol CaptureServiceProtocol: ObservableObject {
    // MARK: - Published Properties

    /// Available displays for capture.
    /// Updated after calling refreshAvailableContent().
    var availableDisplays: [SCDisplay] { get }

    /// Available windows for capture.
    /// Filtered to exclude system windows and self.
    var availableWindows: [SCWindow] { get }

    // MARK: - Content Discovery

    /// Refreshes the list of available displays and windows.
    /// Must be called before capture operations.
    /// - Throws: If ScreenCaptureKit fails to enumerate content.
    func refreshAvailableContent() async throws

    // MARK: - Capture Operations

    /// Captures a rectangular area of the screen.
    /// - Parameter rect: The area to capture in screen coordinates.
    /// - Returns: The capture result containing the image and metadata.
    /// - Throws: CaptureError if capture fails.
    func captureArea(_ rect: CGRect) async throws -> CaptureResult

    /// Captures a specific window.
    /// - Parameter window: The window to capture.
    /// - Returns: The capture result containing the image and metadata.
    /// - Throws: CaptureError if capture fails.
    func captureWindow(_ window: SCWindow) async throws -> CaptureResult

    /// Captures an entire display.
    /// - Parameter display: The display to capture. If nil, captures the main display.
    /// - Returns: The capture result containing the image and metadata.
    /// - Throws: CaptureError if capture fails.
    func captureDisplay(_ display: SCDisplay?) async throws -> CaptureResult

    // MARK: - Output Operations

    /// Saves the capture result to disk.
    /// Uses the configured save location and filename pattern.
    /// - Parameter result: The capture result to save.
    /// - Returns: The URL where the file was saved.
    /// - Throws: If file write fails.
    func save(_ result: CaptureResult) throws -> URL

    /// Copies the capture result to the system clipboard.
    /// - Parameter result: The capture result to copy.
    func copyToClipboard(_ result: CaptureResult)
}

// MARK: - Display Manager Protocol

/// Protocol for managing multiple displays.
@MainActor
protocol DisplayManagerProtocol {
    /// All available displays.
    var displays: [DisplayInfo] { get }

    /// The main display.
    var mainDisplay: DisplayInfo? { get }

    /// Finds the display containing a point.
    /// - Parameter point: The point in screen coordinates.
    /// - Returns: The display containing the point, or nil.
    func display(containing point: CGPoint) -> DisplayInfo?

    /// Finds the display with the largest intersection with a rect.
    /// - Parameter rect: The rect in screen coordinates.
    /// - Returns: The best matching display, or nil.
    func display(for rect: CGRect) -> DisplayInfo?
}

/// Information about a display.
struct DisplayInfo {
    /// AppKit screen reference.
    let screen: NSScreen

    /// ScreenCaptureKit display (after content refresh).
    let scDisplay: SCDisplay?

    /// Screen frame in global coordinates.
    let frame: CGRect

    /// Whether this is the main display.
    let isMain: Bool

    /// Core Graphics display identifier.
    var displayID: CGDirectDisplayID {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }
}

// MARK: - Selection Overlay Protocol

/// Protocol for the area selection overlay window.
@MainActor
protocol SelectionOverlayProtocol {
    /// Begins the selection process.
    /// - Parameter completion: Called with the selected rect, or nil if cancelled.
    func beginSelection(completion: @escaping (CGRect?) -> Void)

    /// Cancels the current selection.
    func cancel()
}

// MARK: - Window Picker Protocol

/// Protocol for the window picker controller.
@MainActor
protocol WindowPickerProtocol {
    /// Presents the window picker and waits for user selection.
    /// - Parameter windows: Available windows to choose from.
    /// - Returns: The selected window, or nil if cancelled.
    func pickWindow(from windows: [SCWindow]) async -> SCWindow?
}
