import XCTest
import CoreGraphics
@testable import ScreenPro

// MARK: - Shared test stubs (008-review-recording, research.md R10)

/// Frame provider stub: returns a deterministic tiny CGImage so flag and
/// voice paths can run without ScreenCaptureKit.
final class StubFrameProvider: ReviewFrameProviding, @unchecked Sendable {
    var image: CGImage?
    private(set) var nearestRequests: [TimeInterval] = []

    init(image: CGImage? = StubFrameProvider.makeImage()) {
        self.image = image
    }

    func latestFrame() -> CGImage? { image }

    func frame(nearest time: TimeInterval) -> CGImage? {
        nearestRequests.append(time)
        return image
    }

    static func makeImage(width: Int = 4, height: Int = 4) -> CGImage? {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context?.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context?.makeImage()
    }
}

@MainActor
func makeTestSession() -> (ReviewSessionService, StubFrameProvider) {
    let service = ReviewSessionService(
        permissionManager: PermissionManager(),
        microphoneAudioHub: MicrophoneAudioHub()
    )
    return (service, StubFrameProvider())
}

// MARK: - ReviewSessionLifecycleTests (T018, T030)

@MainActor
final class ReviewSessionLifecycleTests: XCTestCase {
    func testFlagCreatesIssueWithTimestampAndScreenshot() async throws {
        let (session, frames) = makeTestSession()
        await session.start(voiceNotesEnabled: false, transcriptionLocale: "", frameProvider: frames)
        XCTAssertEqual(session.phase, .active)

        let issue = session.flagCurrentMoment()
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.source, .manual)
        XCTAssertGreaterThanOrEqual(issue!.timestamp, 0)

        let output = await session.finish()
        XCTAssertEqual(output.issues.count, 1)

        // The screenshot write was awaited by finish() — the file must exist
        // (covers the "flag just before stop" edge case).
        let screenshotURL = output.tempDirectory.appendingPathComponent(output.issues[0].screenshotFilename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: screenshotURL.path))

        try? FileManager.default.removeItem(at: output.tempDirectory)
    }

    func testFlagsRejectedWhileSuspended() async {
        let (session, frames) = makeTestSession()
        await session.start(voiceNotesEnabled: false, transcriptionLocale: "", frameProvider: frames)

        session.suspend()
        XCTAssertEqual(session.phase, .suspended)
        XCTAssertNil(session.flagCurrentMoment(), "flags must be rejected while paused (FR-017)")

        session.resume()
        XCTAssertEqual(session.phase, .active)
        XCTAssertNotNil(session.flagCurrentMoment())

        _ = await session.finish()
    }

    func testRapidDoubleFlagYieldsTwoDistinctIssues() async {
        let (session, frames) = makeTestSession()
        await session.start(voiceNotesEnabled: false, transcriptionLocale: "", frameProvider: frames)

        let first = session.flagCurrentMoment()
        let second = session.flagCurrentMoment()

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertNotEqual(first?.id, second?.id)
        XCTAssertNotEqual(first?.screenshotFilename, second?.screenshotFilename)
        XCTAssertEqual(session.issues.count, 2)

        _ = await session.finish()
    }

    func testCancelRemovesTempDirectoryAndState() async {
        let (session, frames) = makeTestSession()
        await session.start(voiceNotesEnabled: false, transcriptionLocale: "", frameProvider: frames)

        session.flagCurrentMoment()
        let tempDir = session.currentOutput().tempDirectory

        session.cancel()
        XCTAssertEqual(session.phase, .inactive)
        XCTAssertTrue(session.issues.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.path), "cancel must leave no trace (FR-016)")
    }

    func testNoFrameMeansNoIssue() async {
        let (session, frames) = makeTestSession()
        frames.image = nil
        await session.start(voiceNotesEnabled: false, transcriptionLocale: "", frameProvider: frames)

        XCTAssertNil(session.flagCurrentMoment())
        XCTAssertTrue(session.issues.isEmpty)

        _ = await session.finish()
    }

    func testSummaryEditsSurfaceInOutput() async {
        let (session, frames) = makeTestSession()
        await session.start(voiceNotesEnabled: false, transcriptionLocale: "", frameProvider: frames)

        let a = session.flagCurrentMoment()!
        let b = session.flagCurrentMoment()!
        let c = session.flagCurrentMoment()!
        _ = await session.finish()

        // Summary-step edits happen after finish(), before currentOutput().
        session.setNote("keep this one", for: a.id)
        session.setTranscript("corrected transcript", for: b.id)
        session.deleteIssue(c.id)

        let output = session.currentOutput()
        XCTAssertEqual(output.issues.count, 2)
        XCTAssertEqual(output.issues.first { $0.id == a.id }?.note, "keep this one")
        XCTAssertEqual(output.issues.first { $0.id == b.id }?.transcript, "corrected transcript")

        try? FileManager.default.removeItem(at: output.tempDirectory)
    }

    func testDeletingAllIssuesYieldsEmptyOutput() async {
        let (session, frames) = makeTestSession()
        await session.start(voiceNotesEnabled: false, transcriptionLocale: "", frameProvider: frames)
        let issue = session.flagCurrentMoment()!
        _ = await session.finish()

        session.deleteIssue(issue.id)
        XCTAssertTrue(session.currentOutput().isEmpty, "routes to the zero-issue path (FR-013)")

        session.cleanupAfterExport()
    }
}
