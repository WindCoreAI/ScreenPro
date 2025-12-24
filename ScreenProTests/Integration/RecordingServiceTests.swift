import XCTest
@testable import ScreenPro

/// Integration tests for RecordingService (T015)
@MainActor
final class RecordingServiceTests: XCTestCase {

    // Note: Full integration tests require screen recording permission.
    // These tests focus on state management and error handling that can be tested without permissions.

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
        // Cancel any ongoing recording
        try? await sut.cancelRecording()
        sut = nil
        storageService = nil
        settingsManager = nil
        permissionManager = nil
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(sut.duration, 0)
        XCTAssertNil(sut.recordingRegion)
    }

    // MARK: - Error Handling Tests

    func testStopRecordingThrowsWhenNotRecording() async {
        // Given: Service is idle
        XCTAssertEqual(sut.state, .idle)

        // When/Then: Stopping should throw
        do {
            _ = try await sut.stopRecording()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is RecordingError)
            if let recordingError = error as? RecordingError {
                XCTAssertEqual(recordingError, .notRecording)
            }
        }
    }

    func testPauseRecordingThrowsWhenNotRecording() {
        // Given: Service is idle
        XCTAssertEqual(sut.state, .idle)

        // When/Then: Pausing should throw
        XCTAssertThrowsError(try sut.pauseRecording()) { error in
            XCTAssertEqual(error as? RecordingError, .notRecording)
        }
    }

    func testResumeRecordingThrowsWhenNotPaused() {
        // Given: Service is idle (not paused)
        XCTAssertEqual(sut.state, .idle)

        // When/Then: Resuming should throw
        XCTAssertThrowsError(try sut.resumeRecording()) { error in
            XCTAssertEqual(error as? RecordingError, .notRecording)
        }
    }

    func testCancelRecordingFromIdleDoesNotThrow() async {
        // Given: Service is idle
        XCTAssertEqual(sut.state, .idle)

        // When/Then: Cancelling from idle should not throw
        do {
            try await sut.cancelRecording()
            XCTAssertEqual(sut.state, .idle)
        } catch {
            XCTFail("Cancelling from idle should not throw: \(error)")
        }
    }

    // MARK: - Video Config Tests

    func testVideoConfigFromSettings() {
        // Given: Default settings
        let settings = settingsManager.settings

        // When: Creating a video config based on settings
        let config = VideoConfig(
            resolution: .r1080p,
            frameRate: settings.videoFPS,
            quality: .high,
            includeSystemAudio: settings.recordSystemAudio,
            includeMicrophone: settings.recordMicrophone,
            showClicks: settings.showClicks,
            showKeystrokes: settings.showKeystrokes,
            showCursor: settings.includeCursor
        )

        // Then: Config should match settings
        XCTAssertEqual(config.frameRate, 30)
        XCTAssertFalse(config.includeSystemAudio)
        XCTAssertFalse(config.includeMicrophone)
        XCTAssertFalse(config.showClicks)
        XCTAssertFalse(config.showKeystrokes)
    }

    // MARK: - Recording Format Tests

    func testRecordingFormatVideo() {
        let format = RecordingFormat.video(VideoConfig())

        XCTAssertEqual(format.fileExtension, "mp4")
        XCTAssertTrue(format.supportsAudio)
    }

    func testRecordingFormatGIF() {
        let format = RecordingFormat.gif(GIFConfig())

        XCTAssertEqual(format.fileExtension, "gif")
        XCTAssertFalse(format.supportsAudio)
    }

    func testDefaultVideoFormat() {
        let format = RecordingFormat.defaultVideo

        if case .video(let config) = format {
            XCTAssertEqual(config.resolution, .r1080p)
            XCTAssertEqual(config.frameRate, 30)
        } else {
            XCTFail("Expected video format")
        }
    }

    func testDefaultGIFFormat() {
        let format = RecordingFormat.defaultGIF

        if case .gif(let config) = format {
            XCTAssertEqual(config.frameRate, 15)
            XCTAssertEqual(config.loopCount, 0)
        } else {
            XCTFail("Expected GIF format")
        }
    }
}

// MARK: - RecordingError Equatable

extension RecordingError: Equatable {
    public static func == (lhs: RecordingError, rhs: RecordingError) -> Bool {
        switch (lhs, rhs) {
        case (.notRecording, .notRecording),
             (.alreadyRecording, .alreadyRecording),
             (.screenCaptureNotAuthorized, .screenCaptureNotAuthorized),
             (.microphoneNotAuthorized, .microphoneNotAuthorized),
             (.insufficientDiskSpace, .insufficientDiskSpace),
             (.noFramesToEncode, .noFramesToEncode),
             (.streamConfigurationFailed, .streamConfigurationFailed):
            return true
        case (.cannotCreateFile(let lhsURL), .cannotCreateFile(let rhsURL)):
            return lhsURL == rhsURL
        case (.encodingFailed(let lhs), .encodingFailed(let rhs)):
            return lhs == rhs
        case (.assetWriterSetupFailed(let lhs), .assetWriterSetupFailed(let rhs)):
            return lhs == rhs
        case (.unknown(let lhs), .unknown(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}
