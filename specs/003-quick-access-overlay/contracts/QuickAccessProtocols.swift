// MARK: - Quick Access Overlay Contracts
// Feature: 003-quick-access-overlay
// These protocols define the internal contracts between Quick Access components.
// This is a DESIGN ARTIFACT - not production code.

import Foundation
import AppKit

// MARK: - CaptureQueue Protocol

/// Manages the ordered collection of pending captures.
@MainActor
protocol CaptureQueueProtocol: ObservableObject {
    /// Ordered list of captures (newest first)
    var items: [CaptureItem] { get }

    /// Currently selected item index for keyboard navigation
    var selectedIndex: Int { get set }

    /// Whether the queue is empty
    var isEmpty: Bool { get }

    /// Currently selected item, if any
    var selected: CaptureItem? { get }

    /// Adds a capture result to the queue
    /// - Parameter result: The capture to add
    /// - Note: Inserts at index 0 (front), evicts oldest if at capacity
    func add(_ result: CaptureResult)

    /// Removes a capture from the queue
    /// - Parameter id: The UUID of the capture to remove
    func remove(_ id: UUID)

    /// Removes all captures from the queue
    func clear()

    /// Moves selection to the next item (down)
    func selectNext()

    /// Moves selection to the previous item (up)
    func selectPrevious()
}

// MARK: - QuickAccessController Protocol

/// Controls the Quick Access overlay window and user interactions.
@MainActor
protocol QuickAccessControllerProtocol: ObservableObject {
    /// The capture queue being managed
    var queue: CaptureQueueProtocol { get }

    /// Whether the overlay window is currently visible
    var isVisible: Bool { get }

    /// Adds a capture and shows the overlay
    /// - Parameter result: The capture result to display
    func addCapture(_ result: CaptureResult)

    /// Performs the Copy action on a capture
    /// - Parameter item: The capture to copy to clipboard
    func copyToClipboard(_ item: CaptureItem)

    /// Performs the Save action on a capture
    /// - Parameter item: The capture to save to disk
    /// - Throws: StorageError if save fails
    func saveToFile(_ item: CaptureItem) throws

    /// Performs the Annotate action on a capture
    /// - Parameter item: The capture to open in editor
    func openInAnnotator(_ item: CaptureItem)

    /// Dismisses a capture without saving
    /// - Parameter item: The capture to dismiss
    func dismiss(_ item: CaptureItem)

    /// Dismisses all captures and hides the overlay
    func dismissAll()

    /// Performs an action on the currently selected capture
    /// - Parameter action: The action to perform
    func performActionOnSelected(_ action: QuickAccessAction)

    /// Cancels the auto-dismiss timer (called on hover)
    func cancelAutoDismiss()
}

// MARK: - QuickAccessAction

/// Actions available in the Quick Access overlay
enum QuickAccessAction {
    /// Copy image to clipboard (Cmd+C)
    case copy

    /// Save image to default location (Cmd+S)
    case save

    /// Open image in annotation editor (Return/Enter or Cmd+A)
    case annotate

    /// Dismiss without saving (Escape or Close button)
    case dismiss
}

// MARK: - ThumbnailGenerator Protocol

/// Generates thumbnails from full-resolution captures.
protocol ThumbnailGeneratorProtocol: Actor {
    /// Generates a thumbnail from a CGImage
    /// - Parameters:
    ///   - image: The source image (full resolution)
    ///   - maxPixelSize: Maximum dimension in pixels
    ///   - scaleFactor: Retina scale factor
    /// - Returns: The generated thumbnail image
    func generateThumbnail(
        from image: CGImage,
        maxPixelSize: Int,
        scaleFactor: CGFloat
    ) async -> CGImage?
}

// MARK: - QuickAccessWindow Protocol

/// Contract for the floating overlay window.
@MainActor
protocol QuickAccessWindowProtocol {
    /// Shows the window at the configured position
    func show()

    /// Hides the window
    func hide()

    /// Updates the window position based on settings
    func updatePosition()

    /// Updates the window content size based on queue
    func updateContentSize()
}

// MARK: - AppCoordinator Integration

/// Extension contract for AppCoordinator to support Quick Access
@MainActor
protocol AppCoordinatorQuickAccessProtocol {
    /// The Quick Access controller
    var quickAccessController: QuickAccessControllerProtocol { get }

    /// Opens the annotation editor for a capture
    /// - Parameter result: The capture to annotate
    func openAnnotationEditor(for result: CaptureResult)
}

// MARK: - CaptureItem Definition

/// Represents a single capture in the Quick Access queue.
/// Defined here for contract completeness.
struct CaptureItem: Identifiable, Sendable {
    let id: UUID
    let result: CaptureResult
    var thumbnail: NSImage?
    let createdAt: Date

    var dimensions: CGSize { result.pixelSize }

    var dimensionsText: String {
        "\(Int(dimensions.width)) × \(Int(dimensions.height))"
    }

    var timeAgoText: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: createdAt)
        }
    }

    init(result: CaptureResult, thumbnail: NSImage? = nil) {
        self.id = result.id
        self.result = result
        self.thumbnail = thumbnail
        self.createdAt = Date()
    }
}

// MARK: - Keyboard Shortcut Contracts

/// Keyboard shortcuts for Quick Access overlay
enum QuickAccessShortcut {
    /// Escape - dismiss selected
    static let escape: UInt16 = 53

    /// Return/Enter - open in annotator
    static let returnKey: UInt16 = 36

    /// Down arrow - select next
    static let downArrow: UInt16 = 125

    /// Up arrow - select previous
    static let upArrow: UInt16 = 126

    /// Space - Quick Look preview (future)
    static let space: UInt16 = 49

    /// Cmd+C character
    static let copyChar: Character = "c"

    /// Cmd+S character
    static let saveChar: Character = "s"

    /// Cmd+A character
    static let annotateChar: Character = "a"
}
