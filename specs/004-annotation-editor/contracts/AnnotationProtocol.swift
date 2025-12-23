// MARK: - Annotation Protocol
// Contract: specs/004-annotation-editor/contracts/AnnotationProtocol.swift
// Feature: 004-annotation-editor
//
// This file defines the protocol contract for all annotation types.
// Implementation files should conform to these protocols exactly.

import Foundation
import CoreGraphics
import AppKit

// MARK: - Annotation Protocol

/// Base protocol that all annotation types must conform to.
/// Provides common properties and behaviors for canvas rendering and manipulation.
protocol Annotation: Identifiable, Codable {
    /// Unique identifier for this annotation.
    var id: UUID { get }

    /// Bounding rectangle in canvas coordinates.
    var bounds: CGRect { get set }

    /// Transformation matrix for rotation/scaling.
    var transform: CGAffineTransform { get set }

    /// Layer order (higher = rendered on top).
    var zIndex: Int { get set }

    /// Whether this annotation is currently selected.
    var isSelected: Bool { get set }

    /// Renders the annotation to the given graphics context.
    /// - Parameters:
    ///   - context: The Core Graphics context to draw into.
    ///   - scale: The current zoom level for proper stroke scaling.
    func render(in context: CGContext, scale: CGFloat)

    /// Tests whether a point intersects with this annotation.
    /// - Parameter point: Point in canvas coordinates.
    /// - Returns: True if the point is within the annotation bounds.
    func hitTest(_ point: CGPoint) -> Bool

    /// Creates a deep copy of this annotation with a new UUID.
    /// - Returns: A copy of this annotation.
    func copy() -> any Annotation
}

extension Annotation {
    /// Bounds after applying the transform.
    var transformedBounds: CGRect {
        bounds.applying(transform)
    }

    /// Default hit test implementation using transformed bounds with padding.
    func hitTest(_ point: CGPoint) -> Bool {
        transformedBounds.insetBy(dx: -5, dy: -5).contains(point)
    }
}

// MARK: - Arrow Style

/// Configuration for arrow head and line styles.
struct ArrowStyle: Codable, Equatable {
    var headStyle: HeadStyle = .filled
    var tailStyle: HeadStyle = .none
    var lineStyle: LineStyle = .straight

    enum HeadStyle: String, Codable {
        case none
        case open
        case filled
        case circle
    }

    enum LineStyle: String, Codable {
        case straight
        case curved
    }
}

// MARK: - Shape Type

/// Types of geometric shapes that can be drawn.
enum ShapeType: String, Codable {
    case rectangle
    case ellipse
    case line
}

// MARK: - Blur Type

/// Types of blur effects for privacy masking.
enum BlurType: String, Codable {
    case gaussian
    case pixelate
}

// MARK: - Font Weight

/// Font weights for text annotations.
enum AnnotationFontWeight: String, Codable {
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
}

// MARK: - Annotation Font

/// Font configuration for text annotations.
struct AnnotationFont: Codable, Equatable {
    var name: String = "SF Pro"
    var size: CGFloat = 16
    var weight: AnnotationFontWeight = .regular

    var nsFont: NSFont {
        NSFont.systemFont(ofSize: size, weight: weight.nsFontWeight)
    }
}

// MARK: - Annotation Color

/// Color representation with preset values.
struct AnnotationColor: Codable, Hashable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    // MARK: - Preset Colors

    static let red = AnnotationColor(red: 1, green: 0.23, blue: 0.19, alpha: 1)
    static let orange = AnnotationColor(red: 1, green: 0.58, blue: 0, alpha: 1)
    static let yellow = AnnotationColor(red: 1, green: 0.8, blue: 0, alpha: 1)
    static let green = AnnotationColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1)
    static let blue = AnnotationColor(red: 0, green: 0.48, blue: 1, alpha: 1)
    static let purple = AnnotationColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1)
    static let black = AnnotationColor(red: 0, green: 0, blue: 0, alpha: 1)
    static let white = AnnotationColor(red: 1, green: 1, blue: 1, alpha: 1)

    // MARK: - Color Conversions

    var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

// MARK: - Annotation Tool

/// Available annotation tools.
enum AnnotationTool: String, CaseIterable {
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

    /// Keyboard shortcut letter (single key).
    var shortcut: String? {
        switch self {
        case .select: return "V"
        case .arrow: return "A"
        case .rectangle: return "R"
        case .ellipse: return "O"
        case .line: return "L"
        case .text: return "T"
        case .blur: return "B"
        case .pixelate: return "P"
        case .highlighter: return "H"
        case .counter: return "N"
        case .crop: return "C"
        }
    }
}

// MARK: - Tool Configuration

/// Current tool settings for annotation creation.
struct ToolConfiguration {
    var color: AnnotationColor = .red
    var strokeWidth: CGFloat = 3
    var fillEnabled: Bool = false
    var blurIntensity: CGFloat = 0.5
    var fontSize: CGFloat = 16
    var fontWeight: AnnotationFontWeight = .regular
}
