import Foundation

/// Result of a completed recording
struct RecordingResult: Identifiable, Sendable {
    /// Unique identifier for the recording
    let id: UUID

    /// File URL of the saved recording
    let url: URL

    /// Total duration in seconds
    let duration: TimeInterval

    /// The format used for this recording
    let format: RecordingFormat

    /// When the recording was created
    let timestamp: Date

    /// File size in bytes (computed lazily)
    var fileSize: Int64? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
    }

    /// Human-readable duration string (MM:SS)
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Human-readable file size string
    var formattedFileSize: String? {
        guard let size = fileSize else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    /// Initialize a new recording result
    init(
        id: UUID = UUID(),
        url: URL,
        duration: TimeInterval,
        format: RecordingFormat,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.duration = duration
        self.format = format
        self.timestamp = timestamp
    }
}
