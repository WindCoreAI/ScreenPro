import Foundation

// MARK: - AspectRatioPreset (T061)

/// Preset aspect ratios for social media and common formats.
enum AspectRatioPreset: String, Codable, CaseIterable, Identifiable {
    case twitter       // 16:9 (1200x675)
    case instagram     // 1:1 (1080x1080)
    case instagramStory // 9:16 (1080x1920)
    case facebook      // 1.91:1 (1200x628)
    case linkedin      // 1.91:1 (1200x627)
    case youtube       // 16:9 (1280x720)
    case freeform      // Custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .twitter: return "Twitter (16:9)"
        case .instagram: return "Instagram (1:1)"
        case .instagramStory: return "Instagram Story (9:16)"
        case .facebook: return "Facebook (1.91:1)"
        case .linkedin: return "LinkedIn (1.91:1)"
        case .youtube: return "YouTube (16:9)"
        case .freeform: return "Freeform"
        }
    }

    /// Aspect ratio as width/height.
    var aspectRatio: CGFloat {
        switch self {
        case .twitter: return 16.0 / 9.0
        case .instagram: return 1.0
        case .instagramStory: return 9.0 / 16.0
        case .facebook: return 1.91
        case .linkedin: return 1.91
        case .youtube: return 16.0 / 9.0
        case .freeform: return 0 // Indicates no constraint
        }
    }

    /// Default output size for 2x export.
    var defaultSize: CGSize {
        switch self {
        case .twitter: return CGSize(width: 2400, height: 1350)
        case .instagram: return CGSize(width: 2160, height: 2160)
        case .instagramStory: return CGSize(width: 2160, height: 3840)
        case .facebook: return CGSize(width: 2400, height: 1256)
        case .linkedin: return CGSize(width: 2400, height: 1254)
        case .youtube: return CGSize(width: 2560, height: 1440)
        case .freeform: return .zero // Determined by content
        }
    }

    /// Icon for the preset.
    var icon: String {
        switch self {
        case .twitter: return "bird"
        case .instagram: return "camera"
        case .instagramStory: return "rectangle.portrait"
        case .facebook: return "person.2"
        case .linkedin: return "briefcase"
        case .youtube: return "play.rectangle"
        case .freeform: return "arrow.left.and.right"
        }
    }
}
