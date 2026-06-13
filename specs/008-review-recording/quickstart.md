# Quickstart: Review Recording (008)

Developer quick reference. Read [plan.md](plan.md) and [research.md](research.md) first.

## What it does

Record screen in "Review" mode → flag moments (⌃⌥F or controls button) and/or just talk (on-device transcription) → each issue gets a screenshot from the live stream → on stop, a bundle folder is generated:

```text
Review 2026-06-12 at 14.30.05/
├── recording.mp4
├── screenshots/issue-01.png …
├── report.md      # human-readable
└── report.json    # agent contract — contracts/review-manifest.schema.json
```

## Key files

| File | Role |
|---|---|
| `Features/Review/ReviewSessionService.swift` | Session lifecycle, flags, voice/manual merge (±2 s window) |
| `Features/Review/SpeechTranscriptionService.swift` | SFSpeechRecognizer (on-device only) + `UtteranceSegmenter` (1.2 s silence boundary) |
| `Features/Review/ReviewFrameBuffer.swift` | 5-slot ring of deep-copied frames @ 2 Hz from `RecordingService.videoFrameTap` |
| `Features/Review/ReviewReportGenerator.swift` | Bundle folder + report.md + report.json |
| `Features/Review/ReviewSummaryView.swift` | Post-stop edit/delete (skippable) |
| `Core/Services/MicrophoneAudioHub.swift` | Single AVAudioEngine tap → fan-out (asset writer + recognizer) |
| `Features/Settings/ReviewSettingsTab.swift` | Voice notes, locale, hotkey, bundle options |

## Touched existing code

- `RecordingService`: `videoFrameTap` hook (sample-handler queue), mic capture moved onto `MicrophoneAudioHub`, new `recordedElapsedTime` (pause-adjusted clock — use this, never `duration`, for issue timestamps).
- `ShortcutManager`/`ShortcutAction`: `.reviewFlag` (default ⌃⌥F), registered **only during** a review session.
- `PermissionManager`: speech recognition status/request (`NSSpeechRecognitionUsageDescription` in Info.plist).
- `SettingsManager`: 5 new fields (see data-model.md) + tolerant-decoding entries.
- `AppCoordinator`: `startReviewRecording()`, stop pipeline (summary → generator → history → Quick Access reveal), cancel cleanup.
- `RecordingControlsView`: flag button + issue-count badge in review mode.

## Invariants to keep

1. **Never retain SCStream pixel buffers** — always deep-copy in the frame tap (pool starvation stalls capture).
2. **Never let recognition fall back to server** — if `supportsOnDeviceRecognition == false`, run manual-only and notify once.
3. **One input-bus tap, ever** — all mic consumers go through `MicrophoneAudioHub`.
4. **Issue timestamps = `recordedElapsedTime`** so they seek correctly in the saved video across pauses.
5. **Session artifacts live in `tmp/ReviewSession-<uuid>/` until finalization** — cancel must leave no trace; failures must never leave half a bundle in the save folder, and the video must survive generator failures.
6. **Zero issues → plain recording save** + notification (no empty bundle).

## Manual test script

1. Settings → Review: confirm defaults (voice notes on, ⌃⌥F).
2. Menu bar → "Record Screen (Review Mode)" → pick a display.
3. Press ⌃⌥F twice; type a note after the second flag; say "this button is misaligned", pause, say "empty state needs copy".
4. Pause recording, press ⌃⌥F (must be rejected), resume.
5. Stop → summary shows 4 issues (2 manual, 2 voice) → delete one → Generate.
6. Verify bundle contents, `report.md` images render, `report.json` validates against the schema, timestamps seek correctly in `recording.mp4`.
7. Feed the folder to a coding agent ("fix the issues in report.json") — it should enumerate all issues without help.
