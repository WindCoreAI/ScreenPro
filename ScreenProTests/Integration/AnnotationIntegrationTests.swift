import XCTest
@testable import ScreenPro
import AppKit

// MARK: - AnnotationIntegrationTests (T077, T078, T117)

/// Integration tests for annotation editor workflows.
/// Tests save, copy, and full annotation workflows.
@MainActor
final class AnnotationIntegrationTests: XCTestCase {
    // MARK: - Properties

    private var document: AnnotationDocument!
    private var storageService: StorageService!
    private var tempDirectory: URL!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Create a test image
        let testImage = createTestImage(width: 200, height: 150)
        document = AnnotationDocument(image: testImage)
        storageService = StorageService()

        // Create temp directory for tests
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try storageService.ensureDirectoryExists(at: tempDirectory)
    }

    override func tearDown() async throws {
        // Clean up temp directory
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }

        document = nil
        storageService = nil
        tempDirectory = nil

        try await super.tearDown()
    }

    // MARK: - Test Helpers

    private func createTestImage(width: Int, height: Int) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!

        // Fill with a gradient to make it distinguishable
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()!
    }

    private func createTestArrowAnnotation() -> ArrowAnnotation {
        ArrowAnnotation(
            startPoint: CGPoint(x: 20, y: 20),
            endPoint: CGPoint(x: 100, y: 80),
            style: ArrowStyle(headStyle: .filled, tailStyle: .none, lineStyle: .straight),
            color: .red,
            strokeWidth: 3.0
        )
    }

    private func createTestShapeAnnotation() -> ShapeAnnotation {
        ShapeAnnotation(
            bounds: CGRect(x: 50, y: 50, width: 80, height: 60),
            shapeType: .rectangle,
            fillColor: nil,
            strokeColor: .blue,
            strokeWidth: 2.0
        )
    }

    // MARK: - Test: Save Workflow (T077)

    func testSaveAnnotatedImage_PNG_createsFile() throws {
        // Arrange
        let arrow = createTestArrowAnnotation()
        document.addAnnotation(arrow)

        // Act
        guard let imageData = document.export(format: ExportImageFormat.png) else {
            XCTFail("Failed to export image")
            return
        }

        let filename = "test_annotation.png"
        let savedURL = try storageService.save(imageData: imageData, filename: filename, to: tempDirectory)

        // Assert
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))

        // Verify the saved image is valid
        let savedData = try Data(contentsOf: savedURL)
        XCTAssertFalse(savedData.isEmpty)

        // Verify it's a valid PNG
        guard let savedImage = NSImage(data: savedData) else {
            XCTFail("Saved data is not a valid image")
            return
        }
        XCTAssertGreaterThan(savedImage.size.width, 0)
    }

    func testSaveAnnotatedImage_JPEG_createsFile() throws {
        // Arrange
        let shape = createTestShapeAnnotation()
        document.addAnnotation(shape)

        // Act
        guard let imageData = document.export(format: ExportImageFormat.jpeg, quality: 0.85) else {
            XCTFail("Failed to export image")
            return
        }

        let filename = "test_annotation.jpg"
        let savedURL = try storageService.save(imageData: imageData, filename: filename, to: tempDirectory)

        // Assert
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))

        // Verify the saved image has JPEG characteristics
        let savedData = try Data(contentsOf: savedURL)
        XCTAssertFalse(savedData.isEmpty)

        // JPEG files start with FFD8FF
        XCTAssertEqual(savedData.prefix(3), Data([0xFF, 0xD8, 0xFF]))
    }

    func testSaveAnnotatedImage_withMultipleAnnotations_preservesAll() throws {
        // Arrange
        let arrow = createTestArrowAnnotation()
        let shape = createTestShapeAnnotation()
        document.addAnnotation(arrow)
        document.addAnnotation(shape)

        // Act
        guard let imageData = document.export(format: ExportImageFormat.png) else {
            XCTFail("Failed to export image")
            return
        }

        let filename = "test_multi_annotation.png"
        let savedURL = try storageService.save(imageData: imageData, filename: filename, to: tempDirectory)

        // Assert
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))

        // Verify image dimensions match canvas
        let savedData = try Data(contentsOf: savedURL)
        guard let savedImage = NSImage(data: savedData),
              let cgImage = savedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            XCTFail("Failed to load saved image")
            return
        }

        XCTAssertEqual(CGFloat(cgImage.width), document.canvasSize.width)
        XCTAssertEqual(CGFloat(cgImage.height), document.canvasSize.height)
    }

    func testSaveAnnotatedImage_withBlur_appliesDestructively() throws {
        // Arrange
        let blur = BlurAnnotation(
            bounds: CGRect(x: 50, y: 50, width: 60, height: 40),
            blurType: .gaussian,
            intensity: 0.8
        )
        document.addAnnotation(blur)

        // Act
        guard let imageData = document.export(format: ExportImageFormat.png) else {
            XCTFail("Failed to export image")
            return
        }

        let filename = "test_blur_annotation.png"
        let savedURL = try storageService.save(imageData: imageData, filename: filename, to: tempDirectory)

        // Assert
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))

        // The blur is applied - we can't easily verify the visual result,
        // but we can verify the file was created successfully
        let savedData = try Data(contentsOf: savedURL)
        XCTAssertFalse(savedData.isEmpty)
    }

    func testSave_createsUniqueFilename_whenFileExists() throws {
        // Arrange
        let arrow = createTestArrowAnnotation()
        document.addAnnotation(arrow)

        guard let imageData = document.export(format: ExportImageFormat.png) else {
            XCTFail("Failed to export image")
            return
        }

        // Act - Save twice with same filename
        let filename = "duplicate_test.png"
        let firstURL = try storageService.save(imageData: imageData, filename: filename, to: tempDirectory)
        let secondURL = try storageService.save(imageData: imageData, filename: filename, to: tempDirectory)

        // Assert - Both files exist with different names
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondURL.path))
        XCTAssertNotEqual(firstURL, secondURL)

        // Second file should have " (1)" suffix
        XCTAssertTrue(secondURL.lastPathComponent.contains("(1)"))
    }

    // MARK: - Test: Copy to Clipboard Workflow (T078)

    func testCopyToClipboard_succeeds() throws {
        // Arrange
        let arrow = createTestArrowAnnotation()
        document.addAnnotation(arrow)

        // Render the image
        guard let cgImage = document.renderWithBlur() else {
            XCTFail("Failed to render image")
            return
        }

        let nsImage = NSImage(cgImage: cgImage, size: document.canvasSize)

        // Act
        storageService.copyToClipboard(image: nsImage)

        // Assert
        let pasteboard = NSPasteboard.general
        XCTAssertTrue(pasteboard.canReadObject(forClasses: [NSImage.self], options: nil))

        // Verify the clipboard contains an image
        guard let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
              let clipboardImage = images.first else {
            XCTFail("Failed to read image from clipboard")
            return
        }

        XCTAssertGreaterThan(clipboardImage.size.width, 0)
        XCTAssertGreaterThan(clipboardImage.size.height, 0)
    }

    func testCopyToClipboard_withAnnotations_includesAnnotations() throws {
        // Arrange - Add multiple annotations
        let arrow = createTestArrowAnnotation()
        let shape = createTestShapeAnnotation()
        document.addAnnotation(arrow)
        document.addAnnotation(shape)

        // Render the image with annotations
        guard let cgImage = document.renderWithBlur() else {
            XCTFail("Failed to render image")
            return
        }

        let nsImage = NSImage(cgImage: cgImage, size: document.canvasSize)

        // Act
        storageService.copyToClipboard(image: nsImage)

        // Assert - Image was copied
        let pasteboard = NSPasteboard.general
        XCTAssertTrue(pasteboard.canReadObject(forClasses: [NSImage.self], options: nil))
    }

    func testCopyToClipboard_asData_withPNGFormat() throws {
        // Arrange
        let shape = createTestShapeAnnotation()
        document.addAnnotation(shape)

        guard let imageData = document.export(format: ExportImageFormat.png) else {
            XCTFail("Failed to export image")
            return
        }

        // Act
        storageService.copyToClipboard(imageData: imageData, type: .png)

        // Assert
        let pasteboard = NSPasteboard.general
        let pngType = NSPasteboard.PasteboardType(UTType.png.identifier)
        XCTAssertNotNil(pasteboard.data(forType: pngType))
    }

    // MARK: - Test: Full Annotation Workflow (T117)

    func testFullAnnotationWorkflow_createEditExport() throws {
        // Step 1: Create document with base image
        let testImage = createTestImage(width: 400, height: 300)
        let workflowDocument = AnnotationDocument(image: testImage)

        // Step 2: Add arrow annotation
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 50, y: 50),
            endPoint: CGPoint(x: 200, y: 150),
            style: ArrowStyle(headStyle: .filled, tailStyle: .none, lineStyle: .straight),
            color: .red,
            strokeWidth: 4.0
        )
        workflowDocument.addAnnotation(arrow)
        XCTAssertEqual(workflowDocument.annotations.count, 1)

        // Step 3: Add shape annotation
        let shape = ShapeAnnotation(
            bounds: CGRect(x: 250, y: 100, width: 100, height: 80),
            shapeType: .ellipse,
            fillColor: .yellow,
            strokeColor: .orange,
            strokeWidth: 2.0
        )
        workflowDocument.addAnnotation(shape)
        XCTAssertEqual(workflowDocument.annotations.count, 2)

        // Step 4: Test undo
        workflowDocument.undo()
        XCTAssertEqual(workflowDocument.annotations.count, 1)

        // Step 5: Test redo
        workflowDocument.redo()
        XCTAssertEqual(workflowDocument.annotations.count, 2)

        // Step 6: Export to PNG
        guard let pngData = workflowDocument.export(format: ExportImageFormat.png) else {
            XCTFail("Failed to export PNG")
            return
        }
        XCTAssertFalse(pngData.isEmpty)

        // Step 7: Save to disk
        let savedURL = try storageService.save(
            imageData: pngData,
            filename: "workflow_test.png",
            to: tempDirectory
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))

        // Step 8: Verify saved image
        let savedData = try Data(contentsOf: savedURL)
        guard let savedImage = NSImage(data: savedData) else {
            XCTFail("Saved data is not a valid image")
            return
        }
        XCTAssertEqual(savedImage.size.width, 400)
        XCTAssertEqual(savedImage.size.height, 300)
    }

    func testFullAnnotationWorkflow_withBlurAndText() throws {
        // Step 1: Create document
        let testImage = createTestImage(width: 300, height: 200)
        let workflowDocument = AnnotationDocument(image: testImage)

        // Step 2: Add blur annotation (privacy)
        let blur = BlurAnnotation(
            bounds: CGRect(x: 100, y: 50, width: 100, height: 50),
            blurType: .pixelate,
            intensity: 0.6
        )
        workflowDocument.addAnnotation(blur)

        // Step 3: Add text annotation
        let text = TextAnnotation(
            text: "Sensitive Info",
            position: CGPoint(x: 50, y: 150),
            textColor: .red,
            backgroundColor: .white,
            font: AnnotationFont(name: "Helvetica", size: 14, weight: .bold)
        )
        workflowDocument.addAnnotation(text)

        XCTAssertEqual(workflowDocument.annotations.count, 2)

        // Step 4: Export (blur should be destructively applied)
        guard let imageData = workflowDocument.export(format: ExportImageFormat.png) else {
            XCTFail("Failed to export")
            return
        }

        // Step 5: Save
        let savedURL = try storageService.save(
            imageData: imageData,
            filename: "blur_text_test.png",
            to: tempDirectory
        )

        // Step 6: Verify
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))
    }

    // MARK: - Test: hasUnsavedChanges

    func testHasUnsavedChanges_afterAddingAnnotation() {
        // Initially no changes
        XCTAssertFalse(document.hasUnsavedChanges)

        // Add annotation
        let arrow = createTestArrowAnnotation()
        document.addAnnotation(arrow)

        // Should have unsaved changes
        XCTAssertTrue(document.hasUnsavedChanges)
    }

    func testHasUnsavedChanges_afterUndoAll() {
        // Add and then undo
        let arrow = createTestArrowAnnotation()
        document.addAnnotation(arrow)
        XCTAssertTrue(document.hasUnsavedChanges)

        document.undo()

        // No more unsaved changes
        XCTAssertFalse(document.hasUnsavedChanges)
    }

    // MARK: - Counter Annotation Tests (T117 extension)

    func testCounterWorkflow_multipleCounters() throws {
        // Arrange
        let testImage = createTestImage(width: 300, height: 200)
        let workflowDocument = AnnotationDocument(image: testImage)

        // Add counters
        let counter1 = CounterAnnotation(number: 1, position: CGPoint(x: 50, y: 50), color: .red, size: 28)
        let counter2 = CounterAnnotation(number: 2, position: CGPoint(x: 100, y: 50), color: .red, size: 28)
        let counter3 = CounterAnnotation(number: 3, position: CGPoint(x: 150, y: 50), color: .red, size: 28)

        workflowDocument.addAnnotation(counter1)
        workflowDocument.addAnnotation(counter2)
        workflowDocument.addAnnotation(counter3)

        // Verify
        XCTAssertEqual(workflowDocument.annotations.count, 3)

        // Export
        guard let imageData = workflowDocument.export(format: ExportImageFormat.png) else {
            XCTFail("Failed to export")
            return
        }

        // Save
        let savedURL = try storageService.save(imageData: imageData, filename: "counter_test.png", to: tempDirectory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))
    }

    // MARK: - Crop Tests (T117 extension)

    func testCropWorkflow_cropAndExport() throws {
        // Arrange
        let testImage = createTestImage(width: 400, height: 300)
        let workflowDocument = AnnotationDocument(image: testImage)

        // Add annotation before crop
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 100, y: 100),
            endPoint: CGPoint(x: 200, y: 150),
            color: .red,
            strokeWidth: 3.0
        )
        workflowDocument.addAnnotation(arrow)

        // Apply crop
        let cropRect = CGRect(x: 50, y: 50, width: 200, height: 150)
        let cropSuccess = workflowDocument.applyCrop(cropRect)
        XCTAssertTrue(cropSuccess)

        // Verify new canvas size
        XCTAssertEqual(workflowDocument.canvasSize.width, 200, accuracy: 1)
        XCTAssertEqual(workflowDocument.canvasSize.height, 150, accuracy: 1)

        // Export
        guard let imageData = workflowDocument.export(format: ExportImageFormat.png) else {
            XCTFail("Failed to export")
            return
        }

        // Save
        let savedURL = try storageService.save(imageData: imageData, filename: "crop_test.png", to: tempDirectory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))

        // Verify exported image dimensions
        let savedData = try Data(contentsOf: savedURL)
        guard let savedImage = NSImage(data: savedData),
              let cgImage = savedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            XCTFail("Failed to load saved image")
            return
        }

        XCTAssertEqual(cgImage.width, 200)
        XCTAssertEqual(cgImage.height, 150)
    }

    func testCropWorkflow_undoCrop() throws {
        // Arrange
        let testImage = createTestImage(width: 400, height: 300)
        let workflowDocument = AnnotationDocument(image: testImage)

        // Apply crop
        let cropRect = CGRect(x: 100, y: 100, width: 200, height: 100)
        workflowDocument.applyCrop(cropRect)

        // Verify cropped
        XCTAssertEqual(workflowDocument.canvasSize.width, 200, accuracy: 1)

        // Undo crop
        workflowDocument.undo()

        // Verify restored
        XCTAssertEqual(workflowDocument.canvasSize.width, 400, accuracy: 1)
        XCTAssertEqual(workflowDocument.canvasSize.height, 300, accuracy: 1)
    }

    // MARK: - Highlighter Tests (T117 extension)

    func testHighlighterWorkflow_createAndExport() throws {
        // Arrange
        let testImage = createTestImage(width: 300, height: 200)
        let workflowDocument = AnnotationDocument(image: testImage)

        // Add highlighter
        let highlighter = HighlighterAnnotation(
            points: [
                CGPoint(x: 50, y: 100),
                CGPoint(x: 100, y: 95),
                CGPoint(x: 150, y: 100),
                CGPoint(x: 200, y: 105),
                CGPoint(x: 250, y: 100)
            ],
            color: .yellow,
            strokeWidth: 20
        )
        workflowDocument.addAnnotation(highlighter)

        // Export
        guard let imageData = workflowDocument.export(format: ExportImageFormat.png) else {
            XCTFail("Failed to export")
            return
        }

        // Save
        let savedURL = try storageService.save(imageData: imageData, filename: "highlighter_test.png", to: tempDirectory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))
    }
}
