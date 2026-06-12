# Tasks: Review Recording

**Input**: Design documents from `/specs/008-review-recording/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included per Constitution V (testing strategy defined in research.md R10).

**Organization**: Grouped by user story. US1+US2 together form the MVP (flag → bundle). Note: this project uses explicit pbxproj file references (`objectVersion = 56`) — every new `.swift` file must also be registered in `ScreenPro.xcodeproj/project.pbxproj` (PBXBuildFile + PBXFileReference + group + Sources phase); each task creating files includes that registration.

## Phase 1: Setup

- [x] T001 Create `ScreenPro/Features/Review/` and `ScreenPro/Features/Review/Models/` groups plus `ScreenProTests/Review/` in `ScreenPro.xcodeproj/project.pbxproj`
- [x] T002 Add `NSSpeechRecognitionUsageDescription` ("ScreenPro transcribes your narration on-device to create review notes during Review Recordings.") to `ScreenPro/Info.plist`

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared models, the recorded-time clock, the frame tap, the mic hub, settings, and the hotkey action — everything more than one story depends on.

- [x] T003 [P] Create review models per data-model.md — `ReviewIssue` + `ReviewIssueSource` in `ScreenPro/Features/Review/Models/ReviewIssue.swift`, `TranscriptSegment` + `ReviewSessionPhase` in `ScreenPro/Features/Review/Models/ReviewSessionState.swift`, `ReviewBundleOptions` + `ReviewSessionMeta` in `ScreenPro/Features/Review/Models/ReviewBundleOptions.swift`, `ReviewManifest` (Codable, schemaVersion 1, matching contracts/review-manifest.schema.json) in `ScreenPro/Features/Review/Models/ReviewManifest.swift`
- [x] T004 [P] Add `recordedElapsedTime: TimeInterval` to `ScreenPro/Features/Recording/RecordingService.swift` computed from `CMClockGetHostTimeClock()` minus `sessionStartTime`/`recordingStartTime` and `pauseOffset` (research.md R5); freeze value while paused
- [x] T005 [P] Add optional `videoFrameTap: (@Sendable (CMSampleBuffer) -> Void)?` to `ScreenPro/Features/Recording/RecordingService.swift`, invoked from the screen-sample path before writer append; nil outside review sessions; cleared in `cleanup()`
- [x] T006 Create `MicrophoneAudioHub` in `ScreenPro/Core/Services/MicrophoneAudioHub.swift` — owns one `AVAudioEngine` input tap, token-based consumer add/remove of `@Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void`, engine starts with first consumer / stops with last (research.md R4)
- [x] T007 Refactor `setupMicrophoneCapture`/`stopMicrophoneCapture`/`handleMicrophoneBuffer` in `ScreenPro/Features/Recording/RecordingService.swift` to register the asset-writer mic track as a `MicrophoneAudioHub` consumer instead of installing its own tap (behavior-preserving; existing buffer→CMSampleBuffer conversion unchanged)
- [x] T008 [P] Add speech permission to `ScreenPro/Core/Services/PermissionManager.swift`: `speechRecognitionStatus`, `checkSpeechRecognitionPermission()`, `requestSpeechRecognitionPermission() async -> Bool` via `SFSpeechRecognizer.requestAuthorization`, `openSpeechRecognitionPreferences()`
- [x] T009 [P] Add settings fields per data-model.md (`reviewVoiceNotesEnabled`, `reviewTranscriptionLocale`, `reviewBundleIncludesVideo`, `reviewBundleIncludesTranscript`, `reviewShowSummaryBeforeExport`) with CodingKeys and tolerant-decoding entries in `ScreenPro/Core/Services/SettingsManager.swift`
- [x] T010 [P] Add `case reviewFlag` to `ShortcutAction` (displayName "Flag Review Moment") and default ⌃⌥F (keyCode 0x03, `controlKey | optionKey`) to `Shortcut.defaults` in `ScreenPro/Core/Services/ShortcutManager.swift`
- [x] T011 Exclude `.reviewFlag` from startup registration (registered per-session by AppCoordinator, research.md R6): in `ScreenPro/Core/AppCoordinator.swift` shortcut setup, skip `.reviewFlag` in `registerAll`-time registration (add a skip set or register actions individually)
- [x] T012 Create `ReviewFrameBuffer` in `ScreenPro/Features/Review/ReviewFrameBuffer.swift` — consumes `videoFrameTap` samples on the sample queue, deep-copies one frame per ≥ 500 ms into a 5-slot ring (never retains stream buffers), `latestFrame()` and `frame(nearest: TimeInterval)` lookups, `writePNG(to:) async` via ImageIO on a background task (research.md R3)

**Checkpoint**: Project builds; existing recording (incl. mic audio via hub) behaves exactly as before.

## Phase 3: User Story 1 — Flag a moment while recording (P1) 🎯 MVP part 1

**Goal**: Hotkey/button flags create issues with screenshots + timestamps, with an optional non-blocking quick note.
**Independent test**: Start review recording, flag 3×, stop — 3 temp screenshots with correct timestamps exist in the session temp dir (inspect via test hooks before US2 exists).

- [x] T013 [US1] Implement `ReviewSessionService` (manual-flag scope) in `ScreenPro/Features/Review/ReviewSessionService.swift` conforming to `specs/008-review-recording/contracts/ReviewSessionServiceProtocol.swift`: phase machine (inactive/active/suspended/finalizing), `flagCurrentMoment()` stamping `recordedElapsedTime` + grabbing `ReviewFrameBuffer.latestFrame()` + async PNG write to `tmp/ReviewSession-<uuid>/`, `setNote`, `deleteIssue`, `suspend`/`resume` (reject flags while suspended, FR-017), `cancel()` deleting temp dir (FR-016), `finish()` awaiting pending PNG writes (edge case: flag just before stop)
- [x] T014 [US1] Create quick-note panel in `ScreenPro/Features/Review/ReviewNotePanel.swift` — non-activating floating `NSPanel` + SwiftUI text field near the recording controls, appears after a flag, Return commits via `setNote`, Esc/5 s inactivity auto-dismisses keeping the flag (FR-004); VoiceOver label + focus indicator
- [x] T015 [US1] Add review-mode UI to `ScreenPro/Features/Recording/RecordingControlsView.swift`: flag button (`flag.fill`, accessibilityLabel "Flag this moment", hint includes current shortcut) + issue-count badge, shown only when a review session is active; wire new `onFlag` closure
- [x] T016 [US1] Wire AppCoordinator in `ScreenPro/Core/AppCoordinator.swift`: own `reviewSessionService` + `microphoneAudioHub`, add `startReviewRecording()` (video format only — GIF excluded) and `isReviewSession` flag, start session + set `videoFrameTap` after `recordingService.startRecording` succeeds, register `.reviewFlag` hotkey at session start / unregister at stop/cancel, route `.reviewFlag` in `handleShortcutAction` to `reviewSessionService.flagCurrentMoment()` + show `ReviewNotePanel`, propagate pause/resume to `suspend()`/`resume()`, extend `cancelRecording()` to call `reviewSessionService.cancel()`
- [x] T017 [US1] Add "Record Screen (Review Mode)…" menu item invoking `startReviewRecording()` in the menu bar definition (`ScreenPro/Features/MenuBar/` — locate `MenuBarView`/status menu and add alongside existing Record entries)
- [x] T018 [P] [US1] Session lifecycle tests in `ScreenProTests/Review/ReviewSessionLifecycleTests.swift` with a stub frame provider: flag creates issue with correct timestamp, flags rejected while suspended, rapid double-flag yields 2 distinct issues, cancel removes temp dir, finish waits for pending screenshot writes

**Checkpoint**: Review recording can be started, flags accumulate with screenshots; stop still produces a normal recording (bundle comes next).

## Phase 4: User Story 2 — Review Report bundle on stop (P1) 🎯 MVP part 2

**Goal**: Stop produces the bundle folder (video, screenshots, report.md, report.json), surfaced via Quick Access + history.
**Independent test**: Record with 2 flags, stop — bundle contains video, 2 PNGs, report.md referencing both, schema-valid report.json with resolving relative paths.

- [x] T019 [US2] Implement `ReviewReportGenerator` in `ScreenPro/Features/Review/ReviewReportGenerator.swift` per `specs/008-review-recording/contracts/ReviewReportGeneratorProtocol.swift`: create `Review {date} at {time}` folder via `SettingsManager.generateFilename` pattern + `StorageService.uniqueURL`/`ensureDirectoryExists`, move video to `recording.mp4` (when `includeVideo`), copy/rename screenshots to `screenshots/issue-NN.png` (dense chronological numbering), render `report.md` (chronological issues, `MM:SS` timecodes, embedded relative image links, FR-009), encode `report.json` with `JSONEncoder` (ISO 8601 dates, sorted keys) matching `review-manifest.schema.json` (FR-010); on any failure leave the video at its original location and clean partial bundle (edge case)
- [x] T020 [US2] Add stop pipeline to `ScreenPro/Core/AppCoordinator.swift`: on stop of a review session call `reviewSessionService.finish()`, build `ReviewSessionMeta` (recordedAt, duration from result, target descriptor from `recordingRegion`), snapshot `ReviewBundleOptions` from settings, run generator off the main actor; zero issues + empty transcript → existing `handleRecordingResult` path + informational notification (FR-013); generator error → preserve video, show error notification naming what was/wasn't saved
- [x] T021 [US2] Surface the bundle in `ScreenPro/Core/AppCoordinator.swift`: record history entry (`historyStore?.recordRecording` with `fileURL` = bundle folder, thumbnail = first issue screenshot else video thumbnail), push Quick Access item, and add a reveal path (`NSWorkspace.shared.activateFileViewerSelecting([bundleURL])`) so the overlay's save/show action reveals the bundle in Finder (FR-011); announce completion via `AccessibilityAnnouncer`
- [x] T022 [P] [US2] Report generator tests in `ScreenProTests/Review/ReviewReportGeneratorTests.swift`: golden `report.md` output, `report.json` decodes back to `ReviewManifest` and satisfies schema constraints (schemaVersion, relative `screenshots/` paths, dense 1-based indices, timecode format), `includeVideo=false` omits video and sets `videoFile: null`, unwritable destination throws `destinationUnwritable` and leaves the source video intact

**Checkpoint**: MVP complete — record → flag → bundle → hand to an agent.

## Phase 5: User Story 3 — Voice notes with automatic screenshots (P2)

**Goal**: Hands-free narration becomes issues with screenshots from utterance start; strictly on-device.
**Independent test**: Speak two observations with a pause between, stay silent otherwise — exactly two voice issues with transcripts and utterance-start screenshots.

- [x] T023 [P] [US3] Implement pure `UtteranceSegmenter` (struct conforming to `UtteranceSegmenting` from `specs/008-review-recording/contracts/SpeechTranscriptionServiceProtocol.swift`; 1.2 s silence threshold, empty/whitespace utterances discarded, tracks utterance start from first partial) in `ScreenPro/Features/Review/SpeechTranscriptionService.swift`
- [x] T024 [US3] Implement `SpeechTranscriptionService` in `ScreenPro/Features/Review/SpeechTranscriptionService.swift`: `SFSpeechRecognizer` per configured locale (empty → system), `requiresOnDeviceRecognition = true` always, `supportsOnDeviceRecognition` gate (throw → manual-only, never server fallback), long-running `SFSpeechAudioBufferRecognitionRequest` restarted per closed utterance, thread-safe `append(_:)` for hub buffers, 300 ms tick driving the segmenter, `suspend`/`resume`/`stop` (flush open utterance on stop)
- [x] T025 [US3] Integrate voice notes in `ScreenPro/Features/Review/ReviewSessionService.swift`: on `start(voiceNotesEnabled: true)` request speech permission via PermissionManager (denied → `voiceNotesActive = false`, one notification, FR-014), register transcription as `MicrophoneAudioHub` consumer (works with `recordMicrophone` off — narration transcribed but not recorded), each `Utterance` → voice `ReviewIssue` with `ReviewFrameBuffer.frame(nearest: utterance.start)` screenshot + `TranscriptSegment`; implement ±2 s manual-merge window (manual flag absorbs overlapping utterance transcript, no duplicate issue, FR-007); recognizer mid-session failure → notify once, continue manual-only
- [x] T026 [US3] Wire microphone for review sessions in `ScreenPro/Core/AppCoordinator.swift`: when starting a review session with voice notes, ensure mic permission (existing flow) and start `MicrophoneAudioHub` even when `recordMicrophone` is off; update `RecordingControlsView` to show a small waveform/mic indicator while voice notes are active (accessibilityLabel "Voice notes active")
- [x] T027 [P] [US3] Segmentation + merge tests: `ScreenProTests/Review/UtteranceSegmentationTests.swift` (boundary at silence threshold, scripted 10-observation sequence → 10 utterances per SC-006, empty-text discard, flush on stop) and `ScreenProTests/Review/ReviewMergeTests.swift` (utterance within ±2 s of manual flag merges; outside window creates separate issue; silence creates nothing)

**Checkpoint**: Hands-free review works; permission denial degrades gracefully.

## Phase 6: User Story 4 — Review and edit before handoff (P3)

**Goal**: Skippable post-stop summary to fix transcripts and drop accidental flags.
**Independent test**: 3 flags → delete one, edit one → generated report has 2 issues with edited text.

- [x] T028 [P] [US4] Create `ReviewSummaryView` in `ScreenPro/Features/Review/ReviewSummaryView.swift`: chronological list (thumbnail, timecode, source icon, editable note/transcript text), delete with undo within the sheet, "Generate Report" and "Skip" actions; full keyboard navigation + VoiceOver labels (Constitution VI)
- [x] T029 [US4] Create `ReviewSummaryWindowController` in `ScreenPro/Features/Review/ReviewSummaryWindowController.swift` and hook into the stop pipeline in `ScreenPro/Core/AppCoordinator.swift`: shown between `finish()` and generation when `reviewShowSummaryBeforeExport` and issues exist; edits apply via `setNote`/`deleteIssue`; window close = skip = generate as-captured (FR-012)
- [x] T030 [P] [US4] Summary behavior tests in `ScreenProTests/Review/ReviewSessionLifecycleTests.swift` (extend): edits/deletes through the service surface in `finish()` output; deleting all issues routes to the zero-issue path

## Phase 7: User Story 5 — Configure Review Recording (P3)

**Goal**: Settings tab for voice notes, language, hotkey, bundle contents.
**Independent test**: Change hotkey + disable video inclusion → next session flags via new key and bundle omits video.

- [x] T031 [US5] Create `ReviewSettingsTab` in `ScreenPro/Features/Settings/ReviewSettingsTab.swift`: voice notes toggle, transcription language picker (`SFSpeechRecognizer.supportedLocales()` filtered to on-device-capable, "System Language" default), flag-hotkey recorder reusing the existing shortcut-editing control, bundle toggles (include video / include full transcript / show summary); register the tab in `ScreenPro/Features/Settings/SettingsView.swift`
- [x] T032 [US5] Apply settings at session start in `ScreenPro/Core/AppCoordinator.swift` + `ReviewSessionService`: hotkey changes re-register on next session, locale + voice-notes flag read at start, bundle options snapshot at stop (mid-session changes don't tear the bundle)

## Phase 8: Polish & Cross-Cutting

- [ ] T033 [P] Performance benchmark in `ScreenProTests/Review/ReviewPerformanceTests.swift`: frame deep-copy cost at 1080p, flag-path latency budget (SC-001/SC-004), ring memory ceiling; sustained-flag loop (50 flags) asserts no sample-queue blocking (Constitution IV benchmark requirement)
- [x] T034 [P] Manifest schema self-check: embed `specs/008-review-recording/contracts/review-manifest.schema.json` constraints as assertions in `ScreenProTests/Review/ReviewReportGeneratorTests.swift` (no third-party validator — constitution) and verify quickstart.md manual test script steps 1–6 against the build
- [x] T035 Update `CLAUDE.md` Recent Changes with 008-review-recording summary and verify all new files are registered in `ScreenPro.xcodeproj/project.pbxproj` (app target + test target memberships)

## Dependencies & Execution Order

```text
Phase 1 (Setup) ─▶ Phase 2 (Foundational) ─▶ US1 ─▶ US2 ─▶ US3 ─▶ US4 ─▶ US5 ─▶ Polish
```

- **US1 → US2**: bundle needs issues to exist (US2 consumes `ReviewSessionOutput`).
- **US3** layers onto US1's session service and US2's report (transcripts appear in bundle) but its segmenter (T023) can be built in parallel any time after Phase 2.
- **US4/US5** are independent of each other; both need US2's stop pipeline.
- Within phases, `[P]` tasks touch disjoint files and can run concurrently — e.g., Phase 2: T003/T004/T005/T008/T009/T010 in parallel, then T006→T007, T011, T012.

## Implementation Strategy

**MVP = Phase 1 + Phase 2 + US1 + US2** (T001–T022): record → flag → bundle → agent handoff. Ship/validate that, then add voice (US3) as the differentiator, then summary + settings (US4/US5), then polish.

| Story | Tasks | Count |
|---|---|---|
| Setup | T001–T002 | 2 |
| Foundational | T003–T012 | 10 |
| US1 (P1) | T013–T018 | 6 |
| US2 (P1) | T019–T022 | 4 |
| US3 (P2) | T023–T027 | 5 |
| US4 (P3) | T028–T030 | 3 |
| US5 (P3) | T031–T032 | 2 |
| Polish | T033–T035 | 3 |
| **Total** | | **35** |
