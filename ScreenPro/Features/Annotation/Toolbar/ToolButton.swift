import SwiftUI

// MARK: - ToolButton (T012)

/// A button for selecting an annotation tool in the toolbar.
/// Displays an SF Symbol icon with selection state and accessibility support.
struct ToolButton: View {
    let tool: AnnotationTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: tool.icon)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .frame(width: 28, height: 28)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.borderless)
        .help(toolTip)
        .accessibilityLabel(tool.accessibilityLabel)
        .accessibilityHint(tool.accessibilityHint)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var toolTip: String {
        if let shortcut = tool.shortcut {
            return "\(tool.rawValue) (\(shortcut.uppercased()))"
        }
        return tool.rawValue
    }
}

// MARK: - Preview

#if DEBUG
struct ToolButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 4) {
            ToolButton(tool: .select, isSelected: false, action: {})
            ToolButton(tool: .arrow, isSelected: true, action: {})
            ToolButton(tool: .rectangle, isSelected: false, action: {})
            ToolButton(tool: .text, isSelected: false, action: {})
            ToolButton(tool: .blur, isSelected: false, action: {})
        }
        .padding()
    }
}
#endif
