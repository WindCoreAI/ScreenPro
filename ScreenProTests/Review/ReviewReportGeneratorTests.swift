import XCTest
@testable import ScreenPro

// MARK: - ReviewReportGeneratorTests (008-review-recording, T022, T034)
//
// Pure file tests: session output in a temp dir → bundle in a temp dir.
// Manifest assertions encode the constraints of
// specs/008-review-recording/contracts/review-manifest.schema.json
// (no third-party JSON-schema validator — Constitution: no external deps).

final class ReviewReportGeneratorTests: XCTestCase {
    private var workDir: URL!
    private var sessionDir: URL!
    private var saveDir: URL!
    private var videoURL: URL!

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReviewReportGeneratorTests-\(UUID().uuidString)", isDirectory: true)
        sessionDir = workDir.appendingPathComponent("session", isDirectory: true)
        saveDir = workDir.appendingPathComponent("save", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)

        videoURL = workDir.appendingPathComponent("recording-original.mp4")
        try Data("fake video".utf8).write(to: videoURL)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDir)
    }

    // MARK: - Fixtures

    private func makeIssue(timestamp: TimeInterval, source: ReviewIssueSource,
                           note: String? = nil, transcript: String? = nil) throws -> ReviewIssue {
        let filename = "\(UUID().uuidString).png"
        try Data("fake png".utf8).write(to: sessionDir.appendingPathComponent(filename))
        return ReviewIssue(timestamp: timestamp, source: source, note: note,
                           transcript: transcript, screenshotFilename: filename)
    }

    private func makeOutput(issues: [ReviewIssue], transcript: [TranscriptSegment] = []) -> ReviewSessionOutput {
        ReviewSessionOutput(issues: issues, transcript: transcript, tempDirectory: sessionDir)
    }

    private var meta: ReviewSessionMeta {
        ReviewSessionMeta(recordedAt: Date(timeIntervalSince1970: 1_750_000_000),
                          duration: 222, target: "display (2560×1440)")
    }

    private func decodeManifest(in bundleURL: URL) throws -> ReviewManifest {
        let data = try Data(contentsOf: bundleURL.appendingPathComponent(ReviewReportGenerator.manifestFilename))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ReviewManifest.self, from: data)
    }

    // MARK: - Tests

    func testBundleContainsVideoScreenshotsAndReports() async throws {
        let issues = [
            try makeIssue(timestamp: 30.4, source: .manual, note: "button misaligned"),
            try makeIssue(timestamp: 12.0, source: .voice, transcript: "empty state needs copy"),
        ]
        let output = makeOutput(issues: issues,
                                transcript: [TranscriptSegment(start: 12.0, end: 14.0, text: "empty state needs copy")])
        let options = ReviewBundleOptions(includeVideo: true, includeFullTranscript: true)

        let bundleURL = try await ReviewReportGenerator().generate(
            output: output, videoURL: videoURL, sessionMeta: meta, options: options, saveLocation: saveDir)

        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: bundleURL.appendingPathComponent("recording.mp4").path))
        XCTAssertTrue(fm.fileExists(atPath: bundleURL.appendingPathComponent("screenshots/issue-01.png").path))
        XCTAssertTrue(fm.fileExists(atPath: bundleURL.appendingPathComponent("screenshots/issue-02.png").path))
        XCTAssertTrue(fm.fileExists(atPath: bundleURL.appendingPathComponent("report.md").path))
        XCTAssertTrue(fm.fileExists(atPath: bundleURL.appendingPathComponent("report.json").path))
        XCTAssertFalse(fm.fileExists(atPath: videoURL.path), "video is moved, not copied")
    }

    func testManifestSatisfiesSchemaConstraints() async throws {
        let issues = [
            try makeIssue(timestamp: 30.4, source: .manual, note: "button misaligned"),
            try makeIssue(timestamp: 12.0, source: .voice, transcript: "empty state needs copy"),
        ]
        let output = makeOutput(issues: issues,
                                transcript: [TranscriptSegment(start: 12.0, end: 14.0, text: "empty state needs copy")])
        let options = ReviewBundleOptions(includeVideo: true, includeFullTranscript: true)

        let bundleURL = try await ReviewReportGenerator().generate(
            output: output, videoURL: videoURL, sessionMeta: meta, options: options, saveLocation: saveDir)
        let manifest = try decodeManifest(in: bundleURL)

        // Top level (schema: required schemaVersion/generator/session/issues).
        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(manifest.generator, "ScreenPro")
        XCTAssertEqual(manifest.session.videoFile, "recording.mp4")
        XCTAssertEqual(manifest.session.target, "display (2560×1440)")

        // Issues: dense 1-based chronological indices, MM:SS timecodes,
        // bundle-relative screenshot paths that resolve.
        XCTAssertEqual(manifest.issues.count, 2)
        XCTAssertEqual(manifest.issues.map(\.index), [1, 2])
        XCTAssertEqual(manifest.issues.map(\.timestamp), [12.0, 30.4], "chronological order")
        XCTAssertEqual(manifest.issues[0].timecode, "00:12")
        XCTAssertEqual(manifest.issues[1].timecode, "00:30")
        for issue in manifest.issues {
            XCTAssertTrue(issue.screenshot.hasPrefix("screenshots/"), "schema pattern ^screenshots/")
            XCTAssertTrue(FileManager.default.fileExists(
                atPath: bundleURL.appendingPathComponent(issue.screenshot).path),
                "relative paths must resolve within the bundle (FR-010)")
            XCTAssertNotNil(issue.timecode.range(of: #"^[0-9]{2,}:[0-5][0-9]$"#, options: .regularExpression),
                            "timecode must match the schema pattern")
        }
        XCTAssertEqual(manifest.issues[0].source, .voice)
        XCTAssertEqual(manifest.issues[1].note, "button misaligned")
        XCTAssertEqual(manifest.fullTranscript?.count, 1)
    }

    func testMarkdownRendersChronologicallyWithRelativeImages() async throws {
        let issues = [
            try makeIssue(timestamp: 95.0, source: .manual, note: "second"),
            try makeIssue(timestamp: 5.0, source: .voice, transcript: "first remark"),
        ]
        let options = ReviewBundleOptions(includeVideo: true, includeFullTranscript: false)
        let bundleURL = try await ReviewReportGenerator().generate(
            output: makeOutput(issues: issues), videoURL: videoURL,
            sessionMeta: meta, options: options, saveLocation: saveDir)

        let markdown = try String(contentsOf: bundleURL.appendingPathComponent("report.md"), encoding: .utf8)

        XCTAssertTrue(markdown.contains("![Issue 1](screenshots/issue-01.png)"))
        XCTAssertTrue(markdown.contains("![Issue 2](screenshots/issue-02.png)"))
        XCTAssertTrue(markdown.contains("> first remark"))
        XCTAssertTrue(markdown.contains("**Note**: second"))
        let firstPos = markdown.range(of: "[00:05]")!.lowerBound
        let secondPos = markdown.range(of: "[01:35]")!.lowerBound
        XCTAssertLessThan(firstPos, secondPos, "issues appear chronologically (FR-009)")
        XCTAssertFalse(markdown.contains("Full Transcript"), "transcript excluded per options")
    }

    func testExcludingVideoLeavesOriginalAndNullsManifestField() async throws {
        let issues = [try makeIssue(timestamp: 1.0, source: .manual)]
        let options = ReviewBundleOptions(includeVideo: false, includeFullTranscript: true)

        let bundleURL = try await ReviewReportGenerator().generate(
            output: makeOutput(issues: issues), videoURL: videoURL,
            sessionMeta: meta, options: options, saveLocation: saveDir)

        XCTAssertFalse(FileManager.default.fileExists(
            atPath: bundleURL.appendingPathComponent("recording.mp4").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: videoURL.path),
                      "video stays at its original location when excluded")
        XCTAssertNil(try decodeManifest(in: bundleURL).session.videoFile)
    }

    func testMissingScreenshotFailsAndPreservesVideo() async throws {
        let phantom = ReviewIssue(timestamp: 3.0, source: .manual, screenshotFilename: "does-not-exist.png")
        let options = ReviewBundleOptions(includeVideo: true, includeFullTranscript: true)

        do {
            _ = try await ReviewReportGenerator().generate(
                output: makeOutput(issues: [phantom]), videoURL: videoURL,
                sessionMeta: meta, options: options, saveLocation: saveDir)
            XCTFail("expected screenshotMissing")
        } catch let error as ReviewReportError {
            XCTAssertEqual(error, .screenshotMissing(issueID: phantom.id))
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: videoURL.path), "video must survive failures")
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: saveDir.path)
        XCTAssertTrue(leftovers.isEmpty, "no partial bundle remains in the save folder")
    }

    func testUnwritableDestinationThrowsAndPreservesVideo() async throws {
        let unwritable = workDir.appendingPathComponent("not-a-dir.txt")
        try Data("file, not a directory".utf8).write(to: unwritable)
        let issues = [try makeIssue(timestamp: 1.0, source: .manual)]
        let options = ReviewBundleOptions(includeVideo: true, includeFullTranscript: true)

        do {
            _ = try await ReviewReportGenerator().generate(
                output: makeOutput(issues: issues), videoURL: videoURL,
                sessionMeta: meta, options: options, saveLocation: unwritable)
            XCTFail("expected destinationUnwritable")
        } catch let error as ReviewReportError {
            XCTAssertEqual(error, .destinationUnwritable(unwritable))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: videoURL.path))
    }

    func testBundleNameCollisionGetsCounterSuffix() async throws {
        let options = ReviewBundleOptions(includeVideo: false, includeFullTranscript: true)
        let first = try await ReviewReportGenerator().generate(
            output: makeOutput(issues: [try makeIssue(timestamp: 1, source: .manual)]),
            videoURL: videoURL, sessionMeta: meta, options: options, saveLocation: saveDir)
        let second = try await ReviewReportGenerator().generate(
            output: makeOutput(issues: [try makeIssue(timestamp: 2, source: .manual)]),
            videoURL: videoURL, sessionMeta: meta, options: options, saveLocation: saveDir)

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(second.lastPathComponent, "\(first.lastPathComponent) (1)")
    }
}
