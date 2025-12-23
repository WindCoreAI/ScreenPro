import XCTest
@testable import ScreenPro

/// Unit tests for CaptureQueue.
@MainActor
final class CaptureQueueTests: XCTestCase {

    // MARK: - Properties

    var sut: CaptureQueue!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        sut = CaptureQueue()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Creates a mock CaptureResult for testing.
    private func createMockCaptureResult() -> CaptureResult? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 1920,
            height: 1080,
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
            mode: .area(CGRect(x: 0, y: 0, width: 1920, height: 1080)),
            sourceRect: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            scaleFactor: 2.0
        )
    }

    // MARK: - Initial State Tests

    func testInitialState_isEmpty() {
        // Then: Queue should start empty
        XCTAssertTrue(sut.isEmpty)
        XCTAssertEqual(sut.count, 0)
        XCTAssertEqual(sut.selectedIndex, 0)
        XCTAssertNil(sut.selected)
    }

    // MARK: - Add Tests

    func testAdd_insertsAtFront() {
        // Given: Mock capture results
        guard let result1 = createMockCaptureResult(),
              let result2 = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture results")
            return
        }

        // When: Adding two captures
        let item1 = sut.add(result1)
        let item2 = sut.add(result2)

        // Then: Second item should be at front (index 0)
        XCTAssertEqual(sut.count, 2)
        XCTAssertEqual(sut.items[0].id, item2.id)
        XCTAssertEqual(sut.items[1].id, item1.id)
    }

    func testAdd_setsSelectionToZero() {
        // Given: A mock capture result
        guard let result = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture result")
            return
        }

        // When: Adding a capture
        _ = sut.add(result)

        // Then: Selection should be at 0
        XCTAssertEqual(sut.selectedIndex, 0)
        XCTAssertNotNil(sut.selected)
    }

    func testAdd_returnsCaptureItem() {
        // Given: A mock capture result
        guard let result = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture result")
            return
        }

        // When: Adding a capture
        let item = sut.add(result)

        // Then: Returned item should have correct ID
        XCTAssertEqual(item.id, result.id)
        XCTAssertEqual(item.result.id, result.id)
    }

    // MARK: - Capacity Tests

    func testAdd_evictsOldestWhenAtCapacity() {
        // Given: Queue at max capacity
        var firstItemId: UUID?
        for i in 0..<sut.maxQueueSize {
            guard let result = createMockCaptureResult() else {
                XCTFail("Failed to create mock capture result")
                return
            }
            let item = sut.add(result)
            if i == 0 {
                firstItemId = item.id
            }
        }

        XCTAssertEqual(sut.count, sut.maxQueueSize)

        // When: Adding one more
        guard let newResult = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture result")
            return
        }
        _ = sut.add(newResult)

        // Then: Count should still be max, and oldest item should be evicted
        XCTAssertEqual(sut.count, sut.maxQueueSize)
        XCTAssertNil(sut.items.first(where: { $0.id == firstItemId }))
    }

    // MARK: - Remove Tests

    func testRemove_removesCorrectItem() {
        // Given: Multiple items in queue
        guard let result1 = createMockCaptureResult(),
              let result2 = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture results")
            return
        }

        let item1 = sut.add(result1)
        let item2 = sut.add(result2)

        // When: Removing first item
        sut.remove(item1.id)

        // Then: Only second item should remain
        XCTAssertEqual(sut.count, 1)
        XCTAssertEqual(sut.items[0].id, item2.id)
    }

    func testRemove_adjustsSelectionIndex() {
        // Given: Multiple items with selection at end
        guard let result1 = createMockCaptureResult(),
              let result2 = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture results")
            return
        }

        _ = sut.add(result1)
        let item2 = sut.add(result2)
        sut.selectNext() // Move selection to index 1

        // When: Removing the second item (at selection)
        sut.remove(sut.items[1].id)

        // Then: Selection should adjust to stay in bounds
        XCTAssertEqual(sut.selectedIndex, 0)
        XCTAssertEqual(sut.selected?.id, item2.id)
    }

    func testRemove_nonexistentItem_noEffect() {
        // Given: An item in queue
        guard let result = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture result")
            return
        }
        _ = sut.add(result)

        // When: Removing non-existent ID
        sut.remove(UUID())

        // Then: Queue should be unchanged
        XCTAssertEqual(sut.count, 1)
    }

    // MARK: - Clear Tests

    func testClear_removesAllItems() {
        // Given: Multiple items in queue
        for _ in 0..<5 {
            guard let result = createMockCaptureResult() else {
                XCTFail("Failed to create mock capture result")
                return
            }
            _ = sut.add(result)
        }

        // When: Clearing the queue
        sut.clear()

        // Then: Queue should be empty
        XCTAssertTrue(sut.isEmpty)
        XCTAssertEqual(sut.count, 0)
        XCTAssertEqual(sut.selectedIndex, 0)
    }

    // MARK: - Selection Tests

    func testSelectNext_incrementsIndex() {
        // Given: Multiple items in queue
        for _ in 0..<3 {
            guard let result = createMockCaptureResult() else {
                XCTFail("Failed to create mock capture result")
                return
            }
            _ = sut.add(result)
        }

        // Selection starts at 0 after last add

        // When: Selecting next twice
        sut.selectNext()
        sut.selectNext()

        // Then: Selection should be at 2
        XCTAssertEqual(sut.selectedIndex, 2)
    }

    func testSelectNext_stopsAtEnd() {
        // Given: Items in queue with selection near end
        for _ in 0..<3 {
            guard let result = createMockCaptureResult() else {
                XCTFail("Failed to create mock capture result")
                return
            }
            _ = sut.add(result)
        }

        // When: Selecting next many times
        for _ in 0..<10 {
            sut.selectNext()
        }

        // Then: Selection should stop at last index
        XCTAssertEqual(sut.selectedIndex, 2)
    }

    func testSelectPrevious_decrementsIndex() {
        // Given: Items in queue with selection in middle
        for _ in 0..<3 {
            guard let result = createMockCaptureResult() else {
                XCTFail("Failed to create mock capture result")
                return
            }
            _ = sut.add(result)
        }
        sut.selectNext()
        sut.selectNext()

        // When: Selecting previous
        sut.selectPrevious()

        // Then: Selection should be at 1
        XCTAssertEqual(sut.selectedIndex, 1)
    }

    func testSelectPrevious_stopsAtZero() {
        // Given: Items in queue with selection at 0
        guard let result = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture result")
            return
        }
        _ = sut.add(result)

        // When: Selecting previous
        sut.selectPrevious()

        // Then: Selection should stay at 0
        XCTAssertEqual(sut.selectedIndex, 0)
    }

    func testSelectNext_emptyQueue_noEffect() {
        // Given: Empty queue

        // When: Selecting next
        sut.selectNext()

        // Then: No crash, index stays at 0
        XCTAssertEqual(sut.selectedIndex, 0)
    }

    // MARK: - Item Access Tests

    func testItemAt_returnsCorrectItem() {
        // Given: Items in queue
        guard let result = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture result")
            return
        }
        let item = sut.add(result)

        // When: Getting item at index 0
        let retrieved = sut.item(at: 0)

        // Then: Should return the correct item
        XCTAssertEqual(retrieved?.id, item.id)
    }

    func testItemAt_outOfBounds_returnsNil() {
        // Given: Items in queue
        guard let result = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture result")
            return
        }
        _ = sut.add(result)

        // When: Getting item at invalid indices
        let negative = sut.item(at: -1)
        let tooLarge = sut.item(at: 10)

        // Then: Should return nil
        XCTAssertNil(negative)
        XCTAssertNil(tooLarge)
    }

    func testIsSelected_returnsCorrectValue() {
        // Given: Multiple items in queue
        guard let result1 = createMockCaptureResult(),
              let result2 = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture results")
            return
        }

        _ = sut.add(result1)
        let item2 = sut.add(result2)

        // Selection is at 0 (item2)

        // When/Then: Check selection status
        XCTAssertTrue(sut.isSelected(item2))
        XCTAssertFalse(sut.isSelected(sut.items[1]))
    }

    // MARK: - Update Thumbnail Tests

    func testUpdateThumbnail_updatesCorrectItem() {
        // Given: Item in queue
        guard let result = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture result")
            return
        }
        let item = sut.add(result)
        XCTAssertNil(sut.items[0].thumbnail)

        // When: Updating thumbnail
        let thumbnail = NSImage(size: NSSize(width: 240, height: 135))
        sut.updateThumbnail(for: item.id, thumbnail: thumbnail)

        // Then: Thumbnail should be set
        XCTAssertNotNil(sut.items[0].thumbnail)
    }

    func testUpdateThumbnail_nonexistentItem_noEffect() {
        // Given: Item in queue
        guard let result = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture result")
            return
        }
        _ = sut.add(result)

        // When: Updating thumbnail for non-existent ID
        let thumbnail = NSImage(size: NSSize(width: 240, height: 135))
        sut.updateThumbnail(for: UUID(), thumbnail: thumbnail)

        // Then: Original item should be unchanged
        XCTAssertNil(sut.items[0].thumbnail)
    }
}
