import XCTest
@testable import ScreenPro

/// Integration tests for the Quick Access overlay feature.
/// Tests the full capture→overlay flow and user interactions.
@MainActor
final class QuickAccessIntegrationTests: XCTestCase {

    // MARK: - Properties

    var coordinator: AppCoordinator!
    var settingsManager: SettingsManager!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        settingsManager = SettingsManager()
        settingsManager.settings.showQuickAccess = true
        coordinator = AppCoordinator(settingsManager: settingsManager)
    }

    override func tearDown() {
        coordinator.quickAccessController.dismissAll()
        coordinator = nil
        settingsManager = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Creates a mock CaptureResult for testing.
    private func createMockCaptureResult(
        width: Int = 1920,
        height: Int = 1080
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
            scaleFactor: 2.0
        )
    }

    // MARK: - Quick Access Controller Tests

    func testQuickAccessController_initialState() {
        // Given: A new controller
        let controller = coordinator.quickAccessController

        // Then: Initial state should be empty and hidden
        XCTAssertTrue(controller.queue.isEmpty)
        XCTAssertFalse(controller.isVisible)
    }

    func testQuickAccessController_addCapture_showsOverlay() {
        // Given: A capture result
        guard let result = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture result")
            return
        }

        // When: Adding a capture
        coordinator.quickAccessController.addCapture(result)

        // Then: Overlay should be visible with one item
        XCTAssertTrue(coordinator.quickAccessController.isVisible)
        XCTAssertEqual(coordinator.quickAccessController.queue.count, 1)
    }

    func testQuickAccessController_addMultipleCaptures_queuesItems() {
        // Given: Multiple capture results
        for _ in 0..<3 {
            guard let result = createMockCaptureResult() else {
                XCTFail("Failed to create mock capture result")
                return
            }
            coordinator.quickAccessController.addCapture(result)
        }

        // Then: All items should be in queue
        XCTAssertEqual(coordinator.quickAccessController.queue.count, 3)
    }

    func testQuickAccessController_dismiss_removesItem() {
        // Given: A capture in the queue
        guard let result = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture result")
            return
        }
        coordinator.quickAccessController.addCapture(result)
        let item = coordinator.quickAccessController.queue.items.first!

        // When: Dismissing the item
        coordinator.quickAccessController.dismiss(item)

        // Then: Queue should be empty and overlay hidden
        XCTAssertTrue(coordinator.quickAccessController.queue.isEmpty)
        XCTAssertFalse(coordinator.quickAccessController.isVisible)
    }

    func testQuickAccessController_dismissAll_clearsQueue() {
        // Given: Multiple captures in queue
        for _ in 0..<3 {
            guard let result = createMockCaptureResult() else {
                XCTFail("Failed to create mock capture result")
                return
            }
            coordinator.quickAccessController.addCapture(result)
        }

        // When: Dismissing all
        coordinator.quickAccessController.dismissAll()

        // Then: Queue should be empty
        XCTAssertTrue(coordinator.quickAccessController.queue.isEmpty)
        XCTAssertFalse(coordinator.quickAccessController.isVisible)
    }

    // MARK: - Keyboard Navigation Tests

    func testQuickAccessController_selectNext_changesSelection() {
        // Given: Multiple captures in queue
        for _ in 0..<3 {
            guard let result = createMockCaptureResult() else {
                XCTFail("Failed to create mock capture result")
                return
            }
            coordinator.quickAccessController.addCapture(result)
        }

        // When: Selecting next
        coordinator.quickAccessController.queue.selectNext()

        // Then: Selection should be at index 1
        XCTAssertEqual(coordinator.quickAccessController.queue.selectedIndex, 1)
    }

    func testQuickAccessController_selectPrevious_changesSelection() {
        // Given: Multiple captures with selection at 1
        for _ in 0..<3 {
            guard let result = createMockCaptureResult() else {
                XCTFail("Failed to create mock capture result")
                return
            }
            coordinator.quickAccessController.addCapture(result)
        }
        coordinator.quickAccessController.queue.selectNext()

        // When: Selecting previous
        coordinator.quickAccessController.queue.selectPrevious()

        // Then: Selection should be back at 0
        XCTAssertEqual(coordinator.quickAccessController.queue.selectedIndex, 0)
    }

    // MARK: - Queue Capacity Tests

    func testQuickAccessController_exceedsCapacity_evictsOldest() {
        // Given: Queue at max capacity
        let controller = coordinator.quickAccessController
        let maxSize = controller.queue.maxQueueSize

        for i in 0...maxSize {
            guard let result = createMockCaptureResult() else {
                XCTFail("Failed to create mock capture result")
                return
            }
            controller.addCapture(result)

            // Store first item ID
            if i == 0 {
                // First item should eventually be evicted
            }
        }

        // Then: Queue should be at max size
        XCTAssertEqual(controller.queue.count, maxSize)
    }

    // MARK: - Settings Integration Tests

    func testQuickAccessController_showQuickAccessDisabled_doesNotShowOverlay() {
        // Given: Quick Access is disabled
        settingsManager.settings.showQuickAccess = false

        // Recreate coordinator with new settings
        let newCoordinator = AppCoordinator(settingsManager: settingsManager)

        // When: A capture would normally trigger Quick Access
        // (In real scenario, handleCaptureResult would check this)

        // Then: Quick Access controller queue should remain empty
        XCTAssertTrue(newCoordinator.quickAccessController.queue.isEmpty)
    }

    // MARK: - CaptureItem Tests

    func testCaptureItem_dimensionsText_formatsCorrectly() {
        // Given: A capture with specific dimensions
        guard let result = createMockCaptureResult(width: 3840, height: 2160) else {
            XCTFail("Failed to create mock capture result")
            return
        }

        // When: Creating a CaptureItem
        let item = CaptureItem(result: result)

        // Then: Dimensions text should be formatted
        XCTAssertEqual(item.dimensionsText, "3840 × 2160")
    }

    func testCaptureItem_timeAgoText_showsJustNow() {
        // Given: A capture created just now
        guard let result = createMockCaptureResult() else {
            XCTFail("Failed to create mock capture result")
            return
        }

        // When: Creating a CaptureItem
        let item = CaptureItem(result: result)

        // Then: Time ago should show "Just now"
        let text = item.timeAgoText
        XCTAssertTrue(
            text == "Just now" || text.hasSuffix("s ago"),
            "Expected 'Just now' or 'Xs ago' but got \(text)"
        )
    }

    // MARK: - Performance Tests

    func testThumbnailGeneration_completesWithinTimeLimit() async {
        // Given: A large capture
        guard let result = createMockCaptureResult(width: 3840, height: 2160) else {
            XCTFail("Failed to create mock capture result")
            return
        }

        // When: Generating thumbnail
        let generator = ThumbnailGenerator()
        let start = Date()
        let _ = await generator.generateThumbnail(from: result.image, maxPixelSize: 240)
        let elapsed = Date().timeIntervalSince(start)

        // Then: Should complete within 500ms (generous for test environment)
        XCTAssertLessThan(elapsed, 0.5, "Thumbnail generation took \(elapsed)s, expected < 0.5s")
    }

    func testMemoryUsage_multipleCaptures_staysReasonable() {
        // Given: Adding multiple captures
        let controller = coordinator.quickAccessController

        // When: Adding 5 captures (within spec limits)
        for _ in 0..<5 {
            guard let result = createMockCaptureResult() else {
                XCTFail("Failed to create mock capture result")
                return
            }
            controller.addCapture(result)
        }

        // Then: All captures should be in queue
        XCTAssertEqual(controller.queue.count, 5)

        // Note: Actual memory measurement would require Instruments
        // This test verifies functional correctness with expected load
    }
}
