import AppKit
import SwiftUI
import Combine

// MARK: - QuickAccessWindowController

/// Controls the Quick Access overlay window and manages user interactions.
/// Coordinates between the capture queue, window display, and action handling.
@MainActor
final class QuickAccessWindowController: ObservableObject {
    // MARK: - Published Properties

    /// Whether the overlay window is currently visible.
    @Published private(set) var isVisible: Bool = false

    // MARK: - Properties

    /// The capture queue being managed.
    let queue: CaptureQueue

    /// Thumbnail generator for async image processing.
    private let thumbnailGenerator: ThumbnailGenerator

    /// Reference to settings manager for configuration.
    private let settingsManager: SettingsManager

    /// Reference to capture service for save/copy operations.
    private let captureService: CaptureService

    /// Weak reference to app coordinator for annotation editor.
    private weak var coordinator: AppCoordinator?

    /// The overlay window.
    private var window: QuickAccessWindow?

    /// Cancellables for Combine subscriptions.
    private var cancellables = Set<AnyCancellable>()

    /// Auto-dismiss timer.
    private var autoDismissTimer: Timer?

    // MARK: - Initialization

    /// Creates a new Quick Access controller.
    /// - Parameters:
    ///   - settingsManager: The settings manager for configuration.
    ///   - captureService: The capture service for save/copy operations.
    ///   - coordinator: The app coordinator for annotation editor.
    init(
        settingsManager: SettingsManager,
        captureService: CaptureService,
        coordinator: AppCoordinator? = nil
    ) {
        self.queue = CaptureQueue()
        self.thumbnailGenerator = ThumbnailGenerator()
        self.settingsManager = settingsManager
        self.captureService = captureService
        self.coordinator = coordinator

        setupQueueObserver()
    }

    // MARK: - Window Management

    /// Shows the overlay window at the configured position.
    func show() {
        if window == nil {
            createWindow()
        }

        updatePosition()
        updateContentSize()
        window?.makeKeyAndOrderFront(nil)
        isVisible = true

        // Start auto-dismiss timer if configured
        startAutoDismissTimer()
    }

    /// Hides the overlay window.
    func hide() {
        window?.orderOut(nil)
        isVisible = false
        stopAutoDismissTimer()
    }

    /// Updates the window position based on settings.
    func updatePosition() {
        guard let window = window,
              let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size
        let padding: CGFloat = 20

        var origin: CGPoint

        switch settingsManager.settings.quickAccessPosition {
        case .bottomLeft:
            origin = CGPoint(
                x: screenFrame.minX + padding,
                y: screenFrame.minY + padding
            )
        case .bottomRight:
            origin = CGPoint(
                x: screenFrame.maxX - windowSize.width - padding,
                y: screenFrame.minY + padding
            )
        case .topLeft:
            origin = CGPoint(
                x: screenFrame.minX + padding,
                y: screenFrame.maxY - windowSize.height - padding
            )
        case .topRight:
            origin = CGPoint(
                x: screenFrame.maxX - windowSize.width - padding,
                y: screenFrame.maxY - windowSize.height - padding
            )
        }

        window.setFrameOrigin(origin)
    }

    /// Updates the window content size based on queue count.
    func updateContentSize() {
        guard let window = window else { return }

        // Base dimensions
        let itemHeight: CGFloat = 100
        let padding: CGFloat = 16
        let minHeight: CGFloat = 120
        let maxVisibleHeight = CGFloat(queue.maxVisibleItems) * itemHeight + padding * 2

        // Calculate height based on item count
        let contentHeight = CGFloat(max(1, queue.count)) * itemHeight + padding * 2
        let finalHeight = min(contentHeight, maxVisibleHeight)

        let newSize = NSSize(width: 320, height: max(minHeight, finalHeight))

        // Preserve position corner when resizing
        let currentFrame = window.frame
        var newFrame = currentFrame
        newFrame.size = newSize

        // Adjust origin based on position setting to keep corner anchored
        switch settingsManager.settings.quickAccessPosition {
        case .bottomLeft, .bottomRight:
            // Bottom-anchored: origin stays the same
            break
        case .topLeft, .topRight:
            // Top-anchored: adjust origin to keep top edge fixed
            newFrame.origin.y = currentFrame.maxY - newSize.height
        }

        window.setFrame(newFrame, display: true, animate: true)
    }

    // MARK: - Capture Management

    /// Adds a capture and shows the overlay.
    /// - Parameter result: The capture result to display.
    func addCapture(_ result: CaptureResult) {
        // Add to queue
        let item = queue.add(result)

        // Generate thumbnail asynchronously
        Task {
            if let thumbnail = await thumbnailGenerator.generateThumbnail(
                from: result.image,
                maxPixelSize: 240,
                scaleFactor: result.scaleFactor
            ) {
                let nsImage = NSImage(
                    cgImage: thumbnail,
                    size: NSSize(
                        width: CGFloat(thumbnail.width) / result.scaleFactor,
                        height: CGFloat(thumbnail.height) / result.scaleFactor
                    )
                )
                queue.updateThumbnail(for: item.id, thumbnail: nsImage)
            }
        }

        // Show window
        show()
    }

    // MARK: - Actions

    /// Copies a capture to the clipboard.
    /// - Parameter item: The capture to copy.
    func copyToClipboard(_ item: CaptureItem) {
        captureService.copyToClipboard(item.result)
        queue.remove(item.id)
        hideIfEmpty()
    }

    /// Saves a capture to disk.
    /// - Parameter item: The capture to save.
    /// - Throws: StorageError if save fails.
    func saveToFile(_ item: CaptureItem) throws {
        _ = try captureService.save(item.result)
        queue.remove(item.id)
        hideIfEmpty()
    }

    /// Opens a capture in the annotation editor.
    /// - Parameter item: The capture to annotate.
    func openInAnnotator(_ item: CaptureItem) {
        coordinator?.openAnnotationEditor(for: item.result)
        queue.remove(item.id)
        hideIfEmpty()
    }

    /// Dismisses a capture without saving.
    /// - Parameter item: The capture to dismiss.
    func dismiss(_ item: CaptureItem) {
        queue.remove(item.id)
        hideIfEmpty()
    }

    /// Dismisses all captures and hides the overlay.
    func dismissAll() {
        queue.clear()
        hide()
    }

    /// Performs an action on the currently selected capture.
    /// - Parameter action: The action to perform.
    func performActionOnSelected(_ action: QuickAccessAction) {
        guard let item = queue.selected else { return }

        switch action {
        case .copy:
            copyToClipboard(item)
        case .save:
            do {
                try saveToFile(item)
            } catch {
                // Error handling will be added in US3
                print("Save failed: \(error)")
            }
        case .annotate:
            openInAnnotator(item)
        case .dismiss:
            dismiss(item)
        }
    }

    /// Cancels the auto-dismiss timer (called on user interaction).
    func cancelAutoDismiss() {
        stopAutoDismissTimer()
    }

    /// Restarts the auto-dismiss timer after interaction ends.
    func restartAutoDismiss() {
        startAutoDismissTimer()
    }

    // MARK: - Private Methods

    private func createWindow() {
        let newWindow = QuickAccessWindow(controller: self)

        // Set up SwiftUI content view
        let contentView = QuickAccessContentView(controller: self)
        newWindow.contentView = NSHostingView(rootView: contentView)

        window = newWindow
    }

    private func setupQueueObserver() {
        // Observe queue changes to update window size
        queue.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateContentSize()
            }
            .store(in: &cancellables)
    }

    private func hideIfEmpty() {
        if queue.isEmpty {
            hide()
        }
    }

    private func startAutoDismissTimer() {
        stopAutoDismissTimer()

        let delay = settingsManager.settings.autoDismissDelay
        guard delay > 0 else { return }

        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismissAll()
            }
        }
    }

    private func stopAutoDismissTimer() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
    }
}
