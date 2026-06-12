import Foundation
import SwiftData
import AppKit

// MARK: - CaptureHistoryStore (007-cloud-polish)

/// Persists and queries capture history using SwiftData.
/// Owns the model container; all access happens on the main actor.
@MainActor
final class CaptureHistoryStore: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var items: [CaptureHistoryItem] = []
    @Published var searchText: String = ""
    @Published var filterType: CaptureHistoryType?

    // MARK: - Private Properties

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    // MARK: - Initialization

    /// Creates a history store.
    /// - Parameter inMemory: When true, history is not persisted to disk (used by tests).
    init(inMemory: Bool = false) throws {
        let schema = Schema([CaptureHistoryItem.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = false
    }

    // MARK: - Querying

    /// Items matching the current search text and type filter.
    var filteredItems: [CaptureHistoryItem] {
        items.filter { item in
            if let filterType, item.type != filterType {
                return false
            }
            return item.matches(searchText: searchText)
        }
    }

    /// Reloads items from the store, newest first.
    func fetchItems(limit: Int = 500) {
        var descriptor = FetchDescriptor<CaptureHistoryItem>(
            sortBy: [SortDescriptor(\.captureDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        do {
            items = try modelContext.fetch(descriptor)
        } catch {
            print("[CaptureHistoryStore] Failed to fetch history: \(error)")
        }
    }

    /// Finds an item by capture identifier.
    func item(withID id: UUID) -> CaptureHistoryItem? {
        if let cached = items.first(where: { $0.id == id }) {
            return cached
        }
        var descriptor = FetchDescriptor<CaptureHistoryItem>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    // MARK: - Recording

    /// Records a screenshot capture, generating an inline thumbnail.
    /// - Parameters:
    ///   - result: The capture that was produced.
    ///   - fileURL: Where the capture was saved, if it was saved.
    @discardableResult
    func recordCapture(_ result: CaptureResult, fileURL: URL?) -> CaptureHistoryItem {
        // Avoid duplicate entries when the same capture is saved and later uploaded.
        if let existing = item(withID: result.id) {
            // Only screenshots get their file updated here; recordings shown in
            // Quick Access share the same id, and saving their thumbnail image
            // must not overwrite the entry pointing at the video file.
            if let fileURL, existing.type == .screenshot {
                existing.filePath = fileURL.path
                existing.filename = fileURL.lastPathComponent
                existing.fileSize = Self.fileSize(at: fileURL)
            }
            save()
            fetchItems()
            return existing
        }

        let item = CaptureHistoryItem(
            id: result.id,
            captureDate: result.timestamp,
            type: .screenshot,
            thumbnailData: Self.generateThumbnail(from: result.image),
            filename: fileURL?.lastPathComponent,
            filePath: fileURL?.path,
            width: result.image.width,
            height: result.image.height,
            fileSize: fileURL.map(Self.fileSize(at:)) ?? 0
        )
        addItem(item)
        return item
    }

    /// Records a completed video or GIF recording.
    @discardableResult
    func recordRecording(_ result: RecordingResult, thumbnail: CGImage?) -> CaptureHistoryItem {
        let isGIF = result.url.pathExtension.lowercased() == "gif"

        let item = CaptureHistoryItem(
            id: result.id,
            captureDate: result.timestamp,
            type: isGIF ? .gif : .video,
            thumbnailData: thumbnail.flatMap { Self.generateThumbnail(from: $0) },
            filename: result.url.lastPathComponent,
            filePath: result.url.path,
            width: thumbnail?.width ?? 0,
            height: thumbnail?.height ?? 0,
            fileSize: result.fileSize ?? 0
        )
        addItem(item)
        return item
    }

    /// Attaches cloud upload metadata to an existing item, or records a new
    /// item when the capture was uploaded without being saved locally.
    func attachCloudUpload(
        captureID: UUID,
        result: CaptureResult?,
        url: URL,
        cloudID: String,
        deleteToken: String
    ) {
        let target: CaptureHistoryItem
        if let existing = item(withID: captureID) {
            target = existing
        } else if let result {
            target = recordCapture(result, fileURL: nil)
        } else {
            return
        }

        target.cloudURL = url.absoluteString
        target.cloudID = cloudID
        target.cloudDeleteToken = deleteToken
        save()
        fetchItems()
    }

    // MARK: - Mutation

    func addItem(_ item: CaptureHistoryItem) {
        modelContext.insert(item)
        save()
        fetchItems()
    }

    /// Deletes a history item.
    /// - Parameters:
    ///   - item: The item to delete.
    ///   - removeFile: When true, also deletes the underlying file from disk.
    func deleteItem(_ item: CaptureHistoryItem, removeFile: Bool = false) {
        if removeFile, let path = item.filePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        modelContext.delete(item)
        save()
        fetchItems()
    }

    /// Removes history entries older than the given date (files stay on disk).
    func clearOlderThan(_ date: Date) {
        let predicate = #Predicate<CaptureHistoryItem> { $0.captureDate < date }
        do {
            try modelContext.delete(model: CaptureHistoryItem.self, where: predicate)
            save()
            fetchItems()
        } catch {
            print("[CaptureHistoryStore] Failed to clear old history: \(error)")
        }
    }

    /// Applies the configured retention policy.
    /// - Parameter days: Number of days of history to retain. Values <= 0 retain everything.
    func applyRetentionPolicy(days: Int) {
        guard days > 0 else { return }
        let cutoff = Date().addingTimeInterval(-TimeInterval(days) * 86400)
        clearOlderThan(cutoff)
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("[CaptureHistoryStore] Failed to save history: \(error)")
        }
    }

    // MARK: - Thumbnail Generation

    /// Generates a JPEG thumbnail constrained to maxSize on the longest edge.
    static func generateThumbnail(from image: CGImage, maxSize: CGFloat = 320) -> Data? {
        let aspectRatio = CGFloat(image.width) / CGFloat(image.height)
        let thumbnailSize: CGSize
        if aspectRatio > 1 {
            thumbnailSize = CGSize(width: maxSize, height: max(1, maxSize / aspectRatio))
        } else {
            thumbnailSize = CGSize(width: max(1, maxSize * aspectRatio), height: maxSize)
        }

        guard let context = CGContext(
            data: nil,
            width: Int(thumbnailSize.width),
            height: Int(thumbnailSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: thumbnailSize))

        guard let thumbnail = context.makeImage() else { return nil }

        let bitmapRep = NSBitmapImageRep(cgImage: thumbnail)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
    }

    // MARK: - File Helpers

    private static func fileSize(at url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }
}
