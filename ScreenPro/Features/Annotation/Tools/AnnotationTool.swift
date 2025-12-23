import Foundation
import AppKit

// MARK: - AnnotationTool (T003)

/// Available annotation tools with their icons and keyboard shortcuts.
enum AnnotationTool: String, CaseIterable, Sendable {
    case select = "Select"
    case arrow = "Arrow"
    case rectangle = "Rectangle"
    case ellipse = "Ellipse"
    case line = "Line"
    case text = "Text"
    case blur = "Blur"
    case pixelate = "Pixelate"
    case highlighter = "Highlighter"
    case counter = "Counter"
    case crop = "Crop"

    /// SF Symbol name for the tool icon.
    var icon: String {
        switch self {
        case .select: return "arrow.up.left.and.arrow.down.right"
        case .arrow: return "arrow.right"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .line: return "line.diagonal"
        case .text: return "textformat"
        case .blur: return "drop.fill"
        case .pixelate: return "square.grid.3x3"
        case .highlighter: return "highlighter"
        case .counter: return "number.circle"
        case .crop: return "crop"
        }
    }

    /// Keyboard shortcut character (single key).
    var shortcut: Character? {
        switch self {
        case .select: return "v"
        case .arrow: return "a"
        case .rectangle: return "r"
        case .ellipse: return "o"
        case .line: return "l"
        case .text: return "t"
        case .blur: return "b"
        case .pixelate: return "p"
        case .highlighter: return "h"
        case .counter: return "n"
        case .crop: return "c"
        }
    }

    /// Accessibility label for VoiceOver.
    var accessibilityLabel: String {
        "\(rawValue) tool"
    }

    /// Accessibility hint including keyboard shortcut.
    var accessibilityHint: String {
        if let shortcut = shortcut {
            return "Press \(shortcut.uppercased()) to select"
        }
        return ""
    }

    /// Whether this tool creates annotations by dragging.
    var usesDragGesture: Bool {
        switch self {
        case .select, .text, .counter:
            return false
        case .arrow, .rectangle, .ellipse, .line, .blur, .pixelate, .highlighter, .crop:
            return true
        }
    }

    /// Whether this tool creates annotations by clicking.
    var usesClickGesture: Bool {
        switch self {
        case .text, .counter:
            return true
        case .select:
            return true // For selection
        default:
            return false
        }
    }

    /// The primary tools shown in the main toolbar section.
    static var primaryTools: [AnnotationTool] {
        [.select, .arrow, .rectangle, .ellipse, .line, .text]
    }

    /// The privacy/redaction tools.
    static var privacyTools: [AnnotationTool] {
        [.blur, .pixelate]
    }

    /// Additional annotation tools.
    static var additionalTools: [AnnotationTool] {
        [.highlighter, .counter, .crop]
    }
}

// MARK: - Font Weight (T003)

/// Font weights for text annotations.
enum AnnotationFontWeight: String, Codable, CaseIterable, Sendable {
    case regular
    case medium
    case semibold
    case bold

    var nsFontWeight: NSFont.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - AnnotationFont (T003)

/// Font configuration for text annotations.
struct AnnotationFont: Codable, Equatable, Sendable {
    var name: String
    var size: CGFloat
    var weight: AnnotationFontWeight

    static let `default` = AnnotationFont(
        name: "SF Pro",
        size: 16,
        weight: .regular
    )

    var nsFont: NSFont {
        NSFont.systemFont(ofSize: size, weight: weight.nsFontWeight)
    }

    /// Available font sizes for the picker.
    static let availableSizes: [CGFloat] = [12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 64]
}

// MARK: - ToolConfiguration (T004)

/// Current tool settings shared across annotation creation.
/// Observable for SwiftUI binding.
@MainActor
final class ToolConfiguration: ObservableObject {
    @Published var selectedTool: AnnotationTool = .arrow
    @Published var color: AnnotationColor = .red
    @Published var strokeWidth: CGFloat = 3
    @Published var fillEnabled: Bool = false
    @Published var fillColor: AnnotationColor = .red
    @Published var blurIntensity: CGFloat = 0.5
    @Published var fontSize: CGFloat = 16
    @Published var fontWeight: AnnotationFontWeight = .regular

    /// Available stroke widths for the picker.
    static let availableStrokeWidths: [CGFloat] = [1, 2, 3, 4, 6, 8, 10]

    /// Reset to default values.
    func reset() {
        selectedTool = .arrow
        color = .red
        strokeWidth = 3
        fillEnabled = false
        fillColor = .red
        blurIntensity = 0.5
        fontSize = 16
        fontWeight = .regular
    }

    /// Creates an AnnotationFont from current settings.
    var currentFont: AnnotationFont {
        AnnotationFont(name: "SF Pro", size: fontSize, weight: fontWeight)
    }
}
