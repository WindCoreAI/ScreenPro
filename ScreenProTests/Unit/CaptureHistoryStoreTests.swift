import XCTest
import AppKit
@testable import ScreenPro

/// Unit tests for CaptureHistoryStore using an in-memory container (007-cloud-polish).
@MainActor
final class CaptureHistoryStoreTests: XCTestCase {

    // MARK: - Helpers

    private func makeStore() throws -> CaptureHistoryStore {
        try CaptureHistoryStore(inMemory: true)
    }

    private func makeCGImage(width: Int = 100, height: Int = 60) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        return context.makeImage()
    }

    private func makeCaptureResult(width: Int = 100, height: Int = 60) -> CaptureResult? {
        guard let image = makeCGImage(width: width, height: height) else { return nil }
        return CaptureResult(
            image: image,
            mode: .area(CGRect(x: 0, y: 0, width: width, height: height)),
            sourceRect: CGRect(x: 0, y: 0, width: width, height: height),
            scaleFactor: 2.0
        )
    }

    // MARK: - Recording

    func testRecordCapture_addsItemWithMetadata() throws {
        let store = try makeStore()
        guard let result = makeCaptureResult(width: 200, height: 100) else {
            XCTFail("Failed to create capture result")
            return
        }

        let item = store.recordCapture(result, fileURL: nil)

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(item.id, result.id)
        XCTAssertEqual(item.type, .screenshot)
        XCTAssertEqual(item.width, 200)
        XCTAssertEqual(item.height, 100)
        XCTAssertNotNil(item.thumbnailData)
        XCTAssertNil(item.filePath)
    }

    func testRecordCapture_updatesExistingItemWhenSavedLater() throws {
        let store = try makeStore()
        guard let result = makeCaptureResult() else {
            XCTFail("Failed to create capture result")
            return
        }

        // Capture first lands in history without a file (Quick Access flow)
        store.recordCapture(result, fileURL: nil)
        // Then the user saves it from the overlay
        let url = URL(fileURLWithPath: "/tmp/Screenshot Test.png")
        store.recordCapture(result, fileURL: url)

        XCTAssertEqual(store.items.count, 1, "Saving should update the entry, not duplicate it")
        XCTAssertEqual(store.items.first?.filePath, url.path)
        XCTAssertEqual(store.items.first?.filename, "Screenshot Test.png")
    }

    func testRecordRecording_detectsGIFType() throws {
        let store = try makeStore()
        let result = RecordingResult(
            url: URL(fileURLWithPath: "/tmp/recording.gif"),
            duration: 5,
            format: .gif(GIFConfig(frameRate: 15, maxColors: 256, loopCount: 0, scale: 1.0))
        )

        let item = store.recordRecording(result, thumbnail: makeCGImage())

        XCTAssertEqual(item.type, .gif)
        XCTAssertEqual(item.filename, "recording.gif")
    }

    // MARK: - Cloud Attachment

    func testAttachCloudUpload_setsCloudFields() throws {
        let store = try makeStore()
        guard let result = makeCaptureResult() else {
            XCTFail("Failed to create capture result")
            return
        }
        store.recordCapture(result, fileURL: nil)

        let shareURL = URL(string: "https://share.example.com/abc")!
        store.attachCloudUpload(
            captureID: result.id,
            result: result,
            url: shareURL,
            cloudID: "abc",
            deleteToken: "tok"
        )

        let item = store.items.first
        XCTAssertEqual(item?.cloudURL, shareURL.absoluteString)
        XCTAssertEqual(item?.cloudID, "abc")
        XCTAssertEqual(item?.cloudDeleteToken, "tok")
    }

    func testAttachCloudUpload_createsItemWhenNotRecorded() throws {
        let store = try makeStore()
        guard let result = makeCaptureResult() else {
            XCTFail("Failed to create capture result")
            return
        }

        store.attachCloudUpload(
            captureID: result.id,
            result: result,
            url: URL(string: "https://share.example.com/xyz")!,
            cloudID: "xyz",
            deleteToken: "tok"
        )

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.cloudID, "xyz")
    }

    // MARK: - Filtering & Search

    func testFilteredItems_filtersByType() throws {
        let store = try makeStore()
        store.addItem(CaptureHistoryItem(type: .screenshot, filename: "shot.png"))
        store.addItem(CaptureHistoryItem(type: .video, filename: "clip.mp4"))
        store.addItem(CaptureHistoryItem(type: .gif, filename: "anim.gif"))

        store.filterType = .video

        XCTAssertEqual(store.filteredItems.count, 1)
        XCTAssertEqual(store.filteredItems.first?.filename, "clip.mp4")
    }

    func testFilteredItems_searchMatchesFilenameCaseInsensitively() throws {
        let store = try makeStore()
        store.addItem(CaptureHistoryItem(type: .screenshot, filename: "Invoice March.png"))
        store.addItem(CaptureHistoryItem(type: .screenshot, filename: "Vacation.png"))

        store.searchText = "invoice"

        XCTAssertEqual(store.filteredItems.count, 1)
        XCTAssertEqual(store.filteredItems.first?.filename, "Invoice March.png")
    }

    func testFilteredItems_searchMatchesTags() throws {
        let store = try makeStore()
        store.addItem(CaptureHistoryItem(type: .screenshot, filename: "a.png", tags: ["work", "bug-report"]))
        store.addItem(CaptureHistoryItem(type: .screenshot, filename: "b.png"))

        store.searchText = "bug"

        XCTAssertEqual(store.filteredItems.count, 1)
    }

    // MARK: - Deletion & Retention

    func testDeleteItem_removesFromStore() throws {
        let store = try makeStore()
        let item = CaptureHistoryItem(type: .screenshot)
        store.addItem(item)
        XCTAssertEqual(store.items.count, 1)

        store.deleteItem(item)

        XCTAssertTrue(store.items.isEmpty)
    }

    func testClearOlderThan_removesOnlyOldItems() throws {
        let store = try makeStore()
        let oldItem = CaptureHistoryItem(
            captureDate: Date().addingTimeInterval(-100 * 86400),
            type: .screenshot,
            filename: "old.png"
        )
        let newItem = CaptureHistoryItem(type: .screenshot, filename: "new.png")
        store.addItem(oldItem)
        store.addItem(newItem)

        store.clearOlderThan(Date().addingTimeInterval(-30 * 86400))

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.filename, "new.png")
    }

    func testApplyRetentionPolicy_zeroDaysRetainsEverything() throws {
        let store = try makeStore()
        store.addItem(CaptureHistoryItem(
            captureDate: Date().addingTimeInterval(-365 * 86400),
            type: .screenshot
        ))

        store.applyRetentionPolicy(days: 0)

        XCTAssertEqual(store.items.count, 1)
    }

    // MARK: - Sorting

    func testFetchItems_sortsNewestFirst() throws {
        let store = try makeStore()
        store.addItem(CaptureHistoryItem(
            captureDate: Date().addingTimeInterval(-3600),
            type: .screenshot,
            filename: "older.png"
        ))
        store.addItem(CaptureHistoryItem(type: .screenshot, filename: "newer.png"))

        XCTAssertEqual(store.items.first?.filename, "newer.png")
        XCTAssertEqual(store.items.last?.filename, "older.png")
    }

    // MARK: - Thumbnails

    func testGenerateThumbnail_constrainsLongestEdge() throws {
        guard let image = makeCGImage(width: 2000, height: 1000) else {
            XCTFail("Failed to create image")
            return
        }

        let data = CaptureHistoryStore.generateThumbnail(from: image, maxSize: 320)

        let thumbnailData = try XCTUnwrap(data)
        let thumbnail = try XCTUnwrap(NSImage(data: thumbnailData))
        XCTAssertLessThanOrEqual(thumbnail.size.width, 320)
        XCTAssertLessThanOrEqual(thumbnail.size.height, 320)
    }
}
