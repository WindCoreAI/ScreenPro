import Foundation

// MARK: - ReviewReportGenerator (008-review-recording)
//
// Pure file producer: finished session in, bundle folder out (FR-008..011).
// Runs off the main actor. On ANY failure the recording survives at its
// original location and no partial bundle remains in the save folder.
//
// Bundle layout (research.md R7):
//   <saveLocation>/Review {date} at {time}/
//     recording.mp4            (when options.includeVideo)
//     screenshots/issue-NN.png (dense chronological numbering)
//     report.md                (human-readable)
//     report.json              (contracts/review-manifest.schema.json, v1)

struct ReviewReportGenerator: Sendable {
    static let videoFilename = "recording.mp4"
    static let screenshotsDirectory = "screenshots"
    static let markdownFilename = "report.md"
    static let manifestFilename = "report.json"

    func generate(
        output: ReviewSessionOutput,
        videoURL: URL,
        sessionMeta: ReviewSessionMeta,
        options: ReviewBundleOptions,
        saveLocation: URL
    ) async throws -> URL {
        let fileManager = FileManager.default

        // Destination folder, unique-ified like StorageService does for files.
        let bundleURL = Self.uniqueBundleURL(in: saveLocation, recordedAt: sessionMeta.recordedAt)
        do {
            try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        } catch {
            throw ReviewReportError.destinationUnwritable(saveLocation)
        }

        var movedVideo = false
        do {
            // Screenshots: copy from session temp dir with final names.
            let screenshotsURL = bundleURL.appendingPathComponent(Self.screenshotsDirectory, isDirectory: true)
            try fileManager.createDirectory(at: screenshotsURL, withIntermediateDirectories: true)

            let issues = output.issues.sorted { $0.timestamp < $1.timestamp }
            var manifestIssues: [ReviewManifest.Issue] = []
            for (offset, issue) in issues.enumerated() {
                let index = offset + 1
                let finalName = String(format: "issue-%02d.png", index)
                let source = output.tempDirectory.appendingPathComponent(issue.screenshotFilename)
                guard fileManager.fileExists(atPath: source.path) else {
                    throw ReviewReportError.screenshotMissing(issueID: issue.id)
                }
                try fileManager.copyItem(at: source, to: screenshotsURL.appendingPathComponent(finalName))

                manifestIssues.append(ReviewManifest.Issue(
                    id: issue.id,
                    index: index,
                    timestamp: issue.timestamp,
                    timecode: issue.timecode,
                    source: issue.source,
                    note: issue.note,
                    transcript: issue.transcript,
                    screenshot: "\(Self.screenshotsDirectory)/\(finalName)"
                ))
            }

            // Reports before the video move, so a report failure never
            // requires moving the video back.
            let manifest = ReviewManifest(
                schemaVersion: ReviewManifest.currentSchemaVersion,
                generator: "ScreenPro",
                session: ReviewManifest.Session(
                    recordedAt: sessionMeta.recordedAt,
                    duration: sessionMeta.duration,
                    target: sessionMeta.target,
                    videoFile: options.includeVideo ? Self.videoFilename : nil
                ),
                issues: manifestIssues,
                fullTranscript: options.includeFullTranscript
                    ? output.transcript.map { ReviewManifest.Segment(start: $0.start, end: $0.end, text: $0.text) }
                    : nil
            )

            try Self.encodeManifest(manifest)
                .write(to: bundleURL.appendingPathComponent(Self.manifestFilename))
            try Self.renderMarkdown(manifest: manifest)
                .data(using: .utf8)!
                .write(to: bundleURL.appendingPathComponent(Self.markdownFilename))

            if options.includeVideo {
                try fileManager.moveItem(
                    at: videoURL,
                    to: bundleURL.appendingPathComponent(Self.videoFilename)
                )
                movedVideo = true
            }

            return bundleURL
        } catch {
            // Restore the video first, then remove the partial bundle.
            if movedVideo {
                try? fileManager.moveItem(
                    at: bundleURL.appendingPathComponent(Self.videoFilename),
                    to: videoURL
                )
            }
            try? fileManager.removeItem(at: bundleURL)
            if let reportError = error as? ReviewReportError {
                throw reportError
            }
            throw ReviewReportError.encodingFailed(error.localizedDescription)
        }
    }

    // MARK: - Naming

    static func uniqueBundleURL(in directory: URL, recordedAt: Date) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: recordedAt)
        formatter.dateFormat = "HH.mm.ss"
        let time = formatter.string(from: recordedAt)

        let base = "Review \(date) at \(time)"
        var candidate = directory.appendingPathComponent(base, isDirectory: true)
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base) (\(counter))", isDirectory: true)
            counter += 1
        }
        return candidate
    }

    // MARK: - report.json

    static func encodeManifest(_ manifest: ReviewManifest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(manifest)
    }

    // MARK: - report.md (FR-009)

    static func renderMarkdown(manifest: ReviewManifest) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short

        var lines: [String] = []
        lines.append("# Review Report — \(dateFormatter.string(from: manifest.session.recordedAt))")
        lines.append("")
        lines.append("- **Target**: \(manifest.session.target)")
        lines.append("- **Duration**: \(ReviewIssue.timecode(for: manifest.session.duration))")
        if let video = manifest.session.videoFile {
            lines.append("- **Recording**: [\(video)](\(video))")
        }
        lines.append("- **Issues**: \(manifest.issues.count)")
        lines.append("")

        if manifest.issues.isEmpty {
            lines.append("_No issues were flagged in this session._")
        } else {
            lines.append("## Issues")
            lines.append("")
            for issue in manifest.issues {
                let sourceLabel = issue.source == .manual ? "flagged" : "spoken"
                lines.append("### \(issue.index). [\(issue.timecode)] \(sourceLabel)")
                lines.append("")
                if let transcript = issue.transcript, !transcript.isEmpty {
                    lines.append("> \(transcript)")
                    lines.append("")
                }
                if let note = issue.note, !note.isEmpty {
                    lines.append("**Note**: \(note)")
                    lines.append("")
                }
                lines.append("![Issue \(issue.index)](\(issue.screenshot))")
                lines.append("")
            }
        }

        if let transcript = manifest.fullTranscript, !transcript.isEmpty {
            lines.append("## Full Transcript")
            lines.append("")
            for segment in transcript {
                let start = ReviewIssue.timecode(for: segment.start)
                let end = ReviewIssue.timecode(for: segment.end)
                lines.append("- **[\(start)–\(end)]** \(segment.text)")
            }
            lines.append("")
        }

        lines.append("---")
        lines.append("_Generated by ScreenPro Review Recording. Machine-readable version: `\(manifestFilename)`._")
        lines.append("")
        return lines.joined(separator: "\n")
    }
}
