import XCTest
@testable import ScreenPro

/// Unit tests for ClickEffect model (T065)
final class ClickEffectTests: XCTestCase {

    // MARK: - Model Tests

    func testClickEffectInitialization() {
        let point = CGPoint(x: 100, y: 200)
        let effect = ClickEffect(position: point, clickType: .left)

        XCTAssertEqual(effect.position, point)
        XCTAssertEqual(effect.clickType, .left)
        XCTAssertNotNil(effect.id)
    }

    func testClickEffectUniqueIDs() {
        let effect1 = ClickEffect(position: .zero, clickType: .left)
        let effect2 = ClickEffect(position: .zero, clickType: .left)

        XCTAssertNotEqual(effect1.id, effect2.id)
    }

    // MARK: - Click Type Tests

    func testLeftClickType() {
        let effect = ClickEffect(position: .zero, clickType: .left)
        XCTAssertEqual(effect.clickType, .left)
    }

    func testRightClickType() {
        let effect = ClickEffect(position: .zero, clickType: .right)
        XCTAssertEqual(effect.clickType, .right)
    }

    func testMiddleClickType() {
        let effect = ClickEffect(position: .zero, clickType: .middle)
        XCTAssertEqual(effect.clickType, .middle)
    }

    // MARK: - Color Tests

    func testLeftClickColor() {
        XCTAssertEqual(ClickEffect.ClickType.left.color.description, "blue")
    }

    func testRightClickColor() {
        XCTAssertEqual(ClickEffect.ClickType.right.color.description, "green")
    }

    func testMiddleClickColor() {
        XCTAssertEqual(ClickEffect.ClickType.middle.color.description, "orange")
    }

    // MARK: - Animation Duration Tests

    func testAnimationDuration() {
        XCTAssertEqual(ClickEffect.animationDuration, 0.5)
    }

    func testMaxRingRadius() {
        XCTAssertEqual(ClickEffect.maxRingRadius, 30.0)
    }

    // MARK: - Identifiable Tests

    func testIdentifiable() {
        let effect = ClickEffect(position: .zero, clickType: .left)
        let id = effect.id

        XCTAssertEqual(effect.id, id)
    }

    // MARK: - Equatable Tests

    func testEquatable() {
        let effect1 = ClickEffect(position: CGPoint(x: 10, y: 20), clickType: .left)
        let effect2 = ClickEffect(position: CGPoint(x: 10, y: 20), clickType: .left)

        // Different IDs mean they're not equal even with same position
        XCTAssertNotEqual(effect1, effect2)

        // Same instance should be equal to itself
        XCTAssertEqual(effect1, effect1)
    }
}
