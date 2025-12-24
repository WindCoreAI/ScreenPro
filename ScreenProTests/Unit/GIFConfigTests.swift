import XCTest
@testable import ScreenPro

/// Unit tests for GIFConfig (T038)
final class GIFConfigTests: XCTestCase {

    // MARK: - Default Values

    func testDefaultValues() {
        let config = GIFConfig()

        XCTAssertEqual(config.frameRate, 15)
        XCTAssertEqual(config.maxColors, 256)
        XCTAssertEqual(config.loopCount, 0)
        XCTAssertEqual(config.scale, 1.0)
    }

    // MARK: - Frame Rate Validation

    func testValidFrameRateRange() {
        XCTAssertEqual(GIFConfig.validFrameRateRange, 5...30)
    }

    func testIsValid_ValidFrameRates() {
        for fps in [5, 10, 15, 20, 25, 30] {
            var config = GIFConfig()
            config.frameRate = fps
            XCTAssertTrue(config.isValid, "Frame rate \(fps) should be valid")
        }
    }

    func testIsValid_InvalidFrameRates() {
        for fps in [0, 1, 4, 31, 60, 100] {
            var config = GIFConfig()
            config.frameRate = fps
            XCTAssertFalse(config.isValid, "Frame rate \(fps) should be invalid")
        }
    }

    // MARK: - Color Validation

    func testValidColorRange() {
        XCTAssertEqual(GIFConfig.validColorRange, 2...256)
    }

    func testIsValid_ValidColorCounts() {
        for colors in [2, 16, 64, 128, 256] {
            var config = GIFConfig()
            config.maxColors = colors
            XCTAssertTrue(config.isValid, "Color count \(colors) should be valid")
        }
    }

    func testIsValid_InvalidColorCounts() {
        for colors in [0, 1, 257, 512] {
            var config = GIFConfig()
            config.maxColors = colors
            XCTAssertFalse(config.isValid, "Color count \(colors) should be invalid")
        }
    }

    // MARK: - Loop Count Validation

    func testIsValid_ValidLoopCounts() {
        for loops in [0, 1, 5, 100] {
            var config = GIFConfig()
            config.loopCount = loops
            XCTAssertTrue(config.isValid, "Loop count \(loops) should be valid")
        }
    }

    func testIsValid_InvalidLoopCount() {
        var config = GIFConfig()
        config.loopCount = -1
        XCTAssertFalse(config.isValid, "Negative loop count should be invalid")
    }

    // MARK: - Scale Validation

    func testValidScaleRange() {
        XCTAssertEqual(GIFConfig.validScaleRange, 0.25...1.0)
    }

    func testIsValid_ValidScales() {
        for scale in [0.25, 0.5, 0.75, 1.0] {
            var config = GIFConfig()
            config.scale = scale
            XCTAssertTrue(config.isValid, "Scale \(scale) should be valid")
        }
    }

    func testIsValid_InvalidScales() {
        for scale in [0.0, 0.1, 0.24, 1.01, 2.0] {
            var config = GIFConfig()
            config.scale = scale
            XCTAssertFalse(config.isValid, "Scale \(scale) should be invalid")
        }
    }

    // MARK: - Frame Delay Calculation

    func testFrameDelay_15fps() {
        let config = GIFConfig(frameRate: 15)
        XCTAssertEqual(config.frameDelay, 1.0 / 15.0, accuracy: 0.0001)
    }

    func testFrameDelay_10fps() {
        let config = GIFConfig(frameRate: 10)
        XCTAssertEqual(config.frameDelay, 0.1, accuracy: 0.0001)
    }

    func testFrameDelay_30fps() {
        let config = GIFConfig(frameRate: 30)
        XCTAssertEqual(config.frameDelay, 1.0 / 30.0, accuracy: 0.0001)
    }

    // MARK: - Codable Tests

    func testCodable() throws {
        let original = GIFConfig(
            frameRate: 20,
            maxColors: 128,
            loopCount: 3,
            scale: 0.5
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(GIFConfig.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    // MARK: - Equatable Tests

    func testEquatable() {
        let config1 = GIFConfig(frameRate: 15, maxColors: 256, loopCount: 0, scale: 1.0)
        let config2 = GIFConfig(frameRate: 15, maxColors: 256, loopCount: 0, scale: 1.0)
        let config3 = GIFConfig(frameRate: 10, maxColors: 256, loopCount: 0, scale: 1.0)

        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
    }

    // MARK: - Sendable Conformance

    func testSendable() {
        let config = GIFConfig()

        // This compiles because GIFConfig is Sendable
        Task {
            let _ = config
        }
    }
}
