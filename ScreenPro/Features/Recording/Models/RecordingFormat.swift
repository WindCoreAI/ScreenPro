import Foundation

/// The output format for recording
enum RecordingFormat: Sendable {
    /// Video recording (MP4/H.264)
    case video(VideoConfig)

    /// Animated GIF recording
    case gif(GIFConfig)

    /// File extension for this format
    var fileExtension: String {
        switch self {
        case .video: return "mp4"
        case .gif:   return "gif"
        }
    }

    /// Whether this format supports audio
    var supportsAudio: Bool {
        switch self {
        case .video: return true
        case .gif:   return false
        }
    }

    /// Default configuration for video recording
    static var defaultVideo: RecordingFormat {
        .video(VideoConfig())
    }

    /// Default configuration for GIF recording
    static var defaultGIF: RecordingFormat {
        .gif(GIFConfig())
    }
}
