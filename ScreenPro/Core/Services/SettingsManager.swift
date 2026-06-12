import Foundation
import SwiftUI

// MARK: - Supporting Enums (T007)

/// Image format options for screenshots
enum ImageFormat: String, Codable, CaseIterable {
    case png
    case jpeg
    case tiff
    case heic

    var fileExtension: String { rawValue }

    var displayName: String {
        switch self {
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        case .tiff: return "TIFF"
        case .heic: return "HEIC"
        }
    }
}

/// Video format options for recordings
enum VideoFormat: String, Codable, CaseIterable {
    case mp4
    case mov

    var fileExtension: String { rawValue }

    var displayName: String {
        switch self {
        case .mp4: return "MP4"
        case .mov: return "MOV"
        }
    }
}

/// Video quality options for recordings
enum VideoQuality: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case maximum

    var displayName: String {
        switch self {
        case .low: return "Low (480p)"
        case .medium: return "Medium (720p)"
        case .high: return "High (1080p)"
        case .maximum: return "Maximum (4K)"
        }
    }
}

/// Position options for Quick Access overlay
enum QuickAccessPosition: String, Codable, CaseIterable {
    case bottomLeft
    case bottomRight
    case topLeft
    case topRight

    var displayName: String {
        switch self {
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        }
    }
}

// MARK: - Advanced Features Enums (006-advanced-features)
// Note: BackgroundStyle, OverlayPosition, OverlayShape are defined in their respective model files
// under Features/Background/Models and Features/Recording/CameraOverlay/Models

/// Type of capture for filename generation
enum CaptureType {
    case screenshot
    case video
    case gif
}

// MARK: - Settings Model (T006)

/// Root model containing all user-configurable preferences
struct Settings: Codable, Equatable {
    // MARK: - General Settings
    var launchAtLogin: Bool = false
    var showMenuBarIcon: Bool = true
    var playCaptureSound: Bool = true
    var showNotifications: Bool = true
    var copyToClipboardAfterCapture: Bool = true

    // MARK: - Capture Settings
    var defaultSaveLocation: URL = Settings.defaultPicturesDirectory
    var fileNamingPattern: String = "Screenshot {date} at {time}"
    var defaultImageFormat: ImageFormat = .png
    var includeCursor: Bool = false
    var showCrosshair: Bool = true
    var showMagnifier: Bool = false
    var hideDesktopIcons: Bool = false

    // MARK: - Recording Settings
    var defaultVideoFormat: VideoFormat = .mp4
    var videoQuality: VideoQuality = .high
    var videoFPS: Int = 30
    var recordMicrophone: Bool = false
    var recordSystemAudio: Bool = false
    var showClicks: Bool = false
    var showKeystrokes: Bool = false

    // MARK: - Quick Access Settings
    var showQuickAccess: Bool = true
    var quickAccessPosition: QuickAccessPosition = .bottomLeft
    var autoDismissDelay: TimeInterval = 0

    // MARK: - Shortcuts (stored separately but part of settings)
    var shortcuts: [ShortcutAction: Shortcut] = Shortcut.defaults

    // MARK: - Advanced Features Settings (006-advanced-features)

    // Scrolling Capture (T007)
    var scrollingCaptureMaxFrames: Int = 50
    var scrollingCaptureOverlapRatio: Double = 0.2

    // OCR Text Recognition (T008)
    var ocrLanguages: [String] = ["en-US", "zh-Hans", "zh-Hant", "ja", "ko"]
    var ocrCopyToClipboardAutomatically: Bool = true

    // Self-Timer (T009)
    var selfTimerDefaultDuration: Int = 5

    // Magnifier (T010)
    var magnifierEnabled: Bool = true
    var magnifierZoomLevel: Int = 8

    // Background Tool (T011)
    var defaultBackgroundStyle: BackgroundStyle = .gradient
    var defaultBackgroundPadding: Double = 40.0

    // Camera Overlay (T012)
    var cameraOverlayEnabled: Bool = false
    var cameraOverlayPosition: OverlayPosition = .bottomRight
    var cameraOverlayShape: OverlayShape = .circle
    var cameraOverlaySize: Double = 150.0

    // MARK: - Cloud & Sharing Settings (007-cloud-polish)
    var cloudUploadEnabled: Bool = false
    var cloudServerURL: String = "https://api.screenpro.cloud"
    var cloudAPIKey: String = ""
    var cloudDefaultExpiry: LinkExpiry = .never
    var copyLinkAfterUpload: Bool = true

    // MARK: - Capture History Settings (007-cloud-polish)
    var captureHistoryEnabled: Bool = true
    /// Days of history to retain; 0 retains forever.
    var historyRetentionDays: Int = 30

    // MARK: - Onboarding (007-cloud-polish)
    var hasCompletedOnboarding: Bool = false

    // MARK: - Default Values

    static var defaultPicturesDirectory: URL {
        let picturesPath = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        return picturesPath.appendingPathComponent("ScreenPro", isDirectory: true)
    }

    static var `default`: Settings { Settings() }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case launchAtLogin, showMenuBarIcon, playCaptureSound, showNotifications
        case copyToClipboardAfterCapture
        case defaultSaveLocation, fileNamingPattern, defaultImageFormat
        case includeCursor, showCrosshair, showMagnifier, hideDesktopIcons
        case defaultVideoFormat, videoQuality, videoFPS
        case recordMicrophone, recordSystemAudio, showClicks, showKeystrokes
        case showQuickAccess, quickAccessPosition, autoDismissDelay
        case shortcuts
        case scrollingCaptureMaxFrames, scrollingCaptureOverlapRatio
        case ocrLanguages, ocrCopyToClipboardAutomatically
        case selfTimerDefaultDuration
        case magnifierEnabled, magnifierZoomLevel
        case defaultBackgroundStyle, defaultBackgroundPadding
        case cameraOverlayEnabled, cameraOverlayPosition, cameraOverlayShape, cameraOverlaySize
        case cloudUploadEnabled, cloudServerURL, cloudAPIKey, cloudDefaultExpiry, copyLinkAfterUpload
        case captureHistoryEnabled, historyRetentionDays
        case hasCompletedOnboarding
    }
}

// MARK: - Tolerant Decoding (007-cloud-polish)

/// Custom decoding that falls back to defaults for missing keys, so settings
/// saved by an older app version survive upgrades instead of being reset.
/// (Synthesized decoding throws on any missing key, which previously caused
/// `SettingsManager.load()` to discard all user preferences after an update.)
extension Settings {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var settings = Settings()

        func decode<T: Decodable>(_ type: T.Type, _ key: CodingKeys, into value: inout T) {
            if let decoded = try? container.decodeIfPresent(type, forKey: key) {
                value = decoded
            }
        }

        decode(Bool.self, .launchAtLogin, into: &settings.launchAtLogin)
        decode(Bool.self, .showMenuBarIcon, into: &settings.showMenuBarIcon)
        decode(Bool.self, .playCaptureSound, into: &settings.playCaptureSound)
        decode(Bool.self, .showNotifications, into: &settings.showNotifications)
        decode(Bool.self, .copyToClipboardAfterCapture, into: &settings.copyToClipboardAfterCapture)

        decode(URL.self, .defaultSaveLocation, into: &settings.defaultSaveLocation)
        decode(String.self, .fileNamingPattern, into: &settings.fileNamingPattern)
        decode(ImageFormat.self, .defaultImageFormat, into: &settings.defaultImageFormat)
        decode(Bool.self, .includeCursor, into: &settings.includeCursor)
        decode(Bool.self, .showCrosshair, into: &settings.showCrosshair)
        decode(Bool.self, .showMagnifier, into: &settings.showMagnifier)
        decode(Bool.self, .hideDesktopIcons, into: &settings.hideDesktopIcons)

        decode(VideoFormat.self, .defaultVideoFormat, into: &settings.defaultVideoFormat)
        decode(VideoQuality.self, .videoQuality, into: &settings.videoQuality)
        decode(Int.self, .videoFPS, into: &settings.videoFPS)
        decode(Bool.self, .recordMicrophone, into: &settings.recordMicrophone)
        decode(Bool.self, .recordSystemAudio, into: &settings.recordSystemAudio)
        decode(Bool.self, .showClicks, into: &settings.showClicks)
        decode(Bool.self, .showKeystrokes, into: &settings.showKeystrokes)

        decode(Bool.self, .showQuickAccess, into: &settings.showQuickAccess)
        decode(QuickAccessPosition.self, .quickAccessPosition, into: &settings.quickAccessPosition)
        decode(TimeInterval.self, .autoDismissDelay, into: &settings.autoDismissDelay)

        decode([ShortcutAction: Shortcut].self, .shortcuts, into: &settings.shortcuts)

        decode(Int.self, .scrollingCaptureMaxFrames, into: &settings.scrollingCaptureMaxFrames)
        decode(Double.self, .scrollingCaptureOverlapRatio, into: &settings.scrollingCaptureOverlapRatio)
        decode([String].self, .ocrLanguages, into: &settings.ocrLanguages)
        decode(Bool.self, .ocrCopyToClipboardAutomatically, into: &settings.ocrCopyToClipboardAutomatically)
        decode(Int.self, .selfTimerDefaultDuration, into: &settings.selfTimerDefaultDuration)
        decode(Bool.self, .magnifierEnabled, into: &settings.magnifierEnabled)
        decode(Int.self, .magnifierZoomLevel, into: &settings.magnifierZoomLevel)
        decode(BackgroundStyle.self, .defaultBackgroundStyle, into: &settings.defaultBackgroundStyle)
        decode(Double.self, .defaultBackgroundPadding, into: &settings.defaultBackgroundPadding)
        decode(Bool.self, .cameraOverlayEnabled, into: &settings.cameraOverlayEnabled)
        decode(OverlayPosition.self, .cameraOverlayPosition, into: &settings.cameraOverlayPosition)
        decode(OverlayShape.self, .cameraOverlayShape, into: &settings.cameraOverlayShape)
        decode(Double.self, .cameraOverlaySize, into: &settings.cameraOverlaySize)

        decode(Bool.self, .cloudUploadEnabled, into: &settings.cloudUploadEnabled)
        decode(String.self, .cloudServerURL, into: &settings.cloudServerURL)
        decode(String.self, .cloudAPIKey, into: &settings.cloudAPIKey)
        decode(LinkExpiry.self, .cloudDefaultExpiry, into: &settings.cloudDefaultExpiry)
        decode(Bool.self, .copyLinkAfterUpload, into: &settings.copyLinkAfterUpload)

        decode(Bool.self, .captureHistoryEnabled, into: &settings.captureHistoryEnabled)
        decode(Int.self, .historyRetentionDays, into: &settings.historyRetentionDays)

        decode(Bool.self, .hasCompletedOnboarding, into: &settings.hasCompletedOnboarding)

        self = settings
    }
}

// MARK: - SettingsManager Protocol

@MainActor
protocol SettingsManagerProtocol: ObservableObject {
    var settings: Settings { get set }
    func save()
    func reset()
    func generateFilename(for type: CaptureType) -> String
}

// MARK: - SettingsManager Implementation (T029, T030 - placeholder for Phase 5)

@MainActor
final class SettingsManager: ObservableObject, SettingsManagerProtocol {
    // MARK: - Published Properties

    @Published var settings: Settings

    // MARK: - Private Properties

    private let userDefaultsKey = "ScreenProSettings"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Initialization

    init() {
        self.settings = Self.load() ?? Settings.default
        ensureSaveDirectoryExists()
    }

    // MARK: - Directory Management (T058)

    /// Ensures the default save directory exists
    private func ensureSaveDirectoryExists() {
        let saveLocation = settings.defaultSaveLocation
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: saveLocation.path) {
            do {
                try fileManager.createDirectory(at: saveLocation, withIntermediateDirectories: true)
            } catch {
                print("Failed to create save directory at \(saveLocation.path): \(error)")
            }
        }
    }

    // MARK: - Persistence (T029)

    func save() {
        do {
            let data = try encoder.encode(settings)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }

    func reset() {
        settings = Settings.default
        save()
    }

    private static func load() -> Settings? {
        guard let data = UserDefaults.standard.data(forKey: "ScreenProSettings") else {
            return nil
        }
        do {
            return try JSONDecoder().decode(Settings.self, from: data)
        } catch {
            print("Failed to load settings: \(error)")
            return nil
        }
    }

    // MARK: - Filename Generation (T030)

    func generateFilename(for type: CaptureType) -> String {
        let now = Date()
        let dateFormatter = DateFormatter()

        // Generate date string
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: now)

        // Generate time string
        dateFormatter.dateFormat = "HH.mm.ss"
        let timeString = dateFormatter.string(from: now)

        // Replace placeholders in pattern
        var filename = settings.fileNamingPattern
            .replacingOccurrences(of: "{date}", with: dateString)
            .replacingOccurrences(of: "{time}", with: timeString)

        // Add extension based on type
        let ext: String
        switch type {
        case .screenshot:
            ext = settings.defaultImageFormat.fileExtension
        case .video:
            ext = settings.defaultVideoFormat.fileExtension
        case .gif:
            ext = "gif"
        }

        filename += ".\(ext)"
        return filename
    }
}
