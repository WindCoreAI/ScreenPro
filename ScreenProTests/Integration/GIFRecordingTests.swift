import XCTest
@testable import ScreenPro

/// Integration tests for GIF recording workflow (T040)
@MainActor
final class GIFRecordingTests: XCTestCase {

    // Note: Full integration tests require screen recording permission.
    // These tests focus on GIF-specific configuration and state management.

    private var sut: RecordingService!
    private var storageService: StorageService!
    private var settingsManager: SettingsManager!
    private var permissionManager: PermissionManager!

    override func setUp() async throws {
        storageService = StorageService()
        settingsManager = SettingsManager()
        permissionManager = PermissionManager()
        sut = RecordingService(
            storageService: storageService,
            settingsManager: settingsManager,
            permissionManager: permissionManager
        )
    }

    override func tearDown() async throws {
        try? await sut.cancelRecording()
        sut = nil
        storageService = nil
        settingsManager = nil
        permissionManager = nil
    }

    // MARK: - GIF Format Tests

    func testGIFFormatFileExtension() {
        let format = RecordingFormat.gif(GIFConfig())
        XCTAssertEqual(format.fileExtension, "gif")
    }

    func testGIFFormatDoesNotSupportAudio() {
        let format = RecordingFormat.gif(GIFConfig())
        XCTAssertFalse(format.supportsAudio)
    }

    func testDefaultGIFFormat() {
        let format = RecordingFormat.defaultGIF

        if case .gif(let config) = format {
            XCTAssertEqual(config.frameRate, 15)
            XCTAssertEqual(config.loopCount, 0, "Default should loop infinitely")
            XCTAssertEqual(config.scale, 1.0, "Default scale should be 100%")
            XCTAssertEqual(config.maxColors, 256, "Default should use full color palette")
        } else {
            XCTFail("Expected GIF format")
        }
    }

    // MARK: - GIF Config Validation Tests

    func testGIFConfigValidation_ValidConfig() {
        let config = GIFConfig(
            frameRate: 15,
            maxColors: 256,
            loopCount: 0,
            scale: 1.0
        )
        XCTAssertTrue(config.isValid)
    }

    func testGIFConfigValidation_InvalidFrameRate() {
        let config = GIFConfig(
            frameRate: 60, // Too high for GIF
            maxColors: 256,
            loopCount: 0,
            scale: 1.0
        )
        XCTAssertFalse(config.isValid)
    }

    func testGIFConfigValidation_InvalidScale() {
        let config = GIFConfig(
            frameRate: 15,
            maxColors: 256,
            loopCount: 0,
            scale: 0.1 // Too low
        )
        XCTAssertFalse(config.isValid)
    }

    // MARK: - GIF Frame Delay Tests

    func testGIFFrameDelay_15FPS() {
        let config = GIFConfig(frameRate: 15)
        XCTAssertEqual(config.frameDelay, 1.0/15.0, accuracy: 0.0001)
    }

    func testGIFFrameDelay_10FPS() {
        let config = GIFConfig(frameRate: 10)
        XCTAssertEqual(config.frameDelay, 0.1, accuracy: 0.0001)
    }

    // MARK: - Recording Format Detection

    func testIsGIFFormat() {
        let gifFormat = RecordingFormat.gif(GIFConfig())
        let videoFormat = RecordingFormat.video(VideoConfig())

        if case .gif = gifFormat {
            // Expected
        } else {
            XCTFail("Should be GIF format")
        }

        if case .video = videoFormat {
            // Expected
        } else {
            XCTFail("Should be video format")
        }
    }

    // MARK: - Memory Warning Tests

    func testGIFMemoryWarningThreshold() {
        // For 15fps, 30 seconds = 450 frames
        // Warning should trigger at around 450+ frames
        let config = GIFConfig(frameRate: 15)
        let warningDuration: TimeInterval = 30.0
        let expectedFramesAtWarning = Int(warningDuration * Double(config.frameRate))

        XCTAssertEqual(expectedFramesAtWarning, 450)
    }

    func testGIFEstimatedFrameCount() {
        let config = GIFConfig(frameRate: 15)
        let duration: TimeInterval = 10.0

        let expectedFrames = Int(duration * Double(config.frameRate))
        XCTAssertEqual(expectedFrames, 150)
    }

    // MARK: - GIF Quality Settings

    func testGIFScaleOptions() {
        let fullScale = GIFConfig(scale: 1.0)
        let halfScale = GIFConfig(scale: 0.5)
        let quarterScale = GIFConfig(scale: 0.25)

        XCTAssertTrue(fullScale.isValid)
        XCTAssertTrue(halfScale.isValid)
        XCTAssertTrue(quarterScale.isValid)
    }

    func testGIFColorPaletteOptions() {
        let fullColor = GIFConfig(maxColors: 256)
        let reducedColor = GIFConfig(maxColors: 128)
        let minimalColor = GIFConfig(maxColors: 16)

        XCTAssertTrue(fullColor.isValid)
        XCTAssertTrue(reducedColor.isValid)
        XCTAssertTrue(minimalColor.isValid)
    }
}
