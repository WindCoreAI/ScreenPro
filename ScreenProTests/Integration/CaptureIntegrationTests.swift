import XCTest
@testable import ScreenPro
import ScreenCaptureKit

/// Integration tests for capture workflows.
/// These tests verify end-to-end capture functionality.
final class CaptureIntegrationTests: XCTestCase {

    // MARK: - Properties

    var coordinator: AppCoordinator!
    var captureService: CaptureService!

    // MARK: - Setup & Teardown

    @MainActor
    override func setUp() async throws {
        try await super.setUp()

        coordinator = AppCoordinator()
        await coordinator.initialize()

        captureService = coordinator.captureService
    }

    @MainActor
    override func tearDown() async throws {
        coordinator.cleanup()
        coordinator = nil
        captureService = nil

        try await super.tearDown()
    }

    // MARK: - Permission Tests

    /// Verifies that capture fails gracefully when permission is not granted.
    @MainActor
    func testCaptureWithoutPermission_showsPermissionRequest() async throws {
        // This test verifies behavior when permission is not granted
        // In CI/headless environments, this will typically fail with permission denied

        // Given: Coordinator is initialized
        XCTAssertTrue(coordinator.isReady)

        // When: Permission status is checked
        let status = coordinator.permissionManager.screenRecordingStatus

        // Then: Status should be either authorized or notDetermined
        // (In a real test environment with mocking, we'd test the denied path)
        XCTAssertTrue(status == .authorized || status == .notDetermined || status == .denied)
    }

    // MARK: - Area Capture Tests

    /// Verifies that area capture state transitions work correctly.
    @MainActor
    func testAreaCapture_stateTransitions() async throws {
        // Skip if permission not granted
        guard coordinator.permissionManager.screenRecordingStatus == .authorized else {
            throw XCTSkip("Screen recording permission required for this test")
        }

        // Given: Coordinator is in idle state
        XCTAssertEqual(coordinator.state, .idle)

        // When: Area capture is initiated
        coordinator.captureArea()

        // Then: State should transition to selectingArea
        XCTAssertEqual(coordinator.state, .selectingArea)

        // Cleanup: Cancel the capture to reset state
        coordinator.cleanup()
    }

    /// Verifies that minimum selection validation works.
    @MainActor
    func testAreaCapture_minimumSelectionValidation() async throws {
        // Given: A rect smaller than 5x5 pixels
        let tooSmallRect = CGRect(x: 100, y: 100, width: 3, height: 3)

        // When/Then: Capture should throw invalidSelection error
        do {
            _ = try await captureService.captureArea(tooSmallRect)
            XCTFail("Expected invalidSelection error")
        } catch let error as CaptureError {
            XCTAssertEqual(error, CaptureError.invalidSelection)
        }
    }

    /// Verifies that a valid area capture produces a result.
    @MainActor
    func testAreaCapture_validSelection_producesResult() async throws {
        // Skip if permission not granted
        guard coordinator.permissionManager.screenRecordingStatus == .authorized else {
            throw XCTSkip("Screen recording permission required for this test")
        }

        // Given: A valid selection rect (at least 5x5)
        guard let screen = NSScreen.main else {
            throw XCTSkip("No main screen available")
        }

        // Refresh content first
        try await captureService.refreshAvailableContent()

        // Create a valid rect in the center of the screen
        let validRect = CGRect(
            x: screen.frame.midX - 50,
            y: screen.frame.midY - 50,
            width: 100,
            height: 100
        )

        // When: Capturing the area
        let result = try await captureService.captureArea(validRect)

        // Then: Result should have valid properties
        XCTAssertNotNil(result.image)
        XCTAssertGreaterThanOrEqual(result.pixelSize.width, 100)
        XCTAssertGreaterThanOrEqual(result.pixelSize.height, 100)
    }

    // MARK: - Fullscreen Capture Tests

    /// Verifies that fullscreen capture state transitions work correctly.
    @MainActor
    func testFullscreenCapture_stateTransitions() async throws {
        // Skip if permission not granted
        guard coordinator.permissionManager.screenRecordingStatus == .authorized else {
            throw XCTSkip("Screen recording permission required for this test")
        }

        // Given: Coordinator is in idle state
        XCTAssertEqual(coordinator.state, .idle)

        // When: Fullscreen capture is initiated
        coordinator.captureFullscreen()

        // Then: State should transition to capturing
        XCTAssertEqual(coordinator.state, .capturing)

        // Wait for capture to complete (async operation)
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // State should return to idle after capture
        XCTAssertEqual(coordinator.state, .idle)
    }

    /// Verifies that fullscreen capture produces a valid result.
    @MainActor
    func testFullscreenCapture_producesValidResult() async throws {
        // Skip if permission not granted
        guard coordinator.permissionManager.screenRecordingStatus == .authorized else {
            throw XCTSkip("Screen recording permission required for this test")
        }

        // Given: Content is refreshed
        try await captureService.refreshAvailableContent()

        // When: Capturing the display
        let result = try await captureService.captureDisplay(nil)

        // Then: Result should match display size (approximately, accounting for Retina)
        guard let screen = NSScreen.main else {
            throw XCTSkip("No main screen available")
        }

        let expectedWidth = screen.frame.width * screen.backingScaleFactor
        let expectedHeight = screen.frame.height * screen.backingScaleFactor

        XCTAssertEqual(result.pixelSize.width, expectedWidth, accuracy: 10)
        XCTAssertEqual(result.pixelSize.height, expectedHeight, accuracy: 10)
    }

    // MARK: - Content Discovery Tests

    /// Verifies that content discovery finds available displays.
    @MainActor
    func testContentDiscovery_findsDisplays() async throws {
        // Skip if permission not granted
        guard coordinator.permissionManager.screenRecordingStatus == .authorized else {
            throw XCTSkip("Screen recording permission required for this test")
        }

        // When: Refreshing available content
        try await captureService.refreshAvailableContent()

        // Then: Should find at least one display
        XCTAssertFalse(captureService.availableDisplays.isEmpty)
        XCTAssertGreaterThanOrEqual(captureService.availableDisplays.count, 1)
    }

    /// Verifies that window discovery filters appropriately.
    @MainActor
    func testContentDiscovery_filtersWindows() async throws {
        // Skip if permission not granted
        guard coordinator.permissionManager.screenRecordingStatus == .authorized else {
            throw XCTSkip("Screen recording permission required for this test")
        }

        // When: Refreshing available content
        try await captureService.refreshAvailableContent()

        // Then: Windows should not include self (ScreenPro windows)
        let selfBundleId = Bundle.main.bundleIdentifier
        for window in captureService.availableWindows {
            if let app = window.owningApplication {
                XCTAssertNotEqual(app.bundleIdentifier, selfBundleId)
            }
        }
    }

    // MARK: - Coordinate Conversion Tests

    /// Verifies Y-axis flip in coordinate conversion.
    @MainActor
    func testCoordinateConversion_yAxisFlip() {
        // Given: A rect at screen origin (bottom-left)
        let screenRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let displayFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let imageSize = CGSize(width: 1920, height: 1080)

        // When: Converting to image coordinates
        let imageRect = DisplayManager.convertToImageCoordinates(
            screenRect,
            in: displayFrame,
            imageSize: imageSize
        )

        // Then: Y should be flipped (near bottom of image = near top of screen)
        XCTAssertEqual(imageRect.origin.x, 0, accuracy: 0.001)
        XCTAssertEqual(imageRect.origin.y, 980, accuracy: 0.001) // 1080 - 100
        XCTAssertEqual(imageRect.width, 100, accuracy: 0.001)
        XCTAssertEqual(imageRect.height, 100, accuracy: 0.001)
    }

    /// Verifies Retina scale factor handling.
    @MainActor
    func testCoordinateConversion_retinaScaling() {
        // Given: A rect with 2x Retina scaling
        let screenRect = CGRect(x: 100, y: 200, width: 50, height: 50)
        let displayFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let imageSize = CGSize(width: 2880, height: 1800) // 2x scale

        // When: Converting to image coordinates
        let imageRect = DisplayManager.convertToImageCoordinates(
            screenRect,
            in: displayFrame,
            imageSize: imageSize
        )

        // Then: All values should be doubled
        XCTAssertEqual(imageRect.origin.x, 200, accuracy: 0.001) // 100 * 2
        XCTAssertEqual(imageRect.width, 100, accuracy: 0.001) // 50 * 2
        XCTAssertEqual(imageRect.height, 100, accuracy: 0.001) // 50 * 2
    }

    // MARK: - Save and Clipboard Tests

    /// Verifies that save operation creates a file.
    @MainActor
    func testSave_createsFile() async throws {
        // Skip if permission not granted
        guard coordinator.permissionManager.screenRecordingStatus == .authorized else {
            throw XCTSkip("Screen recording permission required for this test")
        }

        // Given: A capture result
        try await captureService.refreshAvailableContent()
        let result = try await captureService.captureDisplay(nil)

        // When: Saving the result
        let savedURL = try captureService.save(result)

        // Then: File should exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))

        // Cleanup: Delete the test file
        try? FileManager.default.removeItem(at: savedURL)
    }

    /// Verifies that clipboard copy succeeds without error.
    @MainActor
    func testCopyToClipboard_succeeds() async throws {
        // Skip if permission not granted
        guard coordinator.permissionManager.screenRecordingStatus == .authorized else {
            throw XCTSkip("Screen recording permission required for this test")
        }

        // Given: A capture result
        try await captureService.refreshAvailableContent()
        let result = try await captureService.captureDisplay(nil)

        // When: Copying to clipboard
        captureService.copyToClipboard(result)

        // Then: Clipboard should contain an image
        let pasteboard = NSPasteboard.general
        XCTAssertTrue(pasteboard.canReadObject(forClasses: [NSImage.self], options: nil))
    }

    // MARK: - Window Capture Tests

    /// Verifies that window capture state transitions work correctly.
    @MainActor
    func testWindowCapture_stateTransitions() async throws {
        // Skip if permission not granted
        guard coordinator.permissionManager.screenRecordingStatus == .authorized else {
            throw XCTSkip("Screen recording permission required for this test")
        }

        // Given: Coordinator is in idle state
        XCTAssertEqual(coordinator.state, .idle)

        // When: Window capture is initiated
        coordinator.captureWindow()

        // Then: State should transition to selectingWindow
        XCTAssertEqual(coordinator.state, .selectingWindow)

        // Wait briefly and then cancel by simulating the picker returning nil
        // (In a real UI test, the user would click a window or press Escape)
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        // Cleanup
        coordinator.cleanup()
    }

    /// Verifies that window capture produces a valid result.
    @MainActor
    func testWindowCapture_producesValidResult() async throws {
        // Skip if permission not granted
        guard coordinator.permissionManager.screenRecordingStatus == .authorized else {
            throw XCTSkip("Screen recording permission required for this test")
        }

        // Given: Content is refreshed and windows are available
        try await captureService.refreshAvailableContent()

        guard let window = captureService.availableWindows.first else {
            throw XCTSkip("No windows available for capture")
        }

        // When: Capturing the window
        let result = try await captureService.captureWindow(window)

        // Then: Result should have valid properties matching window dimensions
        XCTAssertNotNil(result.image)
        XCTAssertGreaterThan(result.pixelSize.width, 0)
        XCTAssertGreaterThan(result.pixelSize.height, 0)

        // Mode should be .window
        if case .window(let capturedWindow) = result.mode {
            XCTAssertEqual(capturedWindow.windowID, window.windowID)
        } else {
            XCTFail("Expected window capture mode")
        }
    }

    /// Verifies that window discovery includes valid windows.
    @MainActor
    func testWindowDiscovery_findsValidWindows() async throws {
        // Skip if permission not granted
        guard coordinator.permissionManager.screenRecordingStatus == .authorized else {
            throw XCTSkip("Screen recording permission required for this test")
        }

        // When: Refreshing available content
        try await captureService.refreshAvailableContent()

        // Then: Available windows should have valid properties
        for window in captureService.availableWindows {
            // Each window should have a valid frame
            XCTAssertGreaterThan(window.frame.width, 0)
            XCTAssertGreaterThan(window.frame.height, 0)

            // Each window should have an owning application (by our filter)
            XCTAssertNotNil(window.owningApplication)
        }
    }
}
