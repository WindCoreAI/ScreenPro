import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - AnnotationEditorWindow (T015, T079, T080, T081, T082, T083, T086)

/// The main annotation editor window.
/// Hosts SwiftUI content in an NSWindow for proper window management.
@MainActor
final class AnnotationEditorWindowController: NSWindowController {
    // MARK: - Properties

    private var document: AnnotationDocument?
    private var toolConfig: ToolConfiguration?
    private weak var appCoordinator: AppCoordinator?
    private var captureId: UUID?
    private let storageService = StorageService()
    private let settingsManager: SettingsManager

    // MARK: - Initialization

    convenience init(result: CaptureResult, coordinator: AppCoordinator) {
        let document = AnnotationDocument(result: result)
        let toolConfig = ToolConfiguration()
        let settingsManager = coordinator.settingsManager

        // Create weak self reference for closures
        var weakSelf: AnnotationEditorWindowController?

        let contentView = AnnotationEditorView(
            document: document,
            toolConfig: toolConfig,
            onSave: {
                weakSelf?.performSave()
            },
            onCopy: {
                weakSelf?.performCopy()
            },
            onCancel: { [weak coordinator] in
                coordinator?.cancelAnnotationEditor()
            }
        )

        let hostingController = NSHostingController(rootView: contentView)

        // Calculate window size based on image
        let imageSize = CGSize(
            width: result.image.width,
            height: result.image.height
        )
        let maxSize = CGSize(width: 1200, height: 900)
        let windowSize = calculateWindowSize(imageSize: imageSize, maxSize: maxSize)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Annotation Editor"
        window.contentViewController = hostingController
        window.center()
        window.minSize = NSSize(width: 600, height: 400)
        window.isReleasedWhenClosed = false

        self.init(window: window)

        self.document = document
        self.toolConfig = toolConfig
        self.appCoordinator = coordinator
        self.captureId = result.id
        self.settingsManager = settingsManager

        // Set up window delegate
        window.delegate = self

        // Set weak self reference for closures
        weakSelf = self
    }

    private override init(window: NSWindow?) {
        self.settingsManager = SettingsManager()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        self.settingsManager = SettingsManager()
        super.init(coder: coder)
    }

    // MARK: - Save Action (T079, T081)

    /// Saves the annotated image to disk.
    func performSave() {
        guard let document = document else { return }

        // Get format from settings
        let exportFormat = ExportImageFormat(from: settingsManager.settings.defaultImageFormat)

        // Export image data
        guard let imageData = document.export(format: exportFormat) else {
            showAlert(title: "Export Failed", message: "Failed to render the annotated image.")
            return
        }

        // Generate filename
        let filename = settingsManager.generateFilename(for: .screenshot)
        let saveLocation = settingsManager.settings.defaultSaveLocation

        do {
            let savedURL = try storageService.save(imageData: imageData, filename: filename, to: saveLocation)

            // Clear undo manager to indicate saved state
            document.undoManager.removeAllActions()

            // Show success notification or close window
            NSSound(named: .init("Blow"))?.play()

            // Close the window after successful save
            window?.close()
        } catch {
            showAlert(title: "Save Failed", message: error.localizedDescription)
        }
    }

    // MARK: - Copy Action (T080, T082)

    /// Copies the annotated image to clipboard.
    func performCopy() {
        guard let document = document else { return }

        // Render image with blur applied
        guard let cgImage = document.renderWithBlur() else {
            showAlert(title: "Copy Failed", message: "Failed to render the annotated image.")
            return
        }

        let nsImage = NSImage(cgImage: cgImage, size: document.canvasSize)
        storageService.copyToClipboard(image: nsImage)

        // Play sound to indicate success
        NSSound(named: .init("Pop"))?.play()
    }

    // MARK: - Helpers

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        if let window = window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    // MARK: - Window Management

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWindow() {
        window?.close()
    }

    // MARK: - Helpers

    private static func calculateWindowSize(imageSize: CGSize, maxSize: CGSize) -> CGSize {
        let toolbarHeight: CGFloat = 50
        let padding: CGFloat = 40

        // Add space for toolbar
        let contentHeight = imageSize.height + toolbarHeight + padding

        // Scale down if larger than max
        var scale: CGFloat = 1.0
        if imageSize.width > maxSize.width {
            scale = min(scale, maxSize.width / imageSize.width)
        }
        if contentHeight > maxSize.height {
            scale = min(scale, maxSize.height / contentHeight)
        }

        return CGSize(
            width: max(imageSize.width * scale + padding, 600),
            height: max(contentHeight * scale, 400)
        )
    }
}

// MARK: - NSWindowDelegate (T083, T086)

extension AnnotationEditorWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Notify coordinator
        appCoordinator?.annotationEditorDidClose()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Check for unsaved changes (T083)
        guard let document = document, document.hasUnsavedChanges else {
            return true
        }

        // Show unsaved changes prompt
        let alert = NSAlert()
        alert.messageText = "Unsaved Changes"
        alert.informativeText = "Do you want to save your annotations before closing?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")

        guard let window = window else { return true }

        alert.beginSheetModal(for: window) { [weak self] response in
            switch response {
            case .alertFirstButtonReturn:
                // Save
                self?.performSave()
            case .alertSecondButtonReturn:
                // Don't Save - just close
                window.close()
            default:
                // Cancel - do nothing
                break
            }
        }

        return false
    }
}

// MARK: - AnnotationEditorView

/// The main SwiftUI view for the annotation editor.
struct AnnotationEditorView: View {
    @ObservedObject var document: AnnotationDocument
    @ObservedObject var toolConfig: ToolConfiguration

    var onSave: () -> Void
    var onCopy: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar at top
            AnnotationToolbar(
                toolConfig: toolConfig,
                document: document,
                onSave: onSave,
                onCopy: onCopy,
                onCancel: onCancel
            )

            Divider()

            // Canvas
            AnnotationCanvasView(
                document: document,
                toolConfig: toolConfig
            )
        }
    }
}

// MARK: - AppCoordinator Extension (T017)

extension AppCoordinator {
    /// Opens the annotation editor for a capture result.
    func openAnnotationEditor(for result: CaptureResult) {
        state = .annotating(result.id)

        let windowController = AnnotationEditorWindowController(
            result: result,
            coordinator: self
        )
        annotationEditorController = windowController
        windowController.showWindow()
    }

    /// Closes the annotation editor.
    func closeAnnotationEditor() {
        (annotationEditorController as? AnnotationEditorWindowController)?.closeWindow()
        annotationEditorController = nil
        state = .idle
    }

    /// Called when the user cancels the annotation editor.
    func cancelAnnotationEditor() {
        closeAnnotationEditor()
    }

    /// Called when the annotation editor window closes.
    func annotationEditorDidClose() {
        annotationEditorController = nil
        if case .annotating = state {
            state = .idle
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AnnotationEditorView_Previews: PreviewProvider {
    static var previews: some View {
        let testImage = createTestImage()
        let document = AnnotationDocument(image: testImage)
        let toolConfig = ToolConfiguration()

        AnnotationEditorView(
            document: document,
            toolConfig: toolConfig,
            onSave: {},
            onCopy: {},
            onCancel: {}
        )
        .frame(width: 800, height: 600)
    }

    static func createTestImage() -> CGImage {
        let width = 800
        let height = 600

        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!

        // Fill with light gray
        context.setFillColor(CGColor(gray: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Add some sample content
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 100, y: 100, width: 200, height: 150))

        context.setFillColor(CGColor(red: 0.8, green: 0.3, blue: 0.2, alpha: 1))
        context.fillEllipse(in: CGRect(x: 400, y: 200, width: 150, height: 150))

        return context.makeImage()!
    }
}
#endif
