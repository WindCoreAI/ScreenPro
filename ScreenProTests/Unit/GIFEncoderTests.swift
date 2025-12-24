import XCTest
import CoreGraphics
@testable import ScreenPro

/// Unit tests for GIFEncoder (T039)
final class GIFEncoderTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func createTestFrame(width: Int = 100, height: Int = 100, color: CGColor) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()
    }

    private func createTestFrames(count: Int) -> [CGImage] {
        let colors: [CGColor] = [
            CGColor(red: 1, green: 0, blue: 0, alpha: 1),
            CGColor(red: 0, green: 1, blue: 0, alpha: 1),
            CGColor(red: 0, green: 0, blue: 1, alpha: 1),
            CGColor(red: 1, green: 1, blue: 0, alpha: 1)
        ]

        return (0..<count).compactMap { index in
            createTestFrame(color: colors[index % colors.count])
        }
    }

    // MARK: - Encode Tests

    func testEncodeCreatesGIFFile() throws {
        let frames = createTestFrames(count: 3)
        XCTAssertEqual(frames.count, 3)

        let outputURL = tempDirectory.appendingPathComponent("test.gif")

        try GIFEncoder.encode(
            frames: frames,
            frameDelay: 0.1,
            loopCount: 0,
            to: outputURL
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testEncodeWithZeroFramesThrows() {
        let outputURL = tempDirectory.appendingPathComponent("empty.gif")

        XCTAssertThrowsError(try GIFEncoder.encode(
            frames: [],
            frameDelay: 0.1,
            loopCount: 0,
            to: outputURL
        )) { error in
            XCTAssertEqual(error as? GIFEncoderError, .noFrames)
        }
    }

    func testEncodeWithSingleFrame() throws {
        let frames = createTestFrames(count: 1)
        let outputURL = tempDirectory.appendingPathComponent("single.gif")

        try GIFEncoder.encode(
            frames: frames,
            frameDelay: 0.1,
            loopCount: 0,
            to: outputURL
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Verify file is not empty
        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(fileSize, 0)
    }

    func testEncodeWithCustomLoopCount() throws {
        let frames = createTestFrames(count: 2)
        let outputURL = tempDirectory.appendingPathComponent("loop.gif")

        try GIFEncoder.encode(
            frames: frames,
            frameDelay: 0.1,
            loopCount: 3,
            to: outputURL
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testEncodeWithDifferentFrameDelays() throws {
        let frames = createTestFrames(count: 3)

        // Test various frame delays
        for delay in [0.033, 0.067, 0.1, 0.2] {
            let outputURL = tempDirectory.appendingPathComponent("delay_\(delay).gif")

            try GIFEncoder.encode(
                frames: frames,
                frameDelay: delay,
                loopCount: 0,
                to: outputURL
            )

            XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        }
    }

    // MARK: - reduceFrames Tests

    func testReduceFrames_SameFPS() {
        let frames = createTestFrames(count: 30)

        let reduced = GIFEncoder.reduceFrames(frames, targetFPS: 30, sourceFPS: 30)

        XCTAssertEqual(reduced.count, 30, "Same FPS should keep all frames")
    }

    func testReduceFrames_HalfFPS() {
        let frames = createTestFrames(count: 30)

        let reduced = GIFEncoder.reduceFrames(frames, targetFPS: 15, sourceFPS: 30)

        // Every other frame should be kept
        XCTAssertEqual(reduced.count, 15, "Half FPS should keep half the frames")
    }

    func testReduceFrames_ThirdFPS() {
        let frames = createTestFrames(count: 30)

        let reduced = GIFEncoder.reduceFrames(frames, targetFPS: 10, sourceFPS: 30)

        // Every third frame should be kept
        XCTAssertEqual(reduced.count, 10, "Third FPS should keep a third of frames")
    }

    func testReduceFrames_HigherTargetFPS() {
        let frames = createTestFrames(count: 15)

        let reduced = GIFEncoder.reduceFrames(frames, targetFPS: 30, sourceFPS: 15)

        // Cannot increase FPS, should return all frames
        XCTAssertEqual(reduced.count, 15, "Higher target FPS should keep all frames")
    }

    func testReduceFrames_EmptyArray() {
        let reduced = GIFEncoder.reduceFrames([], targetFPS: 15, sourceFPS: 30)

        XCTAssertEqual(reduced.count, 0, "Empty input should return empty output")
    }

    func testReduceFrames_SingleFrame() {
        let frames = createTestFrames(count: 1)

        let reduced = GIFEncoder.reduceFrames(frames, targetFPS: 15, sourceFPS: 30)

        XCTAssertEqual(reduced.count, 1, "Single frame should be preserved")
    }

    func testReduceFrames_ZeroSourceFPS() {
        let frames = createTestFrames(count: 10)

        let reduced = GIFEncoder.reduceFrames(frames, targetFPS: 15, sourceFPS: 0)

        // Should return all frames to avoid division by zero
        XCTAssertEqual(reduced.count, 10)
    }

    func testReduceFrames_ZeroTargetFPS() {
        let frames = createTestFrames(count: 10)

        let reduced = GIFEncoder.reduceFrames(frames, targetFPS: 0, sourceFPS: 30)

        // Should return empty or single frame
        XCTAssertLessThanOrEqual(reduced.count, 1)
    }

    // MARK: - Integration-like Tests

    func testEncodeAfterReduceFrames() throws {
        let frames = createTestFrames(count: 30)

        // Reduce from 30fps to 15fps
        let reduced = GIFEncoder.reduceFrames(frames, targetFPS: 15, sourceFPS: 30)
        XCTAssertEqual(reduced.count, 15)

        let outputURL = tempDirectory.appendingPathComponent("reduced.gif")

        try GIFEncoder.encode(
            frames: reduced,
            frameDelay: 1.0 / 15.0,
            loopCount: 0,
            to: outputURL
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testEncodeWithLargeFrameCount() throws {
        // Test with more frames to ensure memory handling is correct
        let frames = createTestFrames(count: 100)

        let reduced = GIFEncoder.reduceFrames(frames, targetFPS: 10, sourceFPS: 30)
        XCTAssertLessThanOrEqual(reduced.count, 34) // Approximately 100/3

        let outputURL = tempDirectory.appendingPathComponent("large.gif")

        try GIFEncoder.encode(
            frames: reduced,
            frameDelay: 0.1,
            loopCount: 0,
            to: outputURL
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }
}

// MARK: - GIFEncoderError Equatable

extension GIFEncoderError: Equatable {
    public static func == (lhs: GIFEncoderError, rhs: GIFEncoderError) -> Bool {
        switch (lhs, rhs) {
        case (.noFrames, .noFrames),
             (.failedToCreateDestination, .failedToCreateDestination),
             (.failedToFinalize, .failedToFinalize):
            return true
        default:
            return false
        }
    }
}
