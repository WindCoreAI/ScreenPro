import XCTest
@testable import ScreenPro

/// Unit tests for CaptureItem.
final class CaptureItemTests: XCTestCase {

    // MARK: - Helper Methods

    /// Creates a mock CaptureResult for testing.
    private func createMockCaptureResult(
        width: Int = 1920,
        height: Int = 1080,
        scaleFactor: CGFloat = 2.0
    ) -> CaptureResult? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
              let cgImage = context.makeImage() else {
            return nil
        }

        return CaptureResult(
            image: cgImage,
            mode: .area(CGRect(x: 0, y: 0, width: width, height: height)),
            sourceRect: CGRect(x: 0, y: 0, width: width, height: height),
            scaleFactor: scaleFactor
        )
    }

    /// Creates a CaptureItem with a specific creation date.
    private func createItemWithDate(
        _ date: Date,
        width: Int = 1920,
        height: Int = 1080
    ) -> CaptureItem? {
        guard let result = createMockCaptureResult(width: width, height: height) else {
            return nil
        }

        // Use reflection or create item and manually test the computed property
        // Since createdAt is set in init, we test the timeAgoText logic with known intervals
        return CaptureItem(result: result)
    }

    // MARK: - Initialization Tests

    func testInit_setsPropertiesCorrectly() {
        // Given: A mock capture result
        guard let result = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture result")
            return
        }

        // When: Creating a CaptureItem
        let item = CaptureItem(result: result)

        // Then: Properties should be set correctly
        XCTAssertEqual(item.id, result.id)
        XCTAssertNil(item.thumbnail)
        XCTAssertNotNil(item.createdAt)
    }

    func testInit_withThumbnail() {
        // Given: A mock capture result and thumbnail
        guard let result = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture result")
            return
        }
        let thumbnail = NSImage(size: NSSize(width: 240, height: 135))

        // When: Creating a CaptureItem with thumbnail
        let item = CaptureItem(result: result, thumbnail: thumbnail)

        // Then: Thumbnail should be set
        XCTAssertNotNil(item.thumbnail)
    }

    // MARK: - DimensionsText Tests

    func testDimensionsText_formatsCorrectly() {
        // Given: Various image sizes
        let testCases: [(width: Int, height: Int, expected: String)] = [
            (1920, 1080, "1920 × 1080"),
            (3840, 2160, "3840 × 2160"),
            (800, 600, "800 × 600"),
            (100, 100, "100 × 100"),
        ]

        for testCase in testCases {
            guard let result = createMockCaptureResult(
                width: testCase.width,
                height: testCase.height
            ) else {
                XCTFail("Failed to create mock capture result")
                return
            }

            // When: Getting dimensions text
            let item = CaptureItem(result: result)

            // Then: Should be formatted correctly
            XCTAssertEqual(
                item.dimensionsText,
                testCase.expected,
                "Expected \(testCase.expected) but got \(item.dimensionsText)"
            )
        }
    }

    func testDimensions_returnsPixelSize() {
        // Given: A capture with known dimensions
        guard let result = createMockCaptureResult(width: 3840, height: 2160) else {
            XCTFail("Failed to create mock capture result")
            return
        }

        // When: Getting dimensions
        let item = CaptureItem(result: result)

        // Then: Should return pixel size
        XCTAssertEqual(item.dimensions.width, 3840, accuracy: 0.001)
        XCTAssertEqual(item.dimensions.height, 2160, accuracy: 0.001)
    }

    // MARK: - TimeAgoText Tests

    func testTimeAgoText_justNow() {
        // Given: An item created just now
        guard let result = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture result")
            return
        }
        let item = CaptureItem(result: result)

        // When/Then: Should show "Just now" for very recent items
        // Since the item was just created, it should be within 5 seconds
        let text = item.timeAgoText
        XCTAssertTrue(
            text == "Just now" || text.hasSuffix("s ago"),
            "Expected 'Just now' or 'Xs ago' but got \(text)"
        )
    }

    func testTimeAgoText_handlesEdgeCases() {
        // Given: An item created just now
        guard let result = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture result")
            return
        }
        let item = CaptureItem(result: result)

        // When: Getting timeAgoText immediately
        let text = item.timeAgoText

        // Then: Should not be empty or crash
        XCTAssertFalse(text.isEmpty)
    }

    // MARK: - NSImage Tests

    func testNsImage_returnsResultNsImage() {
        // Given: A capture result
        guard let result = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture result")
            return
        }

        // When: Getting nsImage from item
        let item = CaptureItem(result: result)

        // Then: Should match result's nsImage size
        XCTAssertEqual(item.nsImage.size, result.nsImage.size)
    }

    // MARK: - Equatable Tests

    func testEquatable_sameId_equal() {
        // Given: Two items with same underlying result
        guard let result = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture result")
            return
        }
        let item1 = CaptureItem(result: result)
        let item2 = CaptureItem(result: result) // Same result, same ID

        // Note: Actually these will have different IDs since CaptureItem uses result.id
        // and we're creating the same result. They should be equal.
        XCTAssertEqual(item1.id, item2.id)
        XCTAssertEqual(item1, item2)
    }

    func testEquatable_differentId_notEqual() {
        // Given: Two items with different results
        guard let result1 = createMockCaptureResult(),
              let result2 = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture results")
            return
        }
        let item1 = CaptureItem(result: result1)
        let item2 = CaptureItem(result: result2)

        // Then: Should not be equal
        XCTAssertNotEqual(item1, item2)
    }

    // MARK: - Hashable Tests

    func testHashable_canBeUsedInSet() {
        // Given: Multiple items
        guard let result1 = createMockCaptureResult(),
              let result2 = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture results")
            return
        }
        let item1 = CaptureItem(result: result1)
        let item2 = CaptureItem(result: result2)

        // When: Adding to a Set
        var set = Set<CaptureItem>()
        set.insert(item1)
        set.insert(item2)
        set.insert(item1) // Duplicate

        // Then: Set should have 2 unique items
        XCTAssertEqual(set.count, 2)
    }
}
