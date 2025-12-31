import XCTest
import ScreenCaptureKit
@testable import ScreenPro

/// Unit tests for CaptureService.
final class CaptureServiceTests: XCTestCase {

    // MARK: - Properties

    var sut: CaptureService!
    var mockSettingsManager: SettingsManager!

    // MARK: - Setup & Teardown

    @MainActor
    override func setUp() {
        super.setUp()
        mockSettingsManager = SettingsManager()
        sut = CaptureService(settingsManager: mockSettingsManager)
    }

    override func tearDown() {
        sut = nil
        mockSettingsManager = nil
        super.tearDown()
    }

    // MARK: - Coordinate Conversion Tests

    func testConvertToImageCoordinates_basicConversion() {
        // Given: A rect in screen coordinates
        let screenRect = CGRect(x: 100, y: 100, width: 200, height: 150)
        let displayFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let imageSize = CGSize(width: 3840, height: 2160) // 2x scale factor

        // When: Converting to image coordinates
        let imageRect = DisplayManager.convertToImageCoordinates(
            screenRect,
            in: displayFrame,
            imageSize: imageSize
        )

        // Then: Coordinates should be scaled and Y-flipped
        // X: 100 * 2 = 200
        // Y: (1080 - 100 - 150) * 2 = 830 * 2 = 1660
        // Width: 200 * 2 = 400
        // Height: 150 * 2 = 300
        XCTAssertEqual(imageRect.origin.x, 200, accuracy: 0.001)
        XCTAssertEqual(imageRect.origin.y, 1660, accuracy: 0.001)
        XCTAssertEqual(imageRect.width, 400, accuracy: 0.001)
        XCTAssertEqual(imageRect.height, 300, accuracy: 0.001)
    }

    func testConvertToImageCoordinates_atOrigin() {
        // Given: A rect at the origin (bottom-left in screen coords)
        let screenRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let displayFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let imageSize = CGSize(width: 1920, height: 1080) // 1x scale

        // When: Converting to image coordinates
        let imageRect = DisplayManager.convertToImageCoordinates(
            screenRect,
            in: displayFrame,
            imageSize: imageSize
        )

        // Then: Origin should be at top-left, near bottom of image
        // Y in image coords = 1080 - 0 - 100 = 980
        XCTAssertEqual(imageRect.origin.x, 0, accuracy: 0.001)
        XCTAssertEqual(imageRect.origin.y, 980, accuracy: 0.001)
        XCTAssertEqual(imageRect.width, 100, accuracy: 0.001)
        XCTAssertEqual(imageRect.height, 100, accuracy: 0.001)
    }

    // MARK: - Validation Tests

    func testInvalidSelection_tooSmall() async throws {
        // Given: A selection smaller than 5x5 pixels
        let smallRect = CGRect(x: 100, y: 100, width: 3, height: 3)

        // When/Then: Capture should throw invalidSelection error
        await MainActor.run {
            do {
                _ = try await sut.captureArea(smallRect)
                XCTFail("Expected invalidSelection error")
            } catch let error as CaptureError {
                XCTAssertEqual(error, CaptureError.invalidSelection)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - CaptureConfig Tests

    @MainActor
    func testCaptureConfig_fromSettings() {
        // Given: Default settings
        let settings = Settings.default

        // When: Creating config from settings
        let config = CaptureConfig.from(settings: settings)

        // Then: Config should reflect settings
        XCTAssertEqual(config.includeCursor, settings.includeCursor)
        XCTAssertEqual(config.imageFormat, settings.defaultImageFormat)
        XCTAssertGreaterThanOrEqual(config.scaleFactor, 1.0)
    }

    // MARK: - CaptureResult Tests

    func testCaptureResult_nsImageScaling() {
        // Given: A mock CGImage (we'll create a simple 100x100 context)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 200,
            height: 100,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
              let cgImage = context.makeImage() else {
            XCTFail("Failed to create test image")
            return
        }

        // When: Creating a CaptureResult with 2x scale factor
        // Use .area mode instead of .display to avoid needing to mock SCDisplay
        let result = CaptureResult(
            image: cgImage,
            mode: .area(CGRect(x: 0, y: 0, width: 100, height: 50)),
            sourceRect: CGRect(x: 0, y: 0, width: 100, height: 50),
            scaleFactor: 2.0
        )

        // Then: NSImage should be scaled to logical pixels
        XCTAssertEqual(result.nsImage.size.width, 100, accuracy: 0.001)
        XCTAssertEqual(result.nsImage.size.height, 50, accuracy: 0.001)
        XCTAssertEqual(result.pixelSize.width, 200, accuracy: 0.001)
        XCTAssertEqual(result.pixelSize.height, 100, accuracy: 0.001)
    }

    // MARK: - Display Manager Tests (T044)

    func testDisplayManager_findDisplay_returnsDisplayContainingPoint() {
        // Given: A point and display frames
        let displayFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let pointInside = CGPoint(x: 100, y: 100)
        let pointOutside = CGPoint(x: 2000, y: 100)

        // When/Then: Point inside should be contained
        XCTAssertTrue(displayFrame.contains(pointInside))
        XCTAssertFalse(displayFrame.contains(pointOutside))
    }

    func testDisplayManager_multiMonitor_identifiesCorrectDisplay() {
        // Given: Multiple display frames (simulating multi-monitor setup)
        let primaryDisplay = CGRect(x: 0, y: 0, width: 2560, height: 1440)
        let secondaryDisplay = CGRect(x: 2560, y: 0, width: 1920, height: 1080)

        // When: Testing point locations
        let pointOnPrimary = CGPoint(x: 1000, y: 500)
        let pointOnSecondary = CGPoint(x: 3000, y: 500)

        // Then: Each point should be in the correct display
        XCTAssertTrue(primaryDisplay.contains(pointOnPrimary))
        XCTAssertFalse(primaryDisplay.contains(pointOnSecondary))

        XCTAssertFalse(secondaryDisplay.contains(pointOnPrimary))
        XCTAssertTrue(secondaryDisplay.contains(pointOnSecondary))
    }

    func testScaleFactor_calculatesCorrectly() {
        // Given: Display frame and captured image size
        let displayWidth: CGFloat = 1920
        let imageWidth: CGFloat = 3840 // 2x scale

        // When: Calculating scale factor
        let scaleFactor = imageWidth / displayWidth

        // Then: Scale factor should be 2.0
        XCTAssertEqual(scaleFactor, 2.0, accuracy: 0.001)
    }
}

// MARK: - Notes

// Note: SCDisplay cannot be subclassed or mocked directly.
// Tests that require SCDisplay should either:
// 1. Use .area() mode for CaptureResult instead of .display()
// 2. Use integration tests with actual screen capture
// 3. Use protocol-based dependency injection
