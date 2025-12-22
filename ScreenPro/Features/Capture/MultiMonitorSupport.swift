import Foundation
import AppKit
import ScreenCaptureKit

// MARK: - Display Info

/// Information about a display combining NSScreen and SCDisplay data.
struct DisplayInfo: Sendable {
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

    /// Retina scale factor for this display.
    var scaleFactor: CGFloat {
        screen.backingScaleFactor
    }

    /// Initializes DisplayInfo from an NSScreen and optional SCDisplay.
    init(screen: NSScreen, scDisplay: SCDisplay? = nil) {
        self.screen = screen
        self.scDisplay = scDisplay
        self.frame = screen.frame
        self.isMain = screen == NSScreen.main
    }
}

// MARK: - Display Manager Protocol

/// Protocol for managing multiple displays.
@MainActor
protocol DisplayManagerProtocol {
    /// All available displays.
    var displays: [DisplayInfo] { get }

    /// The main display.
    var mainDisplay: DisplayInfo? { get }

    /// Refreshes display information from SCShareableContent.
    func refresh(with scDisplays: [SCDisplay])

    /// Finds the display containing a point.
    func display(containing point: CGPoint) -> DisplayInfo?

    /// Finds the display with the largest intersection with a rect.
    func display(for rect: CGRect) -> DisplayInfo?
}

// MARK: - Display Manager

/// Manages multiple display configurations and coordinate conversions.
@MainActor
final class DisplayManager: DisplayManagerProtocol, ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var displays: [DisplayInfo] = []

    // MARK: - Computed Properties

    var mainDisplay: DisplayInfo? {
        displays.first { $0.isMain }
    }

    // MARK: - Initialization

    init() {
        refreshFromNSScreens()
    }

    // MARK: - Refresh Methods

    /// Refreshes displays from NSScreen.screens.
    func refreshFromNSScreens() {
        displays = NSScreen.screens.map { DisplayInfo(screen: $0) }
    }

    /// Updates display info with ScreenCaptureKit displays.
    func refresh(with scDisplays: [SCDisplay]) {
        displays = NSScreen.screens.map { screen in
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            let scDisplay = scDisplays.first { $0.displayID == displayID }
            return DisplayInfo(screen: screen, scDisplay: scDisplay)
        }
    }

    // MARK: - Query Methods

    /// Finds the display containing a point.
    func display(containing point: CGPoint) -> DisplayInfo? {
        displays.first { NSPointInRect(point, $0.frame) }
    }

    /// Finds the display with the largest intersection with a rect.
    func display(for rect: CGRect) -> DisplayInfo? {
        var bestMatch: DisplayInfo?
        var bestArea: CGFloat = 0

        for display in displays {
            let intersection = rect.intersection(display.frame)
            if !intersection.isNull {
                let area = intersection.width * intersection.height
                if area > bestArea {
                    bestArea = area
                    bestMatch = display
                }
            }
        }

        return bestMatch
    }

    /// Gets the display currently containing the mouse cursor.
    func displayAtCursor() -> DisplayInfo? {
        let mouseLocation = NSEvent.mouseLocation
        return display(containing: mouseLocation)
    }
}

// MARK: - Coordinate Conversion

extension DisplayManager {
    /// Converts screen coordinates to image coordinates with Y-axis flip.
    ///
    /// Screen coordinates have origin at bottom-left (macOS convention).
    /// Image coordinates have origin at top-left (CGImage convention).
    static func convertToImageCoordinates(
        _ rect: CGRect,
        in displayFrame: CGRect,
        imageSize: CGSize
    ) -> CGRect {
        let scaleX = imageSize.width / displayFrame.width
        let scaleY = imageSize.height / displayFrame.height

        return CGRect(
            x: (rect.origin.x - displayFrame.origin.x) * scaleX,
            y: (displayFrame.height - (rect.origin.y - displayFrame.origin.y) - rect.height) * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
    }

    /// Converts image coordinates to screen coordinates with Y-axis flip.
    static func convertToScreenCoordinates(
        _ rect: CGRect,
        in displayFrame: CGRect,
        imageSize: CGSize
    ) -> CGRect {
        let scaleX = displayFrame.width / imageSize.width
        let scaleY = displayFrame.height / imageSize.height

        return CGRect(
            x: rect.origin.x * scaleX + displayFrame.origin.x,
            y: displayFrame.origin.y + displayFrame.height - (rect.origin.y * scaleY) - (rect.height * scaleY),
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
    }
}
