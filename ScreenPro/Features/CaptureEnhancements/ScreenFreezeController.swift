import Foundation
import AppKit
import ScreenCaptureKit
import Combine

// MARK: - ScreenFreezeController (T048)

/// Controller managing screen freeze functionality for precise capture.
@MainActor
final class ScreenFreezeController: ObservableObject {
    // MARK: - Published Properties

    /// Current freeze state.
    @Published private(set) var state: FreezeState = .unfrozen

    /// Whether the screen is currently frozen.
    var isFrozen: Bool { state.isFrozen }

    // MARK: - Properties

    /// Freeze overlay windows per display.
    private var freezeWindows: [CGDirectDisplayID: NSWindow] = [:]

    /// Frozen images per display.
    private var frozenImages: [CGDirectDisplayID: CGImage] = [:]

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Freezes the display at the cursor location.
    func freeze() async throws {
        guard !isFrozen else { return }

        // Get the display at cursor
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) else {
            return
        }

        let displayID = screen.displayID

        // Capture the current display content
        let image = try await captureDisplay(screen)

        // Store the frozen image
        frozenImages[displayID] = image

        // Create and show the freeze overlay window
        let window = createFreezeWindow(for: screen, with: image)
        freezeWindows[displayID] = window
        window.orderFront(nil)

        // Update state
        state = .frozen(displayID: displayID)
    }

    /// Unfreezes the display and returns the frozen image for capture.
    /// - Returns: The frozen image if available.
    @discardableResult
    func unfreeze() -> CGImage? {
        guard isFrozen, let displayID = state.displayID else { return nil }

        // Get the frozen image before cleanup
        let frozenImage = frozenImages[displayID]

        // Close freeze windows
        for (_, window) in freezeWindows {
            window.orderOut(nil)
        }
        freezeWindows.removeAll()
        frozenImages.removeAll()

        // Update state
        state = .unfrozen

        return frozenImage
    }

    /// Freezes all displays.
    func freezeAll() async throws {
        guard !isFrozen else { return }

        for screen in NSScreen.screens {
            let displayID = screen.displayID
            let image = try await captureDisplay(screen)
            frozenImages[displayID] = image

            let window = createFreezeWindow(for: screen, with: image)
            freezeWindows[displayID] = window
            window.orderFront(nil)
        }

        // Use the main display for state
        if let mainDisplay = NSScreen.main?.displayID {
            state = .frozen(displayID: mainDisplay)
        }
    }

    /// Toggles freeze state.
    func toggle() async throws {
        if isFrozen {
            unfreeze()
        } else {
            try await freeze()
        }
    }

    /// Gets the frozen image for a display.
    /// - Parameter displayID: The display ID.
    /// - Returns: The frozen image if available.
    func getFrozenImage(for displayID: CGDirectDisplayID) -> CGImage? {
        frozenImages[displayID]
    }

    // MARK: - Private Methods

    /// Captures the current content of a display.
    private func captureDisplay(_ screen: NSScreen) async throws -> CGImage {
        // Get shareable content to find the display
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let scDisplay = content.displays.first(where: { $0.displayID == screen.displayID }) else {
            throw ScreenFreezeError.displayNotFound
        }

        // Create filter and configuration
        let filter = SCContentFilter(display: scDisplay, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.width = scDisplay.width * 2 // Retina
        config.height = scDisplay.height * 2
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false

        // Capture the display
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        return image
    }

    /// Creates a freeze overlay window for a screen.
    private func createFreezeWindow(for screen: NSScreen, with image: CGImage) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.isOpaque = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.ignoresMouseEvents = false // Allow clicks through for selection
        window.backgroundColor = .black

        // Create image view
        let nsImage = NSImage(cgImage: image, size: NSSize(
            width: CGFloat(image.width) / 2, // Account for Retina
            height: CGFloat(image.height) / 2
        ))

        let imageView = NSImageView(frame: window.contentView!.bounds)
        imageView.image = nsImage
        imageView.imageScaling = .scaleAxesIndependently
        imageView.autoresizingMask = [.width, .height]

        window.contentView?.addSubview(imageView)

        return window
    }
}

// Note: ScreenFreezeError is defined in ScreenFreezeError.swift

// MARK: - NSScreen Extension

extension NSScreen {
    /// Returns the display ID for this screen.
    var displayID: CGDirectDisplayID {
        let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return CGDirectDisplayID(screenNumber?.uint32Value ?? 0)
    }
}
