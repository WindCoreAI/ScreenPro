# Research: Review Recording (008)

**Date**: 2026-06-12 | **Plan**: [plan.md](plan.md)

All Technical Context unknowns resolved. Each decision below records what was chosen, why, and what was rejected.

## R1. On-device speech transcription

**Decision**: `SFSpeechRecognizer` (Speech framework) with `SFSpeechAudioBufferRecognitionRequest`, `requiresOnDeviceRecognition = true`, `shouldReportPartialResults = true`, `taskHint = .dictation`, optional `addsPunctuation = true` (macOS 13+).

**Rationale**:
- Apple-native (Constitution I) and supports strict on-device mode (Constitution II / FR-018). When `supportsOnDeviceRecognition` is false for the selected locale, we fail closed: voice notes disabled for the session with one user-facing notice — we never silently fall back to server recognition.
- Buffer-based request integrates directly with the `AVAudioPCMBuffer`s we already obtain from the input tap; no file round-trip.
- `SFSpeechRecognitionResult.bestTranscription.segments` provides per-word `timestamp`/`duration` (relative to the audio stream), which we use to anchor utterance start times.

**Alternatives considered**:
- *Vision/`SFSpeechRecognizer` file-based post-processing after stop*: simpler, but kills the live experience (no live note feedback, no live screenshot pairing — we'd have to retro-extract frames from the encoded video, which is possible via `AVAssetImageGenerator` but loses the "screenshot at the exact moment" guarantee while paused/overlays, and delays the report).
- *`SpeechAnalyzer` (newer API)*: requires macOS 26+; project minimum is 14.0. Revisit when minimum rises.
- *Whisper.cpp or other local models*: third-party dependency, prohibited by the constitution.

**Permission**: `SFSpeechRecognizer.requestAuthorization` + `NSSpeechRecognitionUsageDescription` in Info.plist. Requested lazily at first Review Recording start with voice notes enabled (Constitution VII). Note: with on-device recognition Apple does not transmit audio, but authorization is still required.

## R2. Utterance segmentation

**Decision**: Silence-timeout segmentation over a long-running buffer request:
1. Feed all mic buffers to the active recognition request.
2. On each partial result, record `lastPartialAt = now` and remember the first segment's `timestamp` for utterance start.
3. A repeating 300 ms check closes the utterance when `now - lastPartialAt > 1.2 s` and the accumulated text is non-empty: emit `Utterance(text, startRecordedTime, endRecordedTime)`, cancel the task, start a fresh request for the next utterance.
4. Discard utterances whose trimmed text is empty (handles breath noise / recognizer artifacts) — satisfies "silence creates no notes".

**Rationale**: `SFSpeechRecognizer` does not deliver `isFinal` until the request ends, so a practical streaming segmenter must impose its own boundary. The restart-per-utterance pattern is the standard approach and also bounds recognition-task memory in hour-long sessions (Apple recommends limiting individual dictation task duration; restarting per utterance keeps each task seconds long).

**Tunables**: silence threshold 1.2 s (constant, not a setting for v1); minimum utterance length 2 characters.

**Alternatives considered**: voice-activity detection on raw buffers (RMS gate) to start/stop recognition — more code, duplicates what partial results already signal; explicit voice command ("flag this") — out of scope per spec assumptions.

## R3. Screenshot-at-moment extraction

**Decision**: `ReviewFrameBuffer` subscribes to a new `videoFrameTap` closure on `RecordingService` (called from the existing `RecordingStreamOutput` screen-sample path on its sample-handler queue). It keeps a ring of the last 5 frames sampled at ≥ 500 ms spacing, each deep-copied (`CVPixelBuffer` → new buffer via `vImageBuffer`/memcpy, or direct `CGImage` conversion at copy time). Flag → newest ring frame; voice note → ring frame nearest the utterance start time. PNG encoding (`CGImageDestination`, ImageIO) happens on a detached background task writing into the session's temp directory.

**Rationale**:
- Retaining the stream's own `CVPixelBuffer`s would starve `SCStream`'s fixed pool (`queueDepth = 8`) and stall capture — copies are mandatory.
- 1080p BGRA frame ≈ 8 MB; 5-slot ring ≈ 40 MB, within the constraint and only alive during review sessions.
- 2 Hz cadence bounds copy cost (≈ 8 MB memcpy / 500 ms, negligible) while guaranteeing ≤ 0.5 s frame accuracy (SC-004).
- Encoding to PNG off the ring (not at flag time on the sample queue) keeps the sample handler real-time safe (SC-003).

**Alternatives considered**:
- *One-shot `CaptureService` screenshot per flag*: extra SCStream churn, captures the raw screen rather than the recorded composition (different crop/scale), ~50 ms+ latency. Rejected (see plan Complexity Tracking).
- *Post-hoc `AVAssetImageGenerator` extraction from the finished video*: frame-accurate and zero runtime cost, but unavailable for cancel-safe live preview in the note panel and summary, requires the video to be fully written first (delays report), and fails if the user excludes the video from the bundle. Kept as a documented fallback for issues whose ring frame was evicted (should not happen at 2 Hz, but the generator is the safety net for the "stop within 1 s of flag" edge case if the PNG task lost the race).

## R4. Microphone sharing between recording track and recognizer

**Decision**: New `Core/Services/MicrophoneAudioHub.swift`: owns one `AVAudioEngine`, installs the single input-bus tap, and forwards `(AVAudioPCMBuffer, AVAudioTime)` to registered consumers (small array of `@Sendable` closures, registered/removed by token). `RecordingService.setupMicrophoneCapture()` becomes a hub consumer that converts to `CMSampleBuffer` and appends to `microphoneInput` (existing logic moves, unchanged). `SpeechTranscriptionService` is a second consumer appending to the recognition request.

**Rationale**: `AVAudioInputNode` allows exactly one tap per bus — the current RecordingService tap and a recognizer tap cannot coexist. The hub also cleanly supports the "transcribe narration without recording it" case (`recordMicrophone == false` but voice notes on): only the recognizer consumer is registered, mic audio never reaches the asset writer.

**Lifecycle**: hub engine runs while any consumer is registered; stops when the last consumer unregisters. Mic permission is checked before starting (existing `PermissionManager.requestMicrophonePermission`).

## R5. Recorded-time clock (pause correctness)

**Decision**: Add `RecordingService.recordedElapsedTime: TimeInterval` — computed as `hostClockNow - sessionStartHostTime - pauseOffset` using the same `CMClockGetHostTimeClock()` + `pauseOffset` machinery the video writer uses for frame timestamps. ReviewSessionService stamps every issue with this value.

**Rationale**: Issue timestamps must seek correctly in the saved video (FR-017, FR-009/010). The published `duration` property freezes during pause but recomputes from wall-clock `recordingStartTime` on resume, so it silently re-includes paused time — unsuitable (and a latent display bug; noted for an optional drive-by fix using the same new clock).

## R6. Global flag hotkey

**Decision**: Extend `ShortcutAction` with `case reviewFlag` (display "Flag Review Moment", default ⌃⌥F — keyCode 0x03, `controlKey | optionKey`). It is **not** included in the always-registered set: AppCoordinator registers it when a review session starts and unregisters at stop/cancel. Configurable via the existing shortcut-recording UI; persisted in `settings.shortcuts` like all others (tolerant decoding handles upgrades).

**Rationale**: Per-session registration means the key is never consumed globally outside review (spec US1 scenario 4) and avoids new conflicts with the crowded ⌘⇧-digit space. Carbon `RegisterEventHotKey` works while other apps have focus — required, since the reviewer is using the product under test, not ScreenPro.

## R7. Report bundle format

**Decision**: Plain folder `Review {date} at {time}/` (via existing `fileNamingPattern` substitution + `uniqueURL` conflict handling):

```text
Review 2026-06-12 at 14.30.05/
├── recording.mp4          # moved from RecordingService output (optional per settings)
├── screenshots/
│   ├── issue-01.png
│   └── issue-02.png
├── report.md              # human-readable
└── report.json            # machine-readable manifest (schema: contracts/review-manifest.schema.json)
```

`report.json` top level: `schemaVersion`, `generator`, `session {recordedAt, duration, target, videoFile?, transcriptIncluded}`, `issues [{id, index, timestamp, timecode, source: "manual"|"voice", note?, transcript?, screenshot, videoTimecodeURL?}]`, optional `fullTranscript [{start, end, text}]`. All paths relative to the bundle root (FR-010). `report.md` renders the same data chronologically with embedded `![](screenshots/issue-NN.png)` images and `MM:SS` timecodes (FR-009).

**Rationale**: A plain folder (not an NSDocument package) is directly readable by agents and humans (spec assumption). Markdown with relative image links renders in editors/GitHub and can be pasted into a Claude Code prompt as-is; the JSON manifest is the stable contract for programmatic consumption. `schemaVersion: 1` future-proofs the contract.

**Alternatives considered**: single self-contained HTML (not agent-friendly); zip archive (breaks drag-into-agent-context workflows); SQLite (absurd overkill).

## R8. Session lifecycle & integration points

**Decision**:
- `AppCoordinator.startReviewRecording()` mirrors `startRecording()` but sets `isReviewSession`, starts `ReviewSessionService` after `recordingService.startRecording` succeeds, and registers the flag hotkey. Menu bar gains "Record Screen (Review Mode)…"; review mode is offered only for `.video` format (GIF excluded, spec assumption).
- Stop: coordinator stops recording first (video finalized), then presents the summary window (skippable; auto-proceed on close), then `ReviewReportGenerator.generate(...)` moves the video into the bundle, writes screenshots/reports, records a history entry (recording type, fileURL = bundle folder, thumbnail = first issue screenshot or video thumbnail), and pushes a Quick Access item whose "Save/Show" action reveals the bundle in Finder (`NSWorkspace.activateFileViewerSelecting`).
- Zero issues + empty transcript → bypass summary/bundle, fall through to today's `handleRecordingResult` path plus an informational notification (FR-013).
- Cancel → `ReviewSessionService.cancel()` deletes the session temp directory (FR-016).
- Pause/resume → session suspends recognizer consumption and rejects flags while paused (FR-017).

**Temp storage**: screenshots and in-progress state live in `FileManager.temporaryDirectory/ReviewSession-<uuid>/` until bundle finalization moves them — guarantees cancel cleanliness and avoids partial bundles in the user's save folder on failure.

## R9. Settings & persistence

**Decision**: New `Settings` fields (all with defaults + tolerant decoding entries):
`reviewVoiceNotesEnabled: Bool = true`, `reviewTranscriptionLocale: String = ""` (empty → system locale), `reviewBundleIncludesVideo: Bool = true`, `reviewBundleIncludesTranscript: Bool = true`, `reviewShowSummaryBeforeExport: Bool = true`. Flag hotkey rides in existing `shortcuts`. New `ReviewSettingsTab` lists locales from `SFSpeechRecognizer.supportedLocales()` filtered to on-device-capable ones.

## R10. Testing strategy

**Decision**: Protocol-seam testing without live audio/screen:
- `SpeechTranscriptionService` exposes its segmentation core as a pure component (`UtteranceSegmenter`) driven by injected partial-result events + a test clock → unit tests for boundaries, silence, empty-text discard (SC-006 logic).
- `ReviewSessionService` takes `FrameProviding` + `TranscriptionProviding` protocol deps → lifecycle/merge tests with stubs (flag/voice merge window, pause rejection, cancel cleanup).
- `ReviewReportGenerator` is pure (issues in, files out to a temp dir) → golden tests for `report.md` and `report.json` against the schema, relative-path resolution, zero-issue behavior, unwritable-destination error.
- Performance: benchmark test measuring frame-copy cost and flag-path latency per Constitution IV review requirement.
