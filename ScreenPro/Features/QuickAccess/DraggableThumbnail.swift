import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - DraggableThumbnail

/// SwiftUI wrapper for a draggable thumbnail image using AppKit NSDraggingSource.
/// Provides drag-and-drop support for external applications like Finder, Slack, Messages, etc.
struct DraggableThumbnail: NSViewRepresentable {
    // MARK: - Properties

    /// The image to display and make draggable.
    let image: NSImage

    /// The full-resolution image for drag data.
    let fullImage: NSImage

    /// Callback when drag operation starts.
    var onDragStarted: (() -> Void)?

    /// Callback when drag operation ends.
    var onDragEnded: (() -> Void)?

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> DragSourceImageView {
        let view = DragSourceImageView(
            image: image,
            fullImage: fullImage
        )
        view.onDragStarted = onDragStarted
        view.onDragEnded = onDragEnded
        return view
    }

    func updateNSView(_ nsView: DragSourceImageView, context: Context) {
        nsView.displayImage = image
        nsView.fullImage = fullImage
        nsView.onDragStarted = onDragStarted
        nsView.onDragEnded = onDragEnded
        nsView.needsDisplay = true
    }
}

// MARK: - DragSourceImageView

/// NSView subclass that implements NSDraggingSource for image drag operations.
final class DragSourceImageView: NSView, NSDraggingSource, NSFilePromiseProviderDelegate {
    // MARK: - Properties

    /// The display image (thumbnail).
    var displayImage: NSImage

    /// The full-resolution image for drag data.
    var fullImage: NSImage

    /// Callback when drag starts.
    var onDragStarted: (() -> Void)?

    /// Callback when drag ends.
    var onDragEnded: (() -> Void)?

    /// File promise queue for async file operations.
    private lazy var filePromiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()

    // MARK: - Initialization

    init(image: NSImage, fullImage: NSImage) {
        self.displayImage = image
        self.fullImage = fullImage
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw the image scaled to fit
        displayImage.draw(
            in: bounds,
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: true,
            hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)]
        )
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        onDragStarted?()

        // Create dragging items
        var draggingItems: [NSDraggingItem] = []

        // Create file promise for Finder
        let filePromiseProvider = NSFilePromiseProvider(
            fileType: UTType.png.identifier,
            delegate: self
        )
        filePromiseProvider.userInfo = ["image": fullImage]

        let promiseItem = NSDraggingItem(pasteboardWriter: filePromiseProvider)
        promiseItem.setDraggingFrame(bounds, contents: displayImage)
        draggingItems.append(promiseItem)

        // Create pasteboard item with image data for other apps
        let pasteboardItem = NSPasteboardItem()

        // Add TIFF representation
        if let tiffData = fullImage.tiffRepresentation {
            pasteboardItem.setData(tiffData, forType: .tiff)
        }

        // Add PNG representation
        if let pngData = fullImage.pngData() {
            pasteboardItem.setData(pngData, forType: .png)
        }

        let imageItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        imageItem.setDraggingFrame(bounds, contents: displayImage)
        draggingItems.append(imageItem)

        // Start the drag session
        let session = beginDraggingSession(
            with: draggingItems,
            event: event,
            source: self
        )
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .pile
    }

    // MARK: - NSDraggingSource

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        // Allow copy operations for both external and internal contexts
        return .copy
    }

    func draggingSession(
        _ session: NSDraggingSession,
        willBeginAt screenPoint: NSPoint
    ) {
        // Set opacity during drag
        alphaValue = 0.5
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        // Restore opacity
        alphaValue = 1.0
        onDragEnded?()
    }

    // MARK: - NSFilePromiseProviderDelegate

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        fileNameForType fileType: String
    ) -> String {
        // Generate unique filename with timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = formatter.string(from: Date())
        return "Screenshot \(timestamp).png"
    }

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping (Error?) -> Void
    ) {
        // Write the PNG file to the destination
        guard let userInfo = filePromiseProvider.userInfo as? [String: Any],
              let image = userInfo["image"] as? NSImage,
              let pngData = image.pngData() else {
            completionHandler(CocoaError(.fileWriteUnknown))
            return
        }

        do {
            try pngData.write(to: url, options: .atomic)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        return filePromiseQueue
    }
}

// MARK: - NSImage PNG Extension

extension NSImage {
    /// Returns PNG data representation of the image.
    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapRep.representation(using: .png, properties: [:])
    }
}
