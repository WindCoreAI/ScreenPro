import Foundation
import SwiftUI

// MARK: - KeyPress (T075)

/// Represents a keyboard press event for visualization during recording
struct KeyPress: Identifiable, Equatable, Sendable {
    /// Unique identifier for the key press
    let id: UUID

    /// The key character or name
    let key: String

    /// Active modifier keys
    let modifiers: Set<Modifier>

    /// Timestamp when the key was pressed
    let timestamp: Date

    /// Initialize a new key press
    init(
        id: UUID = UUID(),
        key: String,
        modifiers: Set<Modifier>,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.key = key
        self.modifiers = modifiers
        self.timestamp = timestamp
    }

    // MARK: - Display Constants

    /// Duration before key press fades out (T080)
    static let fadeDuration: TimeInterval = 2.0

    /// Maximum number of keystrokes to show at once (T080)
    static let maxQueueSize: Int = 5

    // MARK: - Display String (T079)

    /// Returns the formatted display string with modifier symbols
    var displayString: String {
        var result = ""

        // Add modifiers in standard order: ⌃⌥⇧⌘ (T079)
        if modifiers.contains(.control) {
            result += Modifier.control.symbol
        }
        if modifiers.contains(.option) {
            result += Modifier.option.symbol
        }
        if modifiers.contains(.shift) {
            result += Modifier.shift.symbol
        }
        if modifiers.contains(.command) {
            result += Modifier.command.symbol
        }

        // Add the key (with special handling for certain keys)
        result += formattedKey

        return result
    }

    /// Returns the formatted key name for special keys
    private var formattedKey: String {
        switch key {
        case " ":
            return "Space"
        case "\r", "\n":
            return "↵"
        case "\t":
            return "⇥"
        case "\u{1B}":
            return "Esc"
        case "\u{7F}":
            return "⌫"
        case "\u{F700}":
            return "↑"
        case "\u{F701}":
            return "↓"
        case "\u{F702}":
            return "←"
        case "\u{F703}":
            return "→"
        default:
            return key
        }
    }
}

// MARK: - Modifier

extension KeyPress {
    /// Keyboard modifier keys
    enum Modifier: String, CaseIterable, Sendable {
        case command
        case shift
        case option
        case control

        /// Symbol for the modifier (T079)
        var symbol: String {
            switch self {
            case .command:
                return "⌘"
            case .shift:
                return "⇧"
            case .option:
                return "⌥"
            case .control:
                return "⌃"
            }
        }
    }
}
