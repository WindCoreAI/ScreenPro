import XCTest
@testable import ScreenPro

/// Unit tests for VideoConfig (T014)
final class VideoConfigTests: XCTestCase {

    // MARK: - Default Values

    func testDefaultValues() {
        let config = VideoConfig()

        XCTAssertEqual(config.resolution, .r1080p)
        XCTAssertEqual(config.frameRate, 30)
        XCTAssertEqual(config.quality, .high)
        XCTAssertFalse(config.includeSystemAudio)
        XCTAssertFalse(config.includeMicrophone)
        XCTAssertFalse(config.showClicks)
        XCTAssertFalse(config.showKeystrokes)
        XCTAssertTrue(config.showCursor)
    }

    // MARK: - Resolution Tests

    func testResolutionSizes() {
        XCTAssertEqual(VideoConfig.Resolution.r480p.size, CGSize(width: 854, height: 480))
        XCTAssertEqual(VideoConfig.Resolution.r720p.size, CGSize(width: 1280, height: 720))
        XCTAssertEqual(VideoConfig.Resolution.r1080p.size, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(VideoConfig.Resolution.r4k.size, CGSize(width: 3840, height: 2160))
    }

    func testResolutionDisplayNames() {
        XCTAssertEqual(VideoConfig.Resolution.r480p.displayName, "480p")
        XCTAssertEqual(VideoConfig.Resolution.r720p.displayName, "720p")
        XCTAssertEqual(VideoConfig.Resolution.r1080p.displayName, "1080p")
        XCTAssertEqual(VideoConfig.Resolution.r4k.displayName, "4K")
    }

    func testResolutionBaseBitrates() {
        XCTAssertEqual(VideoConfig.Resolution.r480p.baseBitrate, 2_500_000)
        XCTAssertEqual(VideoConfig.Resolution.r720p.baseBitrate, 5_000_000)
        XCTAssertEqual(VideoConfig.Resolution.r1080p.baseBitrate, 10_000_000)
        XCTAssertEqual(VideoConfig.Resolution.r4k.baseBitrate, 35_000_000)
    }

    // MARK: - Quality Tests

    func testQualityBitrateMultipliers() {
        XCTAssertEqual(VideoConfig.Quality.low.bitrateMultiplier, 0.5)
        XCTAssertEqual(VideoConfig.Quality.medium.bitrateMultiplier, 0.75)
        XCTAssertEqual(VideoConfig.Quality.high.bitrateMultiplier, 1.0)
        XCTAssertEqual(VideoConfig.Quality.maximum.bitrateMultiplier, 1.5)
    }

    func testQualityDisplayNames() {
        XCTAssertEqual(VideoConfig.Quality.low.displayName, "Low")
        XCTAssertEqual(VideoConfig.Quality.medium.displayName, "Medium")
        XCTAssertEqual(VideoConfig.Quality.high.displayName, "High")
        XCTAssertEqual(VideoConfig.Quality.maximum.displayName, "Maximum")
    }

    // MARK: - Target Bitrate Calculation Tests (T022)

    func testTargetBitrate1080pHigh() {
        let config = VideoConfig(resolution: .r1080p, quality: .high)
        // 10 Mbps * 1.0 = 10 Mbps
        XCTAssertEqual(config.targetBitrate, 10_000_000)
    }

    func testTargetBitrate1080pLow() {
        let config = VideoConfig(resolution: .r1080p, quality: .low)
        // 10 Mbps * 0.5 = 5 Mbps
        XCTAssertEqual(config.targetBitrate, 5_000_000)
    }

    func testTargetBitrate4kMaximum() {
        let config = VideoConfig(resolution: .r4k, quality: .maximum)
        // 35 Mbps * 1.5 = 52.5 Mbps
        XCTAssertEqual(config.targetBitrate, 52_500_000)
    }

    func testTargetBitrate720pMedium() {
        let config = VideoConfig(resolution: .r720p, quality: .medium)
        // 5 Mbps * 0.75 = 3.75 Mbps
        XCTAssertEqual(config.targetBitrate, 3_750_000)
    }

    func testTargetBitrate480pLow() {
        let config = VideoConfig(resolution: .r480p, quality: .low)
        // 2.5 Mbps * 0.5 = 1.25 Mbps
        XCTAssertEqual(config.targetBitrate, 1_250_000)
    }

    // MARK: - Frame Rate Validation Tests

    func testValidFrameRates() {
        XCTAssertEqual(VideoConfig.validFrameRates, [15, 24, 30, 60])
    }

    func testIsValidFrameRate_ValidValues() {
        for fps in [15, 24, 30, 60] {
            var config = VideoConfig()
            config.frameRate = fps
            XCTAssertTrue(config.isValidFrameRate, "Frame rate \(fps) should be valid")
        }
    }

    func testIsValidFrameRate_InvalidValues() {
        for fps in [0, 10, 20, 25, 29, 45, 90, 120] {
            var config = VideoConfig()
            config.frameRate = fps
            XCTAssertFalse(config.isValidFrameRate, "Frame rate \(fps) should be invalid")
        }
    }

    // MARK: - Codable Tests

    func testCodable() throws {
        let original = VideoConfig(
            resolution: .r720p,
            frameRate: 24,
            quality: .medium,
            includeSystemAudio: true,
            includeMicrophone: true,
            showClicks: true,
            showKeystrokes: true,
            showCursor: false
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(VideoConfig.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    // MARK: - Equatable Tests

    func testEquatable() {
        let config1 = VideoConfig(resolution: .r1080p, quality: .high)
        let config2 = VideoConfig(resolution: .r1080p, quality: .high)
        let config3 = VideoConfig(resolution: .r720p, quality: .high)

        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
    }

    // MARK: - All Cases Iteration

    func testResolutionCaseIterable() {
        let allResolutions = VideoConfig.Resolution.allCases
        XCTAssertEqual(allResolutions.count, 4)
        XCTAssertTrue(allResolutions.contains(.r480p))
        XCTAssertTrue(allResolutions.contains(.r720p))
        XCTAssertTrue(allResolutions.contains(.r1080p))
        XCTAssertTrue(allResolutions.contains(.r4k))
    }

    func testQualityCaseIterable() {
        let allQualities = VideoConfig.Quality.allCases
        XCTAssertEqual(allQualities.count, 4)
        XCTAssertTrue(allQualities.contains(.low))
        XCTAssertTrue(allQualities.contains(.medium))
        XCTAssertTrue(allQualities.contains(.high))
        XCTAssertTrue(allQualities.contains(.maximum))
    }
}
