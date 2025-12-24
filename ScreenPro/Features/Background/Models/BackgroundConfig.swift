import SwiftUI

// MARK: - BackgroundConfig (T062)

/// Configuration for the background tool settings.
struct BackgroundConfig {
    /// The background style.
    var style: BackgroundStyle

    /// Primary color for solid/gradient.
    var primaryColor: Color

    /// Secondary color for gradient.
    var secondaryColor: Color

    /// Gradient preset.
    var gradientPreset: GradientPreset

    /// Aspect ratio preset.
    var aspectRatio: AspectRatioPreset

    /// Padding around the screenshot.
    var padding: CGFloat

    /// Corner radius for the screenshot.
    var cornerRadius: CGFloat

    /// Shadow radius (0 = no shadow).
    var shadowRadius: CGFloat

    /// Shadow opacity (0-1).
    var shadowOpacity: Double

    /// Export scale factor.
    var exportScale: CGFloat

    /// Creates a background configuration.
    init(
        style: BackgroundStyle = .gradient,
        primaryColor: Color = .blue,
        secondaryColor: Color = .purple,
        gradientPreset: GradientPreset = .ocean,
        aspectRatio: AspectRatioPreset = .twitter,
        padding: CGFloat = 60,
        cornerRadius: CGFloat = 16,
        shadowRadius: CGFloat = 30,
        shadowOpacity: Double = 0.3,
        exportScale: CGFloat = 2.0
    ) {
        self.style = style
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.gradientPreset = gradientPreset
        self.aspectRatio = aspectRatio
        self.padding = max(0, min(200, padding))
        self.cornerRadius = max(0, min(50, cornerRadius))
        self.shadowRadius = max(0, min(100, shadowRadius))
        self.shadowOpacity = max(0, min(1, shadowOpacity))
        self.exportScale = max(1, min(3, exportScale))
    }

    /// Default configuration.
    static var `default`: BackgroundConfig {
        BackgroundConfig()
    }

    /// The gradient to use based on current settings.
    var gradient: LinearGradient {
        let colors = gradientPreset == .custom
            ? [primaryColor, secondaryColor]
            : gradientPreset.colors
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
