import Foundation
import CoreGraphics
import AppKit

// MARK: - AnnotationColor (T002)

/// Color representation with preset values and CGColor/NSColor conversion.
/// Used throughout the annotation system for consistent color handling.
struct AnnotationColor: Codable, Hashable, Sendable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    // MARK: - Initialization

    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(nsColor: NSColor) {
        let converted = nsColor.usingColorSpace(.sRGB) ?? nsColor
        self.red = converted.redComponent
        self.green = converted.greenComponent
        self.blue = converted.blueComponent
        self.alpha = converted.alphaComponent
    }

    // MARK: - Preset Colors

    static let red = AnnotationColor(red: 1, green: 0.23, blue: 0.19, alpha: 1)
    static let orange = AnnotationColor(red: 1, green: 0.58, blue: 0, alpha: 1)
    static let yellow = AnnotationColor(red: 1, green: 0.8, blue: 0, alpha: 1)
    static let green = AnnotationColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1)
    static let blue = AnnotationColor(red: 0, green: 0.48, blue: 1, alpha: 1)
    static let purple = AnnotationColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1)
    static let pink = AnnotationColor(red: 1, green: 0.18, blue: 0.33, alpha: 1)
    static let black = AnnotationColor(red: 0, green: 0, blue: 0, alpha: 1)
    static let white = AnnotationColor(red: 1, green: 1, blue: 1, alpha: 1)

    /// All preset colors for the color picker
    static let presets: [AnnotationColor] = [
        .red, .orange, .yellow, .green, .blue, .purple, .black, .white
    ]

    // MARK: - Color Conversions

    var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Returns a copy with the specified alpha value
    func withAlpha(_ newAlpha: CGFloat) -> AnnotationColor {
        AnnotationColor(red: red, green: green, blue: blue, alpha: newAlpha)
    }
}

// MARK: - SwiftUI Color Extension

import SwiftUI

extension AnnotationColor {
    var color: Color {
        Color(nsColor: nsColor)
    }
}
