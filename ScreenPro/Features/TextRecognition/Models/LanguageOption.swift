import Foundation

// MARK: - LanguageOption (T033)

/// Supported recognition languages for OCR.
enum LanguageOption: String, Codable, CaseIterable, Identifiable {
    case english = "en-US"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    case german = "de-DE"
    case french = "fr-FR"
    case spanish = "es-ES"
    case portuguese = "pt-BR"
    case italian = "it-IT"

    var id: String { rawValue }

    /// Display name for the language.
    var displayName: String {
        switch self {
        case .english: return "English"
        case .chineseSimplified: return "Chinese (Simplified)"
        case .chineseTraditional: return "Chinese (Traditional)"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .german: return "German"
        case .french: return "French"
        case .spanish: return "Spanish"
        case .portuguese: return "Portuguese"
        case .italian: return "Italian"
        }
    }

    /// The Vision framework language identifier.
    var visionIdentifier: String {
        rawValue
    }

    /// Default languages for OCR.
    static var defaults: [LanguageOption] {
        [.english, .chineseSimplified, .chineseTraditional, .japanese, .korean]
    }
}
