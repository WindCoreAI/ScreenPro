import Foundation
import CoreGraphics

/// Configuration for video recording
struct VideoConfig: Codable, Equatable, Sendable {
    /// Output video resolution
    var resolution: Resolution = .r1080p

    /// Recording frame rate
    var frameRate: Int = 30

    /// Quality level (affects bitrate)
    var quality: Quality = .high

    /// Whether to capture system audio
    var includeSystemAudio: Bool = false

    /// Whether to capture microphone audio
    var includeMicrophone: Bool = false

    /// Whether to show click visualizations
    var showClicks: Bool = false

    /// Whether to show keystroke overlay
    var showKeystrokes: Bool = false

    /// Whether to show cursor in recording
    var showCursor: Bool = true

    // MARK: - Resolution

    /// Available video resolutions
    enum Resolution: String, CaseIterable, Codable, Sendable {
        case r480p
        case r720p
        case r1080p
        case r4k

        var size: CGSize {
            switch self {
            case .r480p:  return CGSize(width: 854, height: 480)
            case .r720p:  return CGSize(width: 1280, height: 720)
            case .r1080p: return CGSize(width: 1920, height: 1080)
            case .r4k:    return CGSize(width: 3840, height: 2160)
            }
        }

        var displayName: String {
            switch self {
            case .r480p:  return "480p"
            case .r720p:  return "720p"
            case .r1080p: return "1080p"
            case .r4k:    return "4K"
            }
        }

        /// Base bitrate in bits per second for this resolution at high quality
        var baseBitrate: Int {
            switch self {
            case .r480p:  return 2_500_000   // 2.5 Mbps
            case .r720p:  return 5_000_000   // 5 Mbps
            case .r1080p: return 10_000_000  // 10 Mbps
            case .r4k:    return 35_000_000  // 35 Mbps
            }
        }
    }

    // MARK: - Quality

    /// Quality levels affecting bitrate
    enum Quality: String, CaseIterable, Codable, Sendable {
        case low
        case medium
        case high
        case maximum

        var bitrateMultiplier: Double {
            switch self {
            case .low:     return 0.5
            case .medium:  return 0.75
            case .high:    return 1.0
            case .maximum: return 1.5
            }
        }

        var displayName: String {
            switch self {
            case .low:     return "Low"
            case .medium:  return "Medium"
            case .high:    return "High"
            case .maximum: return "Maximum"
            }
        }
    }

    // MARK: - Computed Properties

    /// Calculate the target bitrate based on resolution and quality
    var targetBitrate: Int {
        Int(Double(resolution.baseBitrate) * quality.bitrateMultiplier)
    }

    /// Valid frame rates for video recording
    static let validFrameRates = [15, 24, 30, 60]

    /// Check if the current frame rate is valid
    var isValidFrameRate: Bool {
        Self.validFrameRates.contains(frameRate)
    }
}
