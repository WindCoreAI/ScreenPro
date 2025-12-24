import Foundation
import Carbon
import AppKit

// MARK: - Shortcut Action Enum (T008)

/// Actions that can be triggered by keyboard shortcuts
enum ShortcutAction: String, Codable, CaseIterable {
    case captureArea
    case captureWindow
    case captureFullscreen
    case captureScrolling
    case startRecording
    case recordGIF
    case textRecognition
    case selfTimer
    case screenFreeze
    case allInOne

    var displayName: String {
        switch self {
        case .captureArea: return "Capture Area"
        case .captureWindow: return "Capture Window"
        case .captureFullscreen: return "Capture Fullscreen"
        case .captureScrolling: return "Capture Scrolling"
        case .startRecording: return "Start Recording"
        case .recordGIF: return "Record GIF"
        case .textRecognition: return "Text Recognition (OCR)"
        case .selfTimer: return "Self-Timer Capture"
        case .screenFreeze: return "Screen Freeze"
        case .allInOne: return "All-in-One"
        }
    }
}

// MARK: - Shortcut Model (T008)

/// Represents a keyboard shortcut combination
struct Shortcut: Codable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32

    /// Computed display string showing modifier symbols
    var displayString: String {
        var result = ""

        // Control
        if modifiers & UInt32(controlKey) != 0 {
            result += "⌃"
        }
        // Option
        if modifiers & UInt32(optionKey) != 0 {
            result += "⌥"
        }
        // Shift
        if modifiers & UInt32(shiftKey) != 0 {
            result += "⇧"
        }
        // Command
        if modifiers & UInt32(cmdKey) != 0 {
            result += "⌘"
        }

        // Add key character
        result += keyCodeToString(keyCode)

        return result
    }

    // MARK: - Default Shortcuts

    /// Default keyboard shortcuts for all actions
    static var defaults: [ShortcutAction: Shortcut] {
        [
            .captureArea: Shortcut(keyCode: 0x15, modifiers: UInt32(cmdKey | shiftKey)),        // ⌘⇧4
            .captureFullscreen: Shortcut(keyCode: 0x14, modifiers: UInt32(cmdKey | shiftKey)),  // ⌘⇧3
            .allInOne: Shortcut(keyCode: 0x17, modifiers: UInt32(cmdKey | shiftKey)),           // ⌘⇧5
            .startRecording: Shortcut(keyCode: 0x16, modifiers: UInt32(cmdKey | shiftKey)),     // ⌘⇧6
            .captureScrolling: Shortcut(keyCode: 0x1A, modifiers: UInt32(cmdKey | shiftKey)),   // ⌘⇧7
            .textRecognition: Shortcut(keyCode: 0x1C, modifiers: UInt32(cmdKey | shiftKey)),    // ⌘⇧8
            .selfTimer: Shortcut(keyCode: 0x19, modifiers: UInt32(cmdKey | shiftKey)),          // ⌘⇧9
            .screenFreeze: Shortcut(keyCode: 0x1D, modifiers: UInt32(cmdKey | shiftKey)),       // ⌘⇧0
        ]
    }

    // MARK: - Key Code Conversion

    private func keyCodeToString(_ keyCode: UInt32) -> String {
        // Common key codes
        let keyMap: [UInt32: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
            0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=", 0x19: "9",
            0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
            0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P",
            0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K", 0x29: ";",
            0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2D: "N", 0x2E: "M",
            0x2F: ".", 0x32: "`",
            0x24: "↩", // Return
            0x30: "⇥", // Tab
            0x31: "␣", // Space
            0x33: "⌫", // Delete
            0x35: "⎋", // Escape
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
            0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        ]
        return keyMap[keyCode] ?? "?"
    }
}

// MARK: - ShortcutManager Protocol

protocol ShortcutManagerProtocol: ObservableObject {
    var shortcuts: [ShortcutAction: Shortcut] { get }
    func registerDefaults()
    func setActionHandler(_ handler: @escaping (ShortcutAction) -> Void)
    func registerAll()
    func register(_ shortcut: Shortcut, for action: ShortcutAction)
    func unregister(_ action: ShortcutAction)
    func unregisterAll()
    func detectConflict(for shortcut: Shortcut) -> String?
}

// MARK: - ShortcutManager Implementation (T038-T046 - placeholder for Phase 6)

final class ShortcutManager: ObservableObject, ShortcutManagerProtocol {
    // MARK: - Published Properties

    @Published private(set) var shortcuts: [ShortcutAction: Shortcut]

    // MARK: - Private Properties

    private var hotKeyRefs: [ShortcutAction: EventHotKeyRef?] = [:]
    private var actionHandler: ((ShortcutAction) -> Void)?
    private var nextHotKeyID: UInt32 = 1

    // Static map for callback to find manager instance
    // Using nonisolated(unsafe) as these are protected by Carbon event handling
    private nonisolated(unsafe) static var actionMap: [UInt32: ShortcutAction] = [:]
    private nonisolated(unsafe) static var sharedHandler: ((ShortcutAction) -> Void)?

    // MARK: - Initialization

    init(shortcuts: [ShortcutAction: Shortcut] = Shortcut.defaults) {
        self.shortcuts = shortcuts
        setupEventHandler()
    }

    deinit {
        unregisterAll()
    }

    // MARK: - Registration (T039, T040)

    func registerDefaults() {
        shortcuts = Shortcut.defaults
        registerAll()
    }

    func setActionHandler(_ handler: @escaping (ShortcutAction) -> Void) {
        self.actionHandler = handler
        Self.sharedHandler = handler
    }

    func registerAll() {
        for (action, shortcut) in shortcuts {
            register(shortcut, for: action)
        }
    }

    func register(_ shortcut: Shortcut, for action: ShortcutAction) {
        // Unregister existing if any
        unregister(action)

        // Create hot key ID
        let hotKeyID = EventHotKeyID(signature: OSType(0x5350524F), id: nextHotKeyID) // "SPRO"
        Self.actionMap[nextHotKeyID] = action
        nextHotKeyID += 1

        // Register the hot key
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            hotKeyRefs[action] = hotKeyRef
        } else {
            print("Failed to register shortcut for \(action): \(status)")
        }
    }

    func unregister(_ action: ShortcutAction) {
        guard let hotKeyRef = hotKeyRefs[action], let ref = hotKeyRef else { return }
        UnregisterEventHotKey(ref)
        hotKeyRefs[action] = nil
    }

    func unregisterAll() {
        for action in ShortcutAction.allCases {
            unregister(action)
        }
        Self.actionMap.removeAll()
    }

    // MARK: - Conflict Detection (T041)

    func detectConflict(for shortcut: Shortcut) -> String? {
        // Check for common system shortcuts that might conflict
        let cmdShift = UInt32(cmdKey | shiftKey)

        // macOS uses Cmd+Shift+3,4,5 by default for screenshots
        if shortcut.modifiers == cmdShift {
            switch shortcut.keyCode {
            case 0x14: // 3
                return "macOS Screenshot (Fullscreen)"
            case 0x15: // 4
                return "macOS Screenshot (Selection)"
            case 0x17: // 5
                return "macOS Screenshot (Options)"
            default:
                break
            }
        }

        return nil
    }

    // MARK: - Event Handler Setup

    private func setupEventHandler() {
        // Install Carbon event handler for hot key events
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                if status == noErr {
                    if let action = ShortcutManager.actionMap[hotKeyID.id] {
                        DispatchQueue.main.async {
                            ShortcutManager.sharedHandler?(action)
                        }
                    }
                }

                return noErr
            },
            1,
            &eventSpec,
            nil,
            nil
        )
    }
}
