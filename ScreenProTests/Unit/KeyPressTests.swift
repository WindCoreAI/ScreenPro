import XCTest
@testable import ScreenPro

/// Unit tests for KeyPress model (T074)
final class KeyPressTests: XCTestCase {

    // MARK: - Basic Initialization

    func testKeyPressInitialization() {
        let keyPress = KeyPress(key: "A", modifiers: [])

        XCTAssertEqual(keyPress.key, "A")
        XCTAssertTrue(keyPress.modifiers.isEmpty)
        XCTAssertNotNil(keyPress.id)
    }

    func testKeyPressWithModifiers() {
        let keyPress = KeyPress(key: "C", modifiers: [.command])

        XCTAssertEqual(keyPress.key, "C")
        XCTAssertEqual(keyPress.modifiers, [.command])
    }

    // MARK: - Display String Tests (T079)

    func testDisplayStringNoModifiers() {
        let keyPress = KeyPress(key: "A", modifiers: [])
        XCTAssertEqual(keyPress.displayString, "A")
    }

    func testDisplayStringWithCommand() {
        let keyPress = KeyPress(key: "C", modifiers: [.command])
        XCTAssertEqual(keyPress.displayString, "⌘C")
    }

    func testDisplayStringWithShift() {
        let keyPress = KeyPress(key: "S", modifiers: [.shift])
        XCTAssertEqual(keyPress.displayString, "⇧S")
    }

    func testDisplayStringWithOption() {
        let keyPress = KeyPress(key: "O", modifiers: [.option])
        XCTAssertEqual(keyPress.displayString, "⌥O")
    }

    func testDisplayStringWithControl() {
        let keyPress = KeyPress(key: "K", modifiers: [.control])
        XCTAssertEqual(keyPress.displayString, "⌃K")
    }

    func testDisplayStringWithMultipleModifiers() {
        let keyPress = KeyPress(key: "Z", modifiers: [.command, .shift])
        XCTAssertEqual(keyPress.displayString, "⌘⇧Z")
    }

    func testDisplayStringWithAllModifiers() {
        let keyPress = KeyPress(key: "A", modifiers: [.control, .option, .shift, .command])
        XCTAssertEqual(keyPress.displayString, "⌃⌥⇧⌘A")
    }

    // MARK: - Special Key Tests

    func testDisplayStringSpace() {
        let keyPress = KeyPress(key: " ", modifiers: [])
        XCTAssertEqual(keyPress.displayString, "Space")
    }

    func testDisplayStringReturn() {
        let keyPress = KeyPress(key: "\r", modifiers: [])
        XCTAssertEqual(keyPress.displayString, "↵")
    }

    func testDisplayStringTab() {
        let keyPress = KeyPress(key: "\t", modifiers: [])
        XCTAssertEqual(keyPress.displayString, "⇥")
    }

    func testDisplayStringEscape() {
        let keyPress = KeyPress(key: "\u{1B}", modifiers: [])
        XCTAssertEqual(keyPress.displayString, "Esc")
    }

    func testDisplayStringDelete() {
        let keyPress = KeyPress(key: "\u{7F}", modifiers: [])
        XCTAssertEqual(keyPress.displayString, "⌫")
    }

    // MARK: - Modifier Symbol Tests

    func testModifierSymbolCommand() {
        XCTAssertEqual(KeyPress.Modifier.command.symbol, "⌘")
    }

    func testModifierSymbolShift() {
        XCTAssertEqual(KeyPress.Modifier.shift.symbol, "⇧")
    }

    func testModifierSymbolOption() {
        XCTAssertEqual(KeyPress.Modifier.option.symbol, "⌥")
    }

    func testModifierSymbolControl() {
        XCTAssertEqual(KeyPress.Modifier.control.symbol, "⌃")
    }

    // MARK: - Identifiable Tests

    func testUniqueIDs() {
        let keyPress1 = KeyPress(key: "A", modifiers: [])
        let keyPress2 = KeyPress(key: "A", modifiers: [])

        XCTAssertNotEqual(keyPress1.id, keyPress2.id)
    }

    // MARK: - Fade Duration Tests

    func testFadeDuration() {
        XCTAssertEqual(KeyPress.fadeDuration, 2.0)
    }

    func testMaxQueueSize() {
        XCTAssertEqual(KeyPress.maxQueueSize, 5)
    }
}
