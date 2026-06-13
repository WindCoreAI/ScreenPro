import XCTest
@testable import ScreenPro

// MARK: - ReviewMergeTests (008-review-recording, T027 / FR-007)
//
// A spoken observation overlapping a manual flag merges into that flag
// instead of duplicating; merges work in both arrival orders.

@MainActor
final class ReviewMergeTests: XCTestCase {
    func testUtteranceOverlappingManualFlagMergesIntoIt() async {
        let (session, frames) = makeTestSession()
        await session.start(voiceNotesEnabled: false, transcriptionLocale: "", frameProvider: frames)

        let flag = session.flagCurrentMoment()!
        let t = flag.timestamp

        // Utterance spanning the flag moment closes shortly after.
        session.ingestUtterance(Utterance(start: max(0, t - 1.0), end: t + 1.0, text: "this button is misaligned"))

        XCTAssertEqual(session.issues.count, 1, "no duplicate issue (FR-007)")
        XCTAssertEqual(session.issues[0].source, .manual)
        XCTAssertEqual(session.issues[0].transcript, "this button is misaligned")

        // The narration still appears in the full transcript.
        let output = await session.finish()
        XCTAssertEqual(output.transcript.count, 1)
    }

    func testUtteranceOutsideMergeWindowCreatesSeparateIssue() async {
        let (session, frames) = makeTestSession()
        await session.start(voiceNotesEnabled: false, transcriptionLocale: "", frameProvider: frames)

        let flag = session.flagCurrentMoment()!
        let farStart = flag.timestamp + ReviewSessionService.mergeWindow + 5.0

        session.ingestUtterance(Utterance(start: farStart, end: farStart + 1.5, text: "empty state needs better copy"))

        XCTAssertEqual(session.issues.count, 2)
        XCTAssertEqual(session.issues.filter { $0.source == .voice }.count, 1)
        XCTAssertEqual(session.issues.first { $0.source == .voice }?.transcript, "empty state needs better copy")

        _ = await session.finish()
    }

    func testFlagAbsorbsJustClosedVoiceIssue() async {
        let (session, frames) = makeTestSession()
        await session.start(voiceNotesEnabled: false, transcriptionLocale: "", frameProvider: frames)

        // Voice issue lands first; the reviewer flags right after speaking.
        let now = session.clock.now
        session.ingestUtterance(Utterance(start: now, end: now + 0.5, text: "spacing looks off"))
        XCTAssertEqual(session.issues.count, 1)

        let flag = session.flagCurrentMoment()
        XCTAssertEqual(session.issues.count, 1, "flag absorbs the overlapping voice issue")
        XCTAssertEqual(flag?.source, .manual)
        XCTAssertEqual(flag?.transcript, "spacing looks off")

        _ = await session.finish()
    }

    func testMergeOnlyTargetsFlagsWithoutTranscript() async {
        let (session, frames) = makeTestSession()
        await session.start(voiceNotesEnabled: false, transcriptionLocale: "", frameProvider: frames)

        let flag = session.flagCurrentMoment()!
        let t = flag.timestamp
        session.ingestUtterance(Utterance(start: max(0, t - 0.5), end: t + 0.5, text: "first remark"))
        session.ingestUtterance(Utterance(start: t + 0.6, end: t + 1.4, text: "second remark"))

        // First merged into the flag; second becomes its own voice issue.
        XCTAssertEqual(session.issues.count, 2)
        XCTAssertEqual(session.issues.first { $0.source == .manual }?.transcript, "first remark")
        XCTAssertEqual(session.issues.first { $0.source == .voice }?.transcript, "second remark")

        _ = await session.finish()
    }

    func testUtteranceWhileInactiveIsIgnored() async {
        let (session, _) = makeTestSession()
        session.ingestUtterance(Utterance(start: 1, end: 2, text: "should be dropped"))
        XCTAssertTrue(session.issues.isEmpty)
    }

    func testVoiceIssueUsesUtteranceStartFrame() async {
        let (session, frames) = makeTestSession()
        await session.start(voiceNotesEnabled: false, transcriptionLocale: "", frameProvider: frames)

        session.ingestUtterance(Utterance(start: 0.1, end: 1.8, text: "modal overlaps the toolbar"))

        XCTAssertEqual(frames.nearestRequests, [0.1], "screenshot resolves to the utterance start (FR-006)")
        XCTAssertEqual(session.issues.first?.timestamp ?? -1, 0.1, accuracy: 0.001)

        _ = await session.finish()
    }
}
