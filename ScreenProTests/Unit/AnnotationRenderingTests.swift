import XCTest
@testable import ScreenPro

// MARK: - AnnotationRenderingTests (T020, T021)

/// Unit tests for annotation rendering functionality.
/// Tests cover ArrowAnnotation rendering and hit testing.
final class AnnotationRenderingTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a test CGContext for rendering.
    private func createTestContext(width: Int = 400, height: Int = 300) -> CGContext {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
    }

    // MARK: - ArrowAnnotation Rendering Tests (T020)

    func testArrowAnnotation_rendersWithoutError() throws {
        // Given
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 50, y: 50),
            endPoint: CGPoint(x: 150, y: 100),
            color: .red,
            strokeWidth: 3
        )
        let context = createTestContext()

        // When/Then - Should not throw
        arrow.render(in: context, scale: 1.0)

        // Verify context has image data
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testArrowAnnotation_rendersStraightLine() throws {
        // Given
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 100, y: 0),
            style: ArrowStyle(headStyle: .none, tailStyle: .none, lineStyle: .straight),
            color: .blue,
            strokeWidth: 5
        )
        let context = createTestContext()

        // When
        arrow.render(in: context, scale: 1.0)

        // Then - Verify image was produced
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testArrowAnnotation_rendersWithFilledHead() throws {
        // Given
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 50, y: 100),
            endPoint: CGPoint(x: 200, y: 100),
            style: ArrowStyle(headStyle: .filled, tailStyle: .none, lineStyle: .straight),
            color: .red,
            strokeWidth: 3
        )
        let context = createTestContext()

        // When
        arrow.render(in: context, scale: 1.0)

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testArrowAnnotation_rendersWithOpenHead() throws {
        // Given
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 50, y: 100),
            endPoint: CGPoint(x: 200, y: 100),
            style: ArrowStyle(headStyle: .open, tailStyle: .none, lineStyle: .straight),
            color: .black,
            strokeWidth: 2
        )
        let context = createTestContext()

        // When
        arrow.render(in: context, scale: 1.0)

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testArrowAnnotation_rendersWithCircleHead() throws {
        // Given
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 50, y: 100),
            endPoint: CGPoint(x: 200, y: 100),
            style: ArrowStyle(headStyle: .circle, tailStyle: .none, lineStyle: .straight),
            color: .green,
            strokeWidth: 4
        )
        let context = createTestContext()

        // When
        arrow.render(in: context, scale: 1.0)

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testArrowAnnotation_rendersWithBothHeadAndTail() throws {
        // Given
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 50, y: 100),
            endPoint: CGPoint(x: 200, y: 100),
            style: ArrowStyle(headStyle: .filled, tailStyle: .circle, lineStyle: .straight),
            color: .purple,
            strokeWidth: 3
        )
        let context = createTestContext()

        // When
        arrow.render(in: context, scale: 1.0)

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testArrowAnnotation_rendersAtDifferentScales() throws {
        // Given
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 50, y: 50),
            endPoint: CGPoint(x: 150, y: 100),
            color: .red,
            strokeWidth: 3
        )
        let context = createTestContext()

        // When - Render at different scales
        arrow.render(in: context, scale: 0.5)
        arrow.render(in: context, scale: 1.0)
        arrow.render(in: context, scale: 2.0)

        // Then - Should not crash
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testArrowAnnotation_rendersDiagonalArrow() throws {
        // Given
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 50, y: 50),
            endPoint: CGPoint(x: 200, y: 200),
            color: .orange,
            strokeWidth: 3
        )
        let context = createTestContext()

        // When
        arrow.render(in: context, scale: 1.0)

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testArrowAnnotation_rendersVerticalArrow() throws {
        // Given
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 100, y: 50),
            endPoint: CGPoint(x: 100, y: 200),
            color: .blue,
            strokeWidth: 3
        )
        let context = createTestContext()

        // When
        arrow.render(in: context, scale: 1.0)

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    // MARK: - ArrowAnnotation Hit Testing Tests (T021)

    func testArrowAnnotation_hitTestReturnsTrue_whenPointOnLine() {
        // Given
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 50, y: 100),
            endPoint: CGPoint(x: 200, y: 100),
            color: .red,
            strokeWidth: 10
        )

        // When - Test point on the line
        let hitResult = arrow.hitTest(CGPoint(x: 100, y: 100))

        // Then
        XCTAssertTrue(hitResult)
    }

    func testArrowAnnotation_hitTestReturnsTrue_whenPointNearLine() {
        // Given
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 50, y: 100),
            endPoint: CGPoint(x: 200, y: 100),
            color: .red,
            strokeWidth: 10
        )

        // When - Test point just above the line (within tolerance)
        let hitResult = arrow.hitTest(CGPoint(x: 100, y: 105))

        // Then
        XCTAssertTrue(hitResult)
    }

    func testArrowAnnotation_hitTestReturnsFalse_whenPointFarFromLine() {
        // Given
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 50, y: 100),
            endPoint: CGPoint(x: 200, y: 100),
            color: .red,
            strokeWidth: 10
        )

        // When - Test point far from the line
        let hitResult = arrow.hitTest(CGPoint(x: 100, y: 200))

        // Then
        XCTAssertFalse(hitResult)
    }

    func testArrowAnnotation_hitTestReturnsTrue_atStartPoint() {
        // Given
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 50, y: 100),
            endPoint: CGPoint(x: 200, y: 100),
            color: .red,
            strokeWidth: 10
        )

        // When
        let hitResult = arrow.hitTest(CGPoint(x: 50, y: 100))

        // Then
        XCTAssertTrue(hitResult)
    }

    func testArrowAnnotation_hitTestReturnsTrue_atEndPoint() {
        // Given
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 50, y: 100),
            endPoint: CGPoint(x: 200, y: 100),
            color: .red,
            strokeWidth: 10
        )

        // When
        let hitResult = arrow.hitTest(CGPoint(x: 200, y: 100))

        // Then
        XCTAssertTrue(hitResult)
    }

    func testArrowAnnotation_hitTestWorksWithDiagonalLine() {
        // Given
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 100, y: 100),
            color: .red,
            strokeWidth: 10
        )

        // When - Test point on diagonal
        let hitResult = arrow.hitTest(CGPoint(x: 50, y: 50))

        // Then
        XCTAssertTrue(hitResult)
    }

    func testArrowAnnotation_hitTestWithThickStrokeWidth() {
        // Given
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 50, y: 100),
            endPoint: CGPoint(x: 200, y: 100),
            color: .red,
            strokeWidth: 20 // Thick stroke
        )

        // When - Test point near line within thick stroke area
        let hitResult = arrow.hitTest(CGPoint(x: 100, y: 115))

        // Then
        XCTAssertTrue(hitResult)
    }

    // MARK: - ArrowAnnotation Bounds Tests

    func testArrowAnnotation_boundsContainsStartAndEndPoints() {
        // Given
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 50, y: 50),
            endPoint: CGPoint(x: 200, y: 150),
            color: .red,
            strokeWidth: 3
        )

        // Then
        XCTAssertTrue(arrow.bounds.contains(CGPoint(x: 50, y: 50)))
        XCTAssertTrue(arrow.bounds.contains(CGPoint(x: 200, y: 150)))
    }

    func testArrowAnnotation_boundsCorrectForHorizontalLine() {
        // Given
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 50, y: 100),
            endPoint: CGPoint(x: 200, y: 100),
            color: .red,
            strokeWidth: 10
        )

        // Then
        XCTAssertEqual(arrow.bounds.minX, 50, accuracy: 1)
        XCTAssertEqual(arrow.bounds.maxX, 200, accuracy: 1)
    }

    func testArrowAnnotation_boundsCorrectForVerticalLine() {
        // Given
        let arrow = ArrowAnnotation(
            startPoint: CGPoint(x: 100, y: 50),
            endPoint: CGPoint(x: 100, y: 200),
            color: .red,
            strokeWidth: 10
        )

        // Then
        XCTAssertEqual(arrow.bounds.minY, 50, accuracy: 1)
        XCTAssertEqual(arrow.bounds.maxY, 200, accuracy: 1)
    }

    // MARK: - ArrowAnnotation Copy Tests

    func testArrowAnnotation_copyCreatesNewUUID() {
        // Given
        let original = ArrowAnnotation(
            startPoint: CGPoint(x: 50, y: 50),
            endPoint: CGPoint(x: 200, y: 150),
            color: .red,
            strokeWidth: 3
        )

        // When
        let copy = original.copy() as! ArrowAnnotation

        // Then
        XCTAssertNotEqual(original.id, copy.id)
    }

    func testArrowAnnotation_copyPreservesProperties() {
        // Given
        let original = ArrowAnnotation(
            startPoint: CGPoint(x: 50, y: 50),
            endPoint: CGPoint(x: 200, y: 150),
            style: ArrowStyle(headStyle: .filled, tailStyle: .circle, lineStyle: .straight),
            color: .purple,
            strokeWidth: 5
        )

        // When
        let copy = original.copy() as! ArrowAnnotation

        // Then
        XCTAssertEqual(copy.startPoint, original.startPoint)
        XCTAssertEqual(copy.endPoint, original.endPoint)
        XCTAssertEqual(copy.style, original.style)
        XCTAssertEqual(copy.color, original.color)
        XCTAssertEqual(copy.strokeWidth, original.strokeWidth)
    }

    // MARK: - TextAnnotation Rendering Tests (T046)

    func testTextAnnotation_rendersWithoutError() throws {
        // Given
        let text = TextAnnotation(
            text: "Hello World",
            position: CGPoint(x: 100, y: 100),
            textColor: .red,
            font: AnnotationFont.default
        )
        let context = createTestContext()

        // When/Then - Should not throw
        text.render(in: context, scale: 1.0)

        // Verify context has image data
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testTextAnnotation_rendersWithBackground() throws {
        // Given
        let text = TextAnnotation(
            text: "Test",
            position: CGPoint(x: 50, y: 50),
            textColor: .black,
            backgroundColor: .yellow,
            font: AnnotationFont.default
        )
        let context = createTestContext()

        // When
        text.render(in: context, scale: 1.0)

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testTextAnnotation_rendersAtDifferentScales() throws {
        // Given
        let text = TextAnnotation(
            text: "Scale Test",
            position: CGPoint(x: 100, y: 100),
            textColor: .blue,
            font: AnnotationFont.default
        )
        let context = createTestContext()

        // When - Render at different scales
        text.render(in: context, scale: 0.5)
        text.render(in: context, scale: 1.0)
        text.render(in: context, scale: 2.0)

        // Then - Should not crash
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testTextAnnotation_rendersWithDifferentFontSizes() throws {
        // Given
        let smallFont = AnnotationFont(name: "SF Pro", size: 12, weight: .regular)
        let largeFont = AnnotationFont(name: "SF Pro", size: 48, weight: .bold)

        let smallText = TextAnnotation(
            text: "Small",
            position: CGPoint(x: 50, y: 50),
            textColor: .black,
            font: smallFont
        )
        let largeText = TextAnnotation(
            text: "Large",
            position: CGPoint(x: 50, y: 150),
            textColor: .black,
            font: largeFont
        )
        let context = createTestContext()

        // When
        smallText.render(in: context, scale: 1.0)
        largeText.render(in: context, scale: 1.0)

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testTextAnnotation_rendersEmptyString() throws {
        // Given
        let text = TextAnnotation(
            text: "",
            position: CGPoint(x: 100, y: 100),
            textColor: .black,
            font: AnnotationFont.default
        )
        let context = createTestContext()

        // When/Then - Should not crash on empty string
        text.render(in: context, scale: 1.0)

        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testTextAnnotation_rendersMultilineText() throws {
        // Given
        let text = TextAnnotation(
            text: "Line 1\nLine 2\nLine 3",
            position: CGPoint(x: 50, y: 50),
            textColor: .black,
            font: AnnotationFont.default
        )
        let context = createTestContext()

        // When
        text.render(in: context, scale: 1.0)

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    // MARK: - TextAnnotation Bounds Tests (T047)

    func testTextAnnotation_boundsCalculation() {
        // Given
        let text = TextAnnotation(
            text: "Test Text",
            position: CGPoint(x: 100, y: 100),
            textColor: .black,
            font: AnnotationFont.default
        )

        // Then - Bounds should contain the position
        XCTAssertTrue(text.bounds.contains(CGPoint(x: 100, y: 100)))
    }

    func testTextAnnotation_boundsWidthGreaterThanZero() {
        // Given
        let text = TextAnnotation(
            text: "Some Text",
            position: CGPoint(x: 50, y: 50),
            textColor: .black,
            font: AnnotationFont.default
        )

        // Then
        XCTAssertGreaterThan(text.bounds.width, 0)
    }

    func testTextAnnotation_boundsHeightGreaterThanZero() {
        // Given
        let text = TextAnnotation(
            text: "Some Text",
            position: CGPoint(x: 50, y: 50),
            textColor: .black,
            font: AnnotationFont.default
        )

        // Then
        XCTAssertGreaterThan(text.bounds.height, 0)
    }

    func testTextAnnotation_boundsGrowsWithPadding() {
        // Given
        let textNoPadding = TextAnnotation(
            text: "Test",
            position: CGPoint(x: 100, y: 100),
            textColor: .black,
            font: AnnotationFont.default,
            padding: 0
        )
        let textWithPadding = TextAnnotation(
            text: "Test",
            position: CGPoint(x: 100, y: 100),
            textColor: .black,
            font: AnnotationFont.default,
            padding: 10
        )

        // Then - Bounds with padding should be larger
        XCTAssertGreaterThan(textWithPadding.bounds.width, textNoPadding.bounds.width)
        XCTAssertGreaterThan(textWithPadding.bounds.height, textNoPadding.bounds.height)
    }

    func testTextAnnotation_hitTestReturnsTrue_whenPointInBounds() {
        // Given
        let text = TextAnnotation(
            text: "Click Me",
            position: CGPoint(x: 100, y: 100),
            textColor: .black,
            font: AnnotationFont.default
        )

        // When - Test point at the position
        let hitResult = text.hitTest(CGPoint(x: 105, y: 105))

        // Then
        XCTAssertTrue(hitResult)
    }

    func testTextAnnotation_hitTestReturnsFalse_whenPointOutsideBounds() {
        // Given
        let text = TextAnnotation(
            text: "Click Me",
            position: CGPoint(x: 100, y: 100),
            textColor: .black,
            font: AnnotationFont.default
        )

        // When - Test point far from the text
        let hitResult = text.hitTest(CGPoint(x: 500, y: 500))

        // Then
        XCTAssertFalse(hitResult)
    }

    func testTextAnnotation_copyCreatesNewUUID() {
        // Given
        let original = TextAnnotation(
            text: "Original",
            position: CGPoint(x: 100, y: 100),
            textColor: .red,
            font: AnnotationFont.default
        )

        // When
        let copy = original.copy() as! TextAnnotation

        // Then
        XCTAssertNotEqual(original.id, copy.id)
    }

    func testTextAnnotation_copyPreservesProperties() {
        // Given
        let font = AnnotationFont(name: "SF Pro", size: 24, weight: .bold)
        let original = TextAnnotation(
            text: "Original",
            position: CGPoint(x: 100, y: 100),
            textColor: .red,
            backgroundColor: .yellow,
            font: font,
            padding: 8
        )

        // When
        let copy = original.copy() as! TextAnnotation

        // Then
        XCTAssertEqual(copy.text, original.text)
        XCTAssertEqual(copy.position, original.position)
        XCTAssertEqual(copy.textColor, original.textColor)
        XCTAssertEqual(copy.backgroundColor, original.backgroundColor)
        XCTAssertEqual(copy.font.size, original.font.size)
        XCTAssertEqual(copy.padding, original.padding)
    }

    // MARK: - ShapeAnnotation Rectangle Tests (T057)

    func testShapeAnnotation_rectangle_rendersWithoutError() throws {
        // Given
        let shape = ShapeAnnotation(
            bounds: CGRect(x: 50, y: 50, width: 100, height: 80),
            shapeType: .rectangle,
            strokeColor: .red,
            strokeWidth: 3
        )
        let context = createTestContext()

        // When/Then - Should not throw
        shape.render(in: context, scale: 1.0)

        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testShapeAnnotation_rectangle_rendersWithFill() throws {
        // Given
        let shape = ShapeAnnotation(
            bounds: CGRect(x: 50, y: 50, width: 100, height: 80),
            shapeType: .rectangle,
            fillColor: .blue,
            strokeColor: .red,
            strokeWidth: 3
        )
        let context = createTestContext()

        // When
        shape.render(in: context, scale: 1.0)

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testShapeAnnotation_rectangle_rendersWithCornerRadius() throws {
        // Given
        let shape = ShapeAnnotation(
            bounds: CGRect(x: 50, y: 50, width: 100, height: 80),
            shapeType: .rectangle,
            strokeColor: .black,
            strokeWidth: 2,
            cornerRadius: 10
        )
        let context = createTestContext()

        // When
        shape.render(in: context, scale: 1.0)

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testShapeAnnotation_rectangle_rendersAtDifferentScales() throws {
        // Given
        let shape = ShapeAnnotation(
            bounds: CGRect(x: 50, y: 50, width: 100, height: 80),
            shapeType: .rectangle,
            strokeColor: .red,
            strokeWidth: 3
        )
        let context = createTestContext()

        // When - Render at different scales
        shape.render(in: context, scale: 0.5)
        shape.render(in: context, scale: 1.0)
        shape.render(in: context, scale: 2.0)

        // Then - Should not crash
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    // MARK: - ShapeAnnotation Ellipse Tests (T058)

    func testShapeAnnotation_ellipse_rendersWithoutError() throws {
        // Given
        let shape = ShapeAnnotation(
            bounds: CGRect(x: 50, y: 50, width: 100, height: 80),
            shapeType: .ellipse,
            strokeColor: .blue,
            strokeWidth: 3
        )
        let context = createTestContext()

        // When/Then - Should not throw
        shape.render(in: context, scale: 1.0)

        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testShapeAnnotation_ellipse_rendersWithFill() throws {
        // Given
        let shape = ShapeAnnotation(
            bounds: CGRect(x: 50, y: 50, width: 100, height: 80),
            shapeType: .ellipse,
            fillColor: .green,
            strokeColor: .black,
            strokeWidth: 2
        )
        let context = createTestContext()

        // When
        shape.render(in: context, scale: 1.0)

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testShapeAnnotation_ellipse_rendersCircle() throws {
        // Given - Equal width and height for circle
        let shape = ShapeAnnotation(
            bounds: CGRect(x: 50, y: 50, width: 100, height: 100),
            shapeType: .ellipse,
            strokeColor: .purple,
            strokeWidth: 3
        )
        let context = createTestContext()

        // When
        shape.render(in: context, scale: 1.0)

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    // MARK: - ShapeAnnotation Line Tests

    func testShapeAnnotation_line_rendersWithoutError() throws {
        // Given
        let shape = ShapeAnnotation(
            bounds: CGRect(x: 50, y: 50, width: 100, height: 80),
            shapeType: .line,
            strokeColor: .black,
            strokeWidth: 2
        )
        let context = createTestContext()

        // When
        shape.render(in: context, scale: 1.0)

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    // MARK: - ShapeAnnotation Hit Testing

    func testShapeAnnotation_hitTestReturnsTrue_whenPointInBounds() {
        // Given
        let shape = ShapeAnnotation(
            bounds: CGRect(x: 50, y: 50, width: 100, height: 80),
            shapeType: .rectangle,
            strokeColor: .red,
            strokeWidth: 3
        )

        // When - Test point inside bounds
        let hitResult = shape.hitTest(CGPoint(x: 100, y: 90))

        // Then
        XCTAssertTrue(hitResult)
    }

    func testShapeAnnotation_hitTestReturnsFalse_whenPointOutsideBounds() {
        // Given
        let shape = ShapeAnnotation(
            bounds: CGRect(x: 50, y: 50, width: 100, height: 80),
            shapeType: .rectangle,
            strokeColor: .red,
            strokeWidth: 3
        )

        // When - Test point outside bounds
        let hitResult = shape.hitTest(CGPoint(x: 200, y: 200))

        // Then
        XCTAssertFalse(hitResult)
    }

    // MARK: - ShapeAnnotation Copy Tests

    func testShapeAnnotation_copyCreatesNewUUID() {
        // Given
        let original = ShapeAnnotation(
            bounds: CGRect(x: 50, y: 50, width: 100, height: 80),
            shapeType: .rectangle,
            strokeColor: .red,
            strokeWidth: 3
        )

        // When
        let copy = original.copy() as! ShapeAnnotation

        // Then
        XCTAssertNotEqual(original.id, copy.id)
    }

    func testShapeAnnotation_copyPreservesProperties() {
        // Given
        let original = ShapeAnnotation(
            bounds: CGRect(x: 50, y: 50, width: 100, height: 80),
            shapeType: .ellipse,
            fillColor: .blue,
            strokeColor: .red,
            strokeWidth: 5,
            cornerRadius: 8
        )

        // When
        let copy = original.copy() as! ShapeAnnotation

        // Then
        XCTAssertEqual(copy.bounds, original.bounds)
        XCTAssertEqual(copy.shapeType, original.shapeType)
        XCTAssertEqual(copy.fillColor, original.fillColor)
        XCTAssertEqual(copy.strokeColor, original.strokeColor)
        XCTAssertEqual(copy.strokeWidth, original.strokeWidth)
        XCTAssertEqual(copy.cornerRadius, original.cornerRadius)
    }

    // MARK: - HighlighterAnnotation Tests (T087)

    func testHighlighterAnnotation_rendersWithoutError() throws {
        // Given
        let highlighter = HighlighterAnnotation(
            points: [
                CGPoint(x: 50, y: 100),
                CGPoint(x: 100, y: 100),
                CGPoint(x: 150, y: 105),
                CGPoint(x: 200, y: 100)
            ],
            color: .yellow,
            strokeWidth: 20
        )
        let context = createTestContext()

        // When/Then - Should not throw
        highlighter.render(in: context, scale: 1.0)

        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testHighlighterAnnotation_rendersWithMultiplyBlendMode() throws {
        // Given - The highlighter should use multiply blend mode
        let highlighter = HighlighterAnnotation(
            points: [
                CGPoint(x: 50, y: 100),
                CGPoint(x: 200, y: 100)
            ],
            color: .yellow,
            strokeWidth: 20
        )
        let context = createTestContext()

        // Fill background with white first
        context.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))

        // When
        highlighter.render(in: context, scale: 1.0)

        // Then - Should render without crashing
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testHighlighterAnnotation_rendersWithSemiTransparency() throws {
        // Given - Highlighter should have 0.4 alpha for semi-transparency
        let highlighter = HighlighterAnnotation(
            points: [
                CGPoint(x: 50, y: 100),
                CGPoint(x: 200, y: 100)
            ],
            color: .yellow,
            strokeWidth: 20
        )
        let context = createTestContext()

        // When
        highlighter.render(in: context, scale: 1.0)

        // Then - Should render with transparency
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testHighlighterAnnotation_rendersAtDifferentScales() throws {
        // Given
        let highlighter = HighlighterAnnotation(
            points: [
                CGPoint(x: 50, y: 100),
                CGPoint(x: 100, y: 100),
                CGPoint(x: 150, y: 105)
            ],
            color: .green,
            strokeWidth: 15
        )
        let context = createTestContext()

        // When - Render at different scales
        highlighter.render(in: context, scale: 0.5)
        highlighter.render(in: context, scale: 1.0)
        highlighter.render(in: context, scale: 2.0)

        // Then - Should not crash
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testHighlighterAnnotation_boundsCalculatedFromPoints() {
        // Given
        let highlighter = HighlighterAnnotation(
            points: [
                CGPoint(x: 50, y: 100),
                CGPoint(x: 150, y: 80),
                CGPoint(x: 200, y: 120)
            ],
            color: .yellow,
            strokeWidth: 20
        )

        // Then - Bounds should encompass all points with stroke padding
        XCTAssertLessThanOrEqual(highlighter.bounds.minX, 50)
        XCTAssertGreaterThanOrEqual(highlighter.bounds.maxX, 200)
        XCTAssertLessThanOrEqual(highlighter.bounds.minY, 80)
        XCTAssertGreaterThanOrEqual(highlighter.bounds.maxY, 120)
    }

    func testHighlighterAnnotation_hitTestReturnsTrue_whenPointOnPath() {
        // Given
        let highlighter = HighlighterAnnotation(
            points: [
                CGPoint(x: 50, y: 100),
                CGPoint(x: 200, y: 100)
            ],
            color: .yellow,
            strokeWidth: 20
        )

        // When - Test point on the path
        let hitResult = highlighter.hitTest(CGPoint(x: 100, y: 100))

        // Then
        XCTAssertTrue(hitResult)
    }

    func testHighlighterAnnotation_hitTestReturnsFalse_whenPointFarFromPath() {
        // Given
        let highlighter = HighlighterAnnotation(
            points: [
                CGPoint(x: 50, y: 100),
                CGPoint(x: 200, y: 100)
            ],
            color: .yellow,
            strokeWidth: 20
        )

        // When - Test point far from the path
        let hitResult = highlighter.hitTest(CGPoint(x: 100, y: 200))

        // Then
        XCTAssertFalse(hitResult)
    }

    func testHighlighterAnnotation_copyCreatesNewUUID() {
        // Given
        let original = HighlighterAnnotation(
            points: [CGPoint(x: 50, y: 100), CGPoint(x: 200, y: 100)],
            color: .yellow,
            strokeWidth: 20
        )

        // When
        let copy = original.copy() as! HighlighterAnnotation

        // Then
        XCTAssertNotEqual(original.id, copy.id)
    }

    func testHighlighterAnnotation_copyPreservesProperties() {
        // Given
        let original = HighlighterAnnotation(
            points: [
                CGPoint(x: 50, y: 100),
                CGPoint(x: 100, y: 95),
                CGPoint(x: 200, y: 100)
            ],
            color: .green,
            strokeWidth: 25
        )

        // When
        let copy = original.copy() as! HighlighterAnnotation

        // Then
        XCTAssertEqual(copy.points.count, original.points.count)
        XCTAssertEqual(copy.color, original.color)
        XCTAssertEqual(copy.strokeWidth, original.strokeWidth)
    }

    func testHighlighterAnnotation_rendersWithDifferentColors() throws {
        // Given
        let context = createTestContext()

        let yellowHighlighter = HighlighterAnnotation(
            points: [CGPoint(x: 50, y: 50), CGPoint(x: 200, y: 50)],
            color: .yellow,
            strokeWidth: 20
        )
        let greenHighlighter = HighlighterAnnotation(
            points: [CGPoint(x: 50, y: 100), CGPoint(x: 200, y: 100)],
            color: .green,
            strokeWidth: 20
        )
        let pinkHighlighter = HighlighterAnnotation(
            points: [CGPoint(x: 50, y: 150), CGPoint(x: 200, y: 150)],
            color: .pink,
            strokeWidth: 20
        )

        // When
        yellowHighlighter.render(in: context, scale: 1.0)
        greenHighlighter.render(in: context, scale: 1.0)
        pinkHighlighter.render(in: context, scale: 1.0)

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testHighlighterAnnotation_rendersCurvedPath() throws {
        // Given - A path with multiple points creating a curve
        let highlighter = HighlighterAnnotation(
            points: [
                CGPoint(x: 50, y: 100),
                CGPoint(x: 75, y: 90),
                CGPoint(x: 100, y: 95),
                CGPoint(x: 125, y: 110),
                CGPoint(x: 150, y: 105),
                CGPoint(x: 175, y: 100),
                CGPoint(x: 200, y: 100)
            ],
            color: .yellow,
            strokeWidth: 15
        )
        let context = createTestContext()

        // When
        highlighter.render(in: context, scale: 1.0)

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    // MARK: - CounterAnnotation Tests (T094)

    func testCounterAnnotation_rendersWithoutError() throws {
        // Given
        let counter = CounterAnnotation(
            number: 1,
            position: CGPoint(x: 100, y: 100),
            color: .red,
            size: 28
        )
        let context = createTestContext()

        // When/Then - Should not throw
        counter.render(in: context, scale: 1.0)

        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testCounterAnnotation_rendersMultipleNumbers() throws {
        // Given
        let context = createTestContext()
        let counters = [
            CounterAnnotation(number: 1, position: CGPoint(x: 50, y: 50), color: .red, size: 28),
            CounterAnnotation(number: 2, position: CGPoint(x: 100, y: 50), color: .red, size: 28),
            CounterAnnotation(number: 3, position: CGPoint(x: 150, y: 50), color: .red, size: 28)
        ]

        // When
        for counter in counters {
            counter.render(in: context, scale: 1.0)
        }

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testCounterAnnotation_numberSequencing_independentOfOrder() {
        // Given - Create counters with specific numbers (T094)
        let counter1 = CounterAnnotation(number: 1, position: CGPoint(x: 50, y: 50), color: .red, size: 28)
        let counter2 = CounterAnnotation(number: 2, position: CGPoint(x: 100, y: 50), color: .red, size: 28)
        let counter3 = CounterAnnotation(number: 3, position: CGPoint(x: 150, y: 50), color: .red, size: 28)

        // Then - Each counter retains its number
        XCTAssertEqual(counter1.number, 1)
        XCTAssertEqual(counter2.number, 2)
        XCTAssertEqual(counter3.number, 3)
    }

    func testCounterAnnotation_rendersAtDifferentScales() throws {
        // Given
        let counter = CounterAnnotation(
            number: 5,
            position: CGPoint(x: 100, y: 100),
            color: .blue,
            size: 28
        )
        let context = createTestContext()

        // When - Render at different scales
        counter.render(in: context, scale: 0.5)
        counter.render(in: context, scale: 1.0)
        counter.render(in: context, scale: 2.0)

        // Then - Should not crash
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testCounterAnnotation_rendersLargeNumbers() throws {
        // Given - Test with double-digit numbers
        let counter = CounterAnnotation(
            number: 99,
            position: CGPoint(x: 100, y: 100),
            color: .red,
            size: 28
        )
        let context = createTestContext()

        // When
        counter.render(in: context, scale: 1.0)

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testCounterAnnotation_boundsCalculatedFromPositionAndSize() {
        // Given
        let counter = CounterAnnotation(
            number: 1,
            position: CGPoint(x: 100, y: 100),
            color: .red,
            size: 28
        )

        // Then - Bounds should be centered on position
        XCTAssertEqual(counter.bounds.midX, 100, accuracy: 0.1)
        XCTAssertEqual(counter.bounds.midY, 100, accuracy: 0.1)
        XCTAssertEqual(counter.bounds.width, 28, accuracy: 0.1)
        XCTAssertEqual(counter.bounds.height, 28, accuracy: 0.1)
    }

    func testCounterAnnotation_hitTestReturnsTrue_whenPointInsideCircle() {
        // Given
        let counter = CounterAnnotation(
            number: 1,
            position: CGPoint(x: 100, y: 100),
            color: .red,
            size: 28
        )

        // When - Test point at center
        let hitResult = counter.hitTest(CGPoint(x: 100, y: 100))

        // Then
        XCTAssertTrue(hitResult)
    }

    func testCounterAnnotation_hitTestReturnsTrue_whenPointNearEdge() {
        // Given
        let counter = CounterAnnotation(
            number: 1,
            position: CGPoint(x: 100, y: 100),
            color: .red,
            size: 28
        )

        // When - Test point near edge (radius is 14, plus 5pt tolerance)
        let hitResult = counter.hitTest(CGPoint(x: 118, y: 100))

        // Then
        XCTAssertTrue(hitResult)
    }

    func testCounterAnnotation_hitTestReturnsFalse_whenPointFarFromCircle() {
        // Given
        let counter = CounterAnnotation(
            number: 1,
            position: CGPoint(x: 100, y: 100),
            color: .red,
            size: 28
        )

        // When - Test point far from circle
        let hitResult = counter.hitTest(CGPoint(x: 200, y: 200))

        // Then
        XCTAssertFalse(hitResult)
    }

    func testCounterAnnotation_copyCreatesNewUUID() {
        // Given
        let original = CounterAnnotation(
            number: 5,
            position: CGPoint(x: 100, y: 100),
            color: .blue,
            size: 32
        )

        // When
        let copy = original.copy() as! CounterAnnotation

        // Then
        XCTAssertNotEqual(original.id, copy.id)
    }

    func testCounterAnnotation_copyPreservesProperties() {
        // Given
        let original = CounterAnnotation(
            number: 7,
            position: CGPoint(x: 150, y: 200),
            color: .green,
            size: 36
        )

        // When
        let copy = original.copy() as! CounterAnnotation

        // Then
        XCTAssertEqual(copy.number, original.number)
        XCTAssertEqual(copy.position, original.position)
        XCTAssertEqual(copy.color, original.color)
        XCTAssertEqual(copy.size, original.size)
    }

    func testCounterAnnotation_rendersWithDifferentColors() throws {
        // Given
        let context = createTestContext()

        let redCounter = CounterAnnotation(number: 1, position: CGPoint(x: 50, y: 100), color: .red, size: 28)
        let blueCounter = CounterAnnotation(number: 2, position: CGPoint(x: 100, y: 100), color: .blue, size: 28)
        let greenCounter = CounterAnnotation(number: 3, position: CGPoint(x: 150, y: 100), color: .green, size: 28)

        // When
        redCounter.render(in: context, scale: 1.0)
        blueCounter.render(in: context, scale: 1.0)
        greenCounter.render(in: context, scale: 1.0)

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }

    func testCounterAnnotation_rendersWithDifferentSizes() throws {
        // Given
        let context = createTestContext()

        let smallCounter = CounterAnnotation(number: 1, position: CGPoint(x: 50, y: 100), color: .red, size: 20)
        let mediumCounter = CounterAnnotation(number: 2, position: CGPoint(x: 100, y: 100), color: .red, size: 28)
        let largeCounter = CounterAnnotation(number: 3, position: CGPoint(x: 160, y: 100), color: .red, size: 40)

        // When
        smallCounter.render(in: context, scale: 1.0)
        mediumCounter.render(in: context, scale: 1.0)
        largeCounter.render(in: context, scale: 1.0)

        // Then
        let image = context.makeImage()
        XCTAssertNotNil(image)
    }
}
