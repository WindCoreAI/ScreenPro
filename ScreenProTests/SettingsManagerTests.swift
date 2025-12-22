import XCTest
@testable import ScreenPro

// MARK: - Settings Manager Tests (T026-T028 - placeholder for Phase 5)

@MainActor
final class SettingsManagerTests: XCTestCase {
    var settingsManager: SettingsManager!

    override func setUp() async throws {
        settingsManager = SettingsManager()
        // Clear any existing settings
        UserDefaults.standard.removeObject(forKey: "ScreenProSettings")
    }

    override func tearDown() async throws {
        // Clean up
        UserDefaults.standard.removeObject(forKey: "ScreenProSettings")
        settingsManager = nil
    }

    // MARK: - Default Settings Test (T026)

    func testDefaultSettings() {
        let settings = Settings.default

        // General defaults
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertTrue(settings.showMenuBarIcon)
        XCTAssertTrue(settings.playCaptureSound)

        // Capture defaults
        XCTAssertEqual(settings.defaultImageFormat, .png)
        XCTAssertFalse(settings.includeCursor)
        XCTAssertTrue(settings.showCrosshair)

        // Recording defaults
        XCTAssertEqual(settings.defaultVideoFormat, .mp4)
        XCTAssertEqual(settings.videoQuality, .high)
        XCTAssertEqual(settings.videoFPS, 30)

        // Quick Access defaults
        XCTAssertTrue(settings.showQuickAccess)
        XCTAssertEqual(settings.quickAccessPosition, .bottomLeft)
    }

    // MARK: - Persistence Test (T027)

    func testSettingsPersistence() {
        // Modify settings
        settingsManager.settings.launchAtLogin = true
        settingsManager.settings.defaultImageFormat = .jpeg
        settingsManager.settings.videoFPS = 60

        // Save settings
        settingsManager.save()

        // Create new manager to load saved settings
        let newManager = SettingsManager()

        // Verify loaded values match saved values
        XCTAssertTrue(newManager.settings.launchAtLogin)
        XCTAssertEqual(newManager.settings.defaultImageFormat, .jpeg)
        XCTAssertEqual(newManager.settings.videoFPS, 60)
    }

    // MARK: - Filename Generation Test (T028)

    func testFilenameGeneration() {
        // Test screenshot filename
        let screenshotName = settingsManager.generateFilename(for: .screenshot)
        XCTAssertTrue(screenshotName.contains("Screenshot"))
        XCTAssertTrue(screenshotName.hasSuffix(".png"))

        // Test video filename
        settingsManager.settings.fileNamingPattern = "Recording {date} at {time}"
        let videoName = settingsManager.generateFilename(for: .video)
        XCTAssertTrue(videoName.contains("Recording"))
        XCTAssertTrue(videoName.hasSuffix(".mp4"))

        // Test GIF filename
        let gifName = settingsManager.generateFilename(for: .gif)
        XCTAssertTrue(gifName.hasSuffix(".gif"))
    }

    func testResetSettings() {
        // Modify settings
        settingsManager.settings.launchAtLogin = true
        settingsManager.settings.defaultImageFormat = .jpeg

        // Reset
        settingsManager.reset()

        // Verify defaults restored
        XCTAssertFalse(settingsManager.settings.launchAtLogin)
        XCTAssertEqual(settingsManager.settings.defaultImageFormat, .png)
    }
}
