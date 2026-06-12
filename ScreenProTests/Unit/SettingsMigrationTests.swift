import XCTest
@testable import ScreenPro

/// Tests for tolerant Settings decoding (007-cloud-polish).
/// Settings saved by older app versions are missing newer keys; decoding must
/// fill those with defaults instead of failing and resetting all preferences.
final class SettingsMigrationTests: XCTestCase {

    // MARK: - Migration

    func testDecode_settingsFromOlderVersion_keepsExistingValuesAndAppliesDefaults() throws {
        // A subset of keys as an older app version would have written them
        let legacyJSON = """
        {
            "launchAtLogin": true,
            "playCaptureSound": false,
            "fileNamingPattern": "Custom {date}",
            "videoFPS": 60
        }
        """

        let settings = try JSONDecoder().decode(Settings.self, from: Data(legacyJSON.utf8))

        // Existing values preserved
        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertFalse(settings.playCaptureSound)
        XCTAssertEqual(settings.fileNamingPattern, "Custom {date}")
        XCTAssertEqual(settings.videoFPS, 60)

        // Missing (newer) keys fall back to defaults
        XCTAssertFalse(settings.cloudUploadEnabled)
        XCTAssertEqual(settings.cloudDefaultExpiry, .never)
        XCTAssertTrue(settings.copyLinkAfterUpload)
        XCTAssertTrue(settings.captureHistoryEnabled)
        XCTAssertEqual(settings.historyRetentionDays, 30)
        XCTAssertFalse(settings.hasCompletedOnboarding)
    }

    func testDecode_emptyObject_producesDefaults() throws {
        let settings = try JSONDecoder().decode(Settings.self, from: Data("{}".utf8))

        XCTAssertEqual(settings, Settings.default)
    }

    // MARK: - Round Trip

    func testEncodeDecode_roundTripPreservesCloudAndHistorySettings() throws {
        var settings = Settings.default
        settings.cloudUploadEnabled = true
        settings.cloudServerURL = "https://uploads.example.com"
        settings.cloudAPIKey = "key-123"
        settings.cloudDefaultExpiry = .oneWeek
        settings.copyLinkAfterUpload = false
        settings.captureHistoryEnabled = false
        settings.historyRetentionDays = 90
        settings.hasCompletedOnboarding = true

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)

        XCTAssertEqual(decoded, settings)
    }

    // MARK: - Defaults

    func testDefaults_forNewMilestone7Settings() {
        let settings = Settings.default

        XCTAssertFalse(settings.cloudUploadEnabled)
        XCTAssertEqual(settings.cloudServerURL, "https://api.screenpro.cloud")
        XCTAssertEqual(settings.cloudAPIKey, "")
        XCTAssertEqual(settings.cloudDefaultExpiry, .never)
        XCTAssertTrue(settings.copyLinkAfterUpload)
        XCTAssertTrue(settings.captureHistoryEnabled)
        XCTAssertEqual(settings.historyRetentionDays, 30)
        XCTAssertFalse(settings.hasCompletedOnboarding)
    }
}
