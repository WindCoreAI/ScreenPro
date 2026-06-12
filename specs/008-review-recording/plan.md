# Implementation Plan: Review Recording

**Branch**: `claude/modest-mendel-lmwqlm` (feature dir `008-review-recording`) | **Date**: 2026-06-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/008-review-recording/spec.md`

## Summary

Add a "Review" mode to screen recording: while recording, the reviewer flags moments via a global hotkey / controls button, and (optionally) ScreenPro transcribes their narration on-device, turning each spoken observation into a review issue with an automatically captured screenshot from the live ScreenCaptureKit stream. On stop, a Review Report bundle (video + screenshots + `report.md` + `report.json`) is generated under the user's save location, surfaced via Quick Access and capture history, and consumable by agentic coding tools with zero preprocessing.

Technical approach: a new `ReviewSessionService` orchestrates the session. It taps the existing `RecordingService` video pipeline through a lightweight frame ring buffer (deep-copied pixel buffers at ~2 Hz) so flags and utterance starts can resolve to the frame that was on screen at that moment. Speech uses `SFSpeechRecognizer` with `requiresOnDeviceRecognition`, fed from a new `MicrophoneAudioHub` that owns the single `AVAudioEngine` input tap and fans buffers out to both the asset writer (existing mic track) and the recognizer. `ReviewReportGenerator` writes the bundle. UI: a flag button on the recording controls, a transient quick-note field, a post-stop summary window (SwiftUI), and a Review settings tab.

## Technical Context

**Language/Version**: Swift 5.9+, strict concurrency checking enabled
**Primary Dependencies**: ScreenCaptureKit (existing stream), AVFoundation (AVAudioEngine), Speech (SFSpeechRecognizer — new framework, Apple-native), Carbon (existing ShortcutManager), SwiftUI + AppKit (summary window, note field), Core Graphics / ImageIO (PNG screenshots), Foundation `JSONEncoder` (manifest)
**Storage**: FileManager bundle folder under `settings.defaultSaveLocation`; SwiftData capture-history entry (existing store); settings via existing `SettingsManager` (UserDefaults)
**Testing**: XCTest — unit tests for utterance segmentation, flag/voice merge, report generation (manifest schema, markdown), filename/bundle layout; integration test for session lifecycle with stubbed frame/speech sources
**Target Platform**: macOS 14.0+ (Sonoma), Universal Binary
**Project Type**: Single native macOS app, feature-module structure (`ScreenPro/Features/Review/`)
**Performance Goals**: Flag action ≤ 0.5 s frame accuracy (SC-004); zero dropped frames attributable to flagging (SC-003); bundle for a 10-min/10-issue session ready < 30 s after stop (SC-002)
**Constraints**: On-device-only speech (Privacy by Default); no third-party deps; @MainActor UI, Sendable data across the stream sample queue boundary; ring buffer memory ≤ ~50 MB at 1080p
**Scale/Scope**: Sessions up to ~60 min, ~100 issues; single concurrent session (mirrors RecordingService single-recording invariant)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|---|---|---|
| I. Native macOS First | PASS | Speech framework is Apple-native; everything else reuses ScreenCaptureKit/AVFoundation/ImageIO. No new dependencies. |
| II. Privacy by Default | PASS | `requiresOnDeviceRecognition = true`; recognizer fails closed (voice notes disabled) if on-device model unavailable rather than falling back to server. Bundle written locally; no uploads without explicit user action (existing cloud flow untouched). FR-018 enforced. |
| III. UX Excellence | PASS | Flag is one keypress, never interrupts recording; quick-note field is non-blocking and auto-dismisses; summary window is skippable; Quick Access remains the post-capture surface. |
| IV. Performance Standards | PASS (verify) | Frame copies happen on the sample-handler queue at ≤ 2 Hz cadence (memcpy of one frame, ~ms); PNG encoding deferred to a background task; report generation off the main actor. Benchmarks required for the 50-flag/30-min scenario per "Performance-sensitive changes MUST include benchmarks". |
| V. Testing Discipline | PASS | Contract + unit tests planned for segmentation, merge, and report generation; happy-path integration test for the session lifecycle. |
| VI. Accessibility | PASS | Flag button labeled + hint; summary window fully keyboard-navigable; issue count announced via existing `AccessibilityAnnouncer`; Reduce Motion respected (no new persistent animations). |
| VII. Security Boundaries | PASS | Speech Recognition permission requested at first Review Recording start, not at launch; `NSSpeechRecognitionUsageDescription` added to Info.plist. Sandbox unaffected (writes inside user-selected save location, as today). |

**Post-Phase-1 re-check**: PASS — design introduces no violations; one shared-infrastructure refactor (microphone tap fan-out) is justified in Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/008-review-recording/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── ReviewSessionServiceProtocol.swift
│   ├── ReviewReportGeneratorProtocol.swift
│   ├── SpeechTranscriptionServiceProtocol.swift
│   └── review-manifest.schema.json
├── checklists/requirements.md
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
ScreenPro/
├── Core/
│   ├── AppCoordinator.swift                    # MODIFIED: review session wiring, startReviewRecording(), shortcut routing
│   └── Services/
│       ├── SettingsManager.swift               # MODIFIED: review settings fields + tolerant decoding
│       ├── ShortcutManager.swift               # MODIFIED: .reviewFlag action + dynamic register/unregister
│       ├── PermissionManager.swift             # MODIFIED: speech recognition permission
│       └── MicrophoneAudioHub.swift            # NEW: single AVAudioEngine tap, fan-out to consumers
├── Features/
│   ├── Recording/
│   │   ├── RecordingService.swift              # MODIFIED: frame tap hook, mic hub adoption, recordedElapsedTime
│   │   ├── RecordingControlsView.swift         # MODIFIED: flag button + issue count (review mode only)
│   │   └── Models/RecordingResult.swift        # unchanged (bundle wraps it)
│   └── Review/                                 # NEW feature module
│       ├── ReviewSessionService.swift          # session lifecycle, flags, voice/manual merge
│       ├── SpeechTranscriptionService.swift    # SFSpeechRecognizer wrapper, utterance segmentation
│       ├── ReviewFrameBuffer.swift             # ring buffer of recent frames + PNG export
│       ├── ReviewReportGenerator.swift         # bundle folder, report.md, report.json
│       ├── ReviewNotePanel.swift               # transient quick-note field (NSPanel + SwiftUI)
│       ├── ReviewSummaryWindowController.swift # post-stop edit/delete summary
│       ├── ReviewSummaryView.swift
│       └── Models/
│           ├── ReviewIssue.swift
│           ├── ReviewSessionState.swift
│           ├── ReviewBundleOptions.swift
│           └── ReviewManifest.swift            # Codable mirror of report.json
│   └── Settings/
│       └── ReviewSettingsTab.swift             # NEW settings tab
ScreenProTests/
└── Review/
    ├── UtteranceSegmentationTests.swift
    ├── ReviewMergeTests.swift
    ├── ReviewReportGeneratorTests.swift
    └── ReviewSessionLifecycleTests.swift
```

**Structure Decision**: Follows the established feature-module layout (`Features/Review/` mirroring `Features/Recording/`). `MicrophoneAudioHub` lives in `Core/Services` because it is shared infrastructure between RecordingService (mic track) and the Review feature (transcription).

## Key Design Decisions (summary — details in research.md)

1. **Flag screenshots from the live stream, not a separate capture**: `RecordingService` gains an optional `videoFrameTap: (@Sendable (CMSampleBuffer) -> Void)?` invoked on the sample-handler queue. `ReviewFrameBuffer` consumes it, deep-copying one frame every ~500 ms into a 5-slot ring (≤ ~40 MB at 1080p). A flag resolves to the newest frame; a voice note resolves to the frame nearest the utterance start (recognition latency means the right frame is slightly in the past — hence the ring, not just "latest").
2. **One microphone tap, many consumers**: `MicrophoneAudioHub` owns the `AVAudioEngine` input tap and forwards `AVAudioPCMBuffer`s to registered consumers (asset-writer mic track when `recordMicrophone` is on; speech recognizer when voice notes are on). Fixes the otherwise-fatal double-tap conflict and lets narration be transcribed without being recorded into the video.
3. **Utterance segmentation by partial-result silence timeout**: one long-running `SFSpeechAudioBufferRecognitionRequest`; an utterance closes when no new partial text arrives for 1.2 s, then the request is restarted for the next utterance. Utterance start time = recorded-time when its first partial arrived minus the recognizer's reported word timing offset where available.
4. **Manual + voice merge window**: a manual flag within ±2 s of an active/just-closed utterance absorbs that utterance's transcript instead of producing two issues (FR-007).
5. **Pause-correct timestamps**: review timestamps use a new `RecordingService.recordedElapsedTime` computed with the same `pauseOffset` the video writer uses, so issue timestamps always seek correctly in the saved video.
6. **Bundle is a plain folder**: `Review {date} at {time}/` containing `recording.mp4`, `screenshots/issue-NN.png`, `report.md`, `report.json`. `report.json` conforms to `contracts/review-manifest.schema.json` — this schema is the agentic-integration contract.
7. **Hotkey registered per-session**: `.reviewFlag` (default ⌃⌥F) is registered when a review session starts and unregistered at stop/cancel, so the key is never globally consumed outside review sessions (FR per US1 scenario 4).
8. **Degradation paths**: speech permission denied / model unavailable → manual flags only, single notification; zero issues at stop → plain recording save + notification (FR-013); cancel → session directory (temp screenshots) deleted (FR-016).

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Refactor of existing mic capture into `MicrophoneAudioHub` (touches working 005 code) | AVAudioEngine permits one tap per input bus; transcription and the mic audio track must share it | A second `AVAudioEngine` instance per consumer is fragile (device contention, format drift) and duplicates buffers; keeping the tap inside RecordingService and pushing recognition into it would couple recording to the Speech framework and violate single-responsibility |
| `videoFrameTap` hook on RecordingService | Flags must capture the exact recorded content (same crop/scale the video has) with no extra ScreenCaptureKit stream | Running a parallel one-shot `CaptureService` capture per flag costs ~50 ms+, may include overlays/regions that differ from the recording, and risks SCStream contention |
