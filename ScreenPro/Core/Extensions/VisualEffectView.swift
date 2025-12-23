import SwiftUI
import AppKit

// MARK: - VisualEffectView

/// SwiftUI wrapper for NSVisualEffectView providing macOS blur effects.
struct VisualEffectView: NSViewRepresentable {
    // MARK: - Properties

    /// The material appearance of the visual effect.
    let material: NSVisualEffectView.Material

    /// How the effect blends with content behind the window.
    let blendingMode: NSVisualEffectView.BlendingMode

    /// The visual effect state (active, inactive, or follows window).
    let state: NSVisualEffectView.State

    /// Whether to emphasize the material.
    let isEmphasized: Bool

    // MARK: - Initialization

    /// Creates a visual effect view with the specified appearance.
    /// - Parameters:
    ///   - material: The material appearance. Defaults to `.hudWindow`.
    ///   - blendingMode: The blending mode. Defaults to `.behindWindow`.
    ///   - state: The effect state. Defaults to `.active`.
    ///   - isEmphasized: Whether to emphasize the material. Defaults to `false`.
    init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active,
        isEmphasized: Bool = false
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
        self.isEmphasized = isEmphasized
    }

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = isEmphasized
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
        nsView.isEmphasized = isEmphasized
    }
}

// MARK: - Convenience Initializers

extension VisualEffectView {
    /// Creates a HUD-style visual effect view (dark semi-transparent).
    static var hudWindow: VisualEffectView {
        VisualEffectView(material: .hudWindow)
    }

    /// Creates a popover-style visual effect view.
    static var popover: VisualEffectView {
        VisualEffectView(material: .popover)
    }

    /// Creates a sidebar-style visual effect view.
    static var sidebar: VisualEffectView {
        VisualEffectView(material: .sidebar)
    }

    /// Creates a menu-style visual effect view.
    static var menu: VisualEffectView {
        VisualEffectView(material: .menu)
    }

    /// Creates a tooltip-style visual effect view.
    static var tooltip: VisualEffectView {
        VisualEffectView(material: .toolTip)
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Applies a visual effect background to the view.
    /// - Parameters:
    ///   - material: The material appearance.
    ///   - blendingMode: The blending mode.
    /// - Returns: A view with the visual effect applied as background.
    func visualEffectBackground(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) -> some View {
        self.background(
            VisualEffectView(material: material, blendingMode: blendingMode)
        )
    }
}
