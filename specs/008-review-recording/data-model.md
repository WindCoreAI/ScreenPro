# Data Model: Review Recording (008)

**Date**: 2026-06-12 | **Plan**: [plan.md](plan.md)

## Entity Overview

```text
ReviewSessionService (1 active max)
 └── ReviewSessionState ──── issues: [ReviewIssue]
        │                    transcript: [TranscriptSegment]
        │                    tempDirectory: URL
        ▼ on stop
 ReviewReportGenerator ──→ ReviewBundle (folder on disk)
        ▲ described by
 ReviewManifest (Codable ⇄ report.json)
```

## ReviewIssue

One observation captured during a session. Value type, `Identifiable`, `Sendable`, `Codable` (persisted only inside the manifest).

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | stable across summary edits |
| `timestamp` | `TimeInterval` | recorded time (pause-adjusted), seconds into the video |
| `source` | `ReviewIssueSource` | `.manual` or `.voice` |
| `note` | `String?` | typed text (quick-note field or summary edit) |
| `transcript` | `String?` | spoken text (voice issues; merged into manual issues per FR-007) |
| `screenshotFilename` | `String` | `issue-NN.png`, assigned at finalization; during the session a temp URL is tracked |

**Validation / invariants**:
- `timestamp >= 0`; issues kept sorted by timestamp.
- At least one of `note`/`transcript` may be nil; both nil is legal for a bare manual flag (US1 scenario 3).
- `screenshotFilename` unique within a session; numbering `issue-01…` assigned in chronological order at finalization (post summary-deletions, so numbering is dense).

```swift
enum ReviewIssueSource: String, Codable, Sendable { case manual, voice }
```

## TranscriptSegment

Full-session narration (optional bundle content, FR-015).

| Field | Type | Notes |
|---|---|---|
| `start` / `end` | `TimeInterval` | recorded time |
| `text` | `String` | utterance text |

Every voice issue corresponds to one segment; segments merged into manual flags still appear in the full transcript.

## ReviewSessionState

Held by `ReviewSessionService` (`@MainActor`); not persisted. State machine:

```text
inactive ──start──▶ active ──pause──▶ suspended
   ▲                  │  ▲──resume──────┘
   │                  ├──stop──▶ finalizing ──▶ inactive (bundle written)
   └─────cancel───────┴──cancel─▶ inactive (temp dir deleted)
```

| Field | Type | Notes |
|---|---|---|
| `phase` | `Phase` (`inactive/active/suspended/finalizing`) | flags rejected unless `active` (FR-017) |
| `issues` | `[ReviewIssue]` | append-only during session; edited in summary |
| `transcript` | `[TranscriptSegment]` | |
| `tempDirectory` | `URL` | `…/ReviewSession-<uuid>/`, deleted on cancel (FR-016) |
| `voiceNotesActive` | `Bool` | false when permission denied / model unavailable (FR-014) |

**Merge rule (FR-007)**: when a manual flag occurs at time *t*, any utterance with `start ∈ [t − 2 s, t + 2 s]` (or currently open and started before *t*) attaches its text to the manual issue's `transcript` instead of emitting a separate voice issue.

## ReviewBundleOptions

Derived from `Settings` at stop time (so mid-session settings changes don't tear the bundle).

| Field | Type | Default |
|---|---|---|
| `includeVideo` | `Bool` | `true` |
| `includeFullTranscript` | `Bool` | `true` |

## ReviewManifest (report.json)

Codable mirror of `contracts/review-manifest.schema.json`. `schemaVersion = 1`.

```swift
struct ReviewManifest: Codable, Sendable {
    let schemaVersion: Int            // 1
    let generator: String             // "ScreenPro"
    let session: Session
    let issues: [Issue]
    let fullTranscript: [Segment]?    // nil when excluded

    struct Session: Codable, Sendable {
        let recordedAt: Date          // ISO 8601
        let duration: TimeInterval
        let target: String            // "display"|"window"|"area" + descriptor
        let videoFile: String?        // "recording.mp4", nil when excluded
    }
    struct Issue: Codable, Sendable {
        let id: UUID
        let index: Int                // 1-based chronological
        let timestamp: TimeInterval   // seconds into video
        let timecode: String          // "MM:SS" convenience
        let source: ReviewIssueSource
        let note: String?
        let transcript: String?
        let screenshot: String        // "screenshots/issue-01.png" (bundle-relative)
    }
    struct Segment: Codable, Sendable {
        let start: TimeInterval
        let end: TimeInterval
        let text: String
    }
}
```

## Settings additions

| Field | Type | Default | CodingKey |
|---|---|---|---|
| `reviewVoiceNotesEnabled` | `Bool` | `true` | `reviewVoiceNotesEnabled` |
| `reviewTranscriptionLocale` | `String` | `""` (system) | `reviewTranscriptionLocale` |
| `reviewBundleIncludesVideo` | `Bool` | `true` | `reviewBundleIncludesVideo` |
| `reviewBundleIncludesTranscript` | `Bool` | `true` | `reviewBundleIncludesTranscript` |
| `reviewShowSummaryBeforeExport` | `Bool` | `true` | `reviewShowSummaryBeforeExport` |
| `shortcuts[.reviewFlag]` | `Shortcut` | ⌃⌥F | existing `shortcuts` map |

All added to the tolerant-decoding initializer (007 pattern) so upgrades keep defaults.

## ShortcutAction addition

`case reviewFlag` — excluded from `Shortcut.defaults` *registration set semantics*: present in the defaults map (so the settings UI can show/edit it) but AppCoordinator registers/unregisters it only around review sessions (R6).

## Capture history integration

Reuses `CaptureHistoryItem` (no schema change): `type = .recording`, `fileURL = bundle folder URL`, `thumbnailData` = first issue screenshot (fallback: video thumbnail). The history browser's existing reveal/drag actions operate on the folder.
