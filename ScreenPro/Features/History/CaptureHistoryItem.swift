import Foundation
import SwiftData

// MARK: - Capture History Type (007-cloud-polish)

/// The kind of capture a history item represents.
enum CaptureHistoryType: String, Codable, CaseIterable, Sendable {
    case screenshot
    case video
    case gif

    var displayName: String {
        switch self {
        case .screenshot: return "Screenshot"
        case .video: return "Video"
        case .gif: return "GIF"
        }
    }

    var iconName: String {
        switch self {
        case .screenshot: return "photo"
        case .video: return "video"
        case .gif: return "photo.stack"
        }
    }
}

// MARK: - Capture History Item (007-cloud-polish)

/// A persisted record of a past capture, recording, or upload.
/// Stored with SwiftData; thumbnails are kept inline as JPEG data so history
/// remains browsable even after the original file is moved or deleted.
@Model
final class CaptureHistoryItem {
    @Attribute(.unique) var id: UUID
    var captureDate: Date

    /// Raw value of CaptureHistoryType (SwiftData-friendly storage).
    var typeRawValue: String

    /// Small JPEG preview of the capture.
    var thumbnailData: Data?

    /// Original filename, used for display and search.
    var filename: String?

    /// Absolute path of the saved file, if it was saved to disk.
    var filePath: String?

    /// Shareable link if the capture was uploaded.
    var cloudURL: String?

    /// Server-assigned upload identifier.
    var cloudID: String?

    /// Token required to delete the cloud upload.
    var cloudDeleteToken: String?

    var width: Int
    var height: Int
    var fileSize: Int64
    var tags: [String]

    init(
        id: UUID = UUID(),
        captureDate: Date = Date(),
        type: CaptureHistoryType,
        thumbnailData: Data? = nil,
        filename: String? = nil,
        filePath: String? = nil,
        width: Int = 0,
        height: Int = 0,
        fileSize: Int64 = 0,
        tags: [String] = []
    ) {
        self.id = id
        self.captureDate = captureDate
        self.typeRawValue = type.rawValue
        self.thumbnailData = thumbnailData
        self.filename = filename
        self.filePath = filePath
        self.width = width
        self.height = height
        self.fileSize = fileSize
        self.tags = tags
    }

    // MARK: - Computed Properties

    var type: CaptureHistoryType {
        CaptureHistoryType(rawValue: typeRawValue) ?? .screenshot
    }

    var fileURL: URL? {
        filePath.map { URL(fileURLWithPath: $0) }
    }

    var fileExists: Bool {
        guard let filePath else { return false }
        return FileManager.default.fileExists(atPath: filePath)
    }

    var shareURL: URL? {
        cloudURL.flatMap { URL(string: $0) }
    }

    var dimensionsText: String {
        "\(width) × \(height)"
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// Whether the item matches a free-text search over filename and tags.
    func matches(searchText: String) -> Bool {
        guard !searchText.isEmpty else { return true }
        if let filename, filename.localizedCaseInsensitiveContains(searchText) {
            return true
        }
        return tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
    }
}
