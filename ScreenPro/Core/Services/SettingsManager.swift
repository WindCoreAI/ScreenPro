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

    // MARK: - Default Values

    static var defaultPicturesDirectory: URL {
        let picturesPath = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        return picturesPath.appendingPathComponent("ScreenPro", isDirectory: true)
    }

    static var `default`: Settings { Settings() }
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
