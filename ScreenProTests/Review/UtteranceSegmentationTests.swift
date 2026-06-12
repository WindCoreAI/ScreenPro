import XCTest
@testable import ScreenPro

// MARK: - UtteranceSegmentationTests (008-review-recording, T027)
//
// Drives the pure segmenter with injected partial-result events and a test
// clock — no Speech framework involvement (research.md R2, R10).

final class UtteranceSegmentationTests: XCTestCase {
    private func makeSegmenter() -> UtteranceSegmenter {
        UtteranceSegmenter(silenceThreshold: 1.2, minimumLength: 2, startLatencyCompensation: 0.5)
    }

    func testUtteranceClosesAfterSilenceThreshold() {
        var segmenter = makeSegmenter()
        segmenter.partial(text: "this button", at: 10.0)
        segmenter.partial(text: "this button is misaligned", at: 11.0)

        // Below threshold: still open.
        XCTAssertNil(segmenter.tick(now: 12.0))

        // Above threshold: closes with full text.
        let utterance = segmenter.tick(now: 12.3)
        XCTAssertNotNil(utterance)
        XCTAssertEqual(utterance?.text, "this button is misaligned")
        XCTAssertEqual(utterance?.end, 11.0)
    }

    func testUtteranceStartUsesLatencyCompensation() {
        var segmenter = makeSegmenter()
        segmenter.partial(text: "hello there", at: 5.0)
        let utterance = segmenter.tick(now: 7.0)
        XCTAssertEqual(utterance?.start, 4.5) // 5.0 − 0.5 compensation
    }

    func testUtteranceStartClampsToZero() {
        var segmenter = makeSegmenter()
        segmenter.partial(text: "immediate speech", at: 0.2)
        let utterance = segmenter.tick(now: 2.0)
        XCTAssertEqual(utterance?.start, 0)
    }

    func testSilenceProducesNothing() {
        var segmenter = makeSegmenter()
        XCTAssertNil(segmenter.tick(now: 10.0))
        XCTAssertNil(segmenter.tick(now: 100.0))
        XCTAssertNil(segmenter.flush())
    }

    func testEmptyAndWhitespaceTextDiscarded() {
        var segmenter = makeSegmenter()
        segmenter.partial(text: "   ", at: 1.0)
        XCTAssertNil(segmenter.tick(now: 3.0))

        segmenter.partial(text: "a", at: 5.0) // below minimumLength
        XCTAssertNil(segmenter.tick(now: 7.0))
    }

    func testFlushReturnsOpenUtterance() {
        var segmenter = makeSegmenter()
        segmenter.partial(text: "needs better empty state copy", at: 20.0)
        let utterance = segmenter.flush()
        XCTAssertEqual(utterance?.text, "needs better empty state copy")
    }

    func testSegmenterResetsBetweenUtterances() {
        var segmenter = makeSegmenter()
        segmenter.partial(text: "first observation", at: 1.0)
        XCTAssertNotNil(segmenter.tick(now: 3.0))

        // After close, a quiet segmenter yields nothing until new partials.
        XCTAssertNil(segmenter.tick(now: 10.0))

        segmenter.partial(text: "second observation", at: 11.0)
        let second = segmenter.tick(now: 13.0)
        XCTAssertEqual(second?.text, "second observation")
        XCTAssertEqual(second?.start, 10.5)
    }

    /// SC-006: a scripted sequence of distinct observations separated by
    /// silence produces exactly one utterance each.
    func testScriptedTenObservationsProduceTenUtterances() {
        var segmenter = makeSegmenter()
        var closed: [Utterance] = []

        for index in 0..<10 {
            let base = TimeInterval(index) * 10.0
            segmenter.partial(text: "observation \(index) part one", at: base + 0.5)
            segmenter.partial(text: "observation \(index) part one and two", at: base + 1.5)
            // Silence until next observation; tick at +3.0 (gap 1.5 > 1.2).
            if let utterance = segmenter.tick(now: base + 3.0) {
                closed.append(utterance)
            }
        }

        XCTAssertEqual(closed.count, 10)
        XCTAssertEqual(Set(closed.map(\.text)).count, 10, "each observation segments separately")
    }
}
