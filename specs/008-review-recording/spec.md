# Feature Specification: Review Recording

**Feature Branch**: `008-review-recording`
**Created**: 2026-06-12
**Status**: Draft
**Input**: User description: "Review Mode recording for design/QA feedback that feeds agentic coding workflows. While recording a product under review, the reviewer talks about what they see; ScreenPro transcribes speech on-device, creates a review note per spoken observation, and automatically captures a screenshot at that moment from the live recording stream. The reviewer can also flag moments via hotkey or controls button. When recording stops, ScreenPro generates a Review Report bundle (video, screenshots, Markdown report, machine-readable JSON manifest) designed to feed directly into an agentic coding framework."

## Problem Statement

Teams that build software with AI coding agents spend significant human time on the review loop: a person opens the built artifact (web app, mobile app, desktop UI), explores it, finds UX/UI/design issues, and must then manually take screenshots, write up each issue, organize the evidence, and hand it back to developers or a coding agent. This is slow, error-prone, and lossy — the reviewer's spoken, in-the-moment observations are the richest signal, and today they are discarded.

ScreenPro already records the screen with microphone audio. Review Recording turns that recording session into a structured feedback artifact: the reviewer simply narrates while using the product, and ScreenPro produces a ready-to-consume review report — each issue paired with a screenshot of exactly what the reviewer was looking at when they said it — that a human or coding agent can act on immediately.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Flag a moment while recording (Priority: P1)

A reviewer starts a Review Recording of the product under test. While recording, whenever they notice something that needs improvement, they press a flag hotkey (or click a flag button on the recording controls). ScreenPro instantly captures a screenshot of the recorded content at that moment and registers a review note with its timestamp. The reviewer keeps working without interruption; they can optionally type a short note for the flag right after pressing it.

**Why this priority**: This is the core capture mechanic and works even without speech transcription (e.g., muted environments, unsupported languages). It alone replaces the manual "pause, screenshot, write it down" workflow and is the smallest slice that delivers the feature's value.

**Independent Test**: Start a Review Recording, press the flag hotkey three times at different moments, stop recording. Verify three screenshots exist, each matching what was on screen at flag time, each with a correct timestamp.

**Acceptance Scenarios**:

1. **Given** a Review Recording is in progress, **When** the reviewer presses the flag hotkey, **Then** a screenshot of the recorded region at that instant is captured and a review note with the recording timestamp is created, without interrupting the recording.
2. **Given** a Review Recording is in progress, **When** the reviewer clicks the flag button on the recording controls, **Then** the same flag behavior occurs as with the hotkey.
3. **Given** a flag was just created, **When** the reviewer types a quick note in the unobtrusive note field that appears, **Then** the text is attached to that flag; **and When** the reviewer ignores the field, **Then** the flag is kept with no typed note and the field disappears on its own.
4. **Given** an ordinary (non-Review) recording is in progress, **When** the reviewer presses the flag hotkey, **Then** nothing is captured (flagging is exclusive to Review Recordings).

---

### User Story 2 - Generate a Review Report bundle on stop (Priority: P1)

When the reviewer stops a Review Recording, ScreenPro assembles everything into a single Review Report bundle: a folder containing the recorded video, all flagged screenshots, a human-readable report listing each issue (screenshot, timestamp, note/transcript), and a machine-readable manifest that an agentic coding tool can consume directly. The bundle is saved to the user's configured location and offered through the usual post-capture flow.

**Why this priority**: The report is the deliverable — without it, flags are trapped inside ScreenPro. Together with Story 1 this forms the MVP loop: record → flag → hand off.

**Independent Test**: Record with two flags, stop. Verify the bundle folder contains the video, two screenshots, a Markdown report referencing both screenshots with timestamps and notes, and a JSON manifest whose entries resolve to the screenshot files.

**Acceptance Scenarios**:

1. **Given** a Review Recording with at least one flag, **When** the reviewer stops recording, **Then** a bundle folder is created containing the video file, one image file per flag, a human-readable report, and a machine-readable manifest.
2. **Given** the bundle was created, **When** the reviewer opens the human-readable report, **Then** each issue appears in chronological order with its screenshot, its timestamp into the video, and its note and/or transcribed speech.
3. **Given** the bundle was created, **When** a coding agent reads the machine-readable manifest, **Then** it can resolve every screenshot by relative path within the bundle and read each issue's timestamp, note text, and transcript without any other context.
4. **Given** a Review Recording with zero flags and no transcript, **When** the reviewer stops recording, **Then** ScreenPro saves the recording as a normal recording and informs the reviewer that no review report was generated.
5. **Given** the bundle was created, **When** the post-capture overlay appears, **Then** the reviewer can reveal the bundle in Finder from there.

---

### User Story 3 - Voice notes with automatic screenshots (Priority: P2)

While a Review Recording is running, the reviewer narrates what they see ("this button is misaligned", "the empty state needs better copy"). ScreenPro transcribes the microphone audio on-device in real time. Each contiguous spoken observation becomes a review note automatically: the note carries the transcribed text, and a screenshot is captured at the moment the observation began. The reviewer never touches the keyboard.

**Why this priority**: This is the "perfect UX" the feature aims for — hands-free review. It layers on top of Story 1's flag/screenshot machinery and Story 2's report, so it is sequenced after them, but it is the differentiator.

**Independent Test**: Start a Review Recording with voice notes enabled, speak two separate observations with a clear pause between them, stay silent otherwise, stop. Verify the report contains exactly two voice-originated issues, each with the spoken text and a screenshot from the moment the utterance began.

**Acceptance Scenarios**:

1. **Given** voice notes are enabled and a Review Recording is in progress, **When** the reviewer speaks an observation and then pauses, **Then** a review note is created containing the transcribed text and a screenshot captured at the start of the utterance.
2. **Given** the reviewer is silent, **When** no speech occurs, **Then** no notes are created (silence and background noise do not generate flags).
3. **Given** speech recognition permission has not been granted, **When** the reviewer starts a Review Recording, **Then** ScreenPro asks for permission; **and When** permission is denied, **Then** the Review Recording proceeds with hotkey flagging only and the reviewer is told voice notes are unavailable.
4. **Given** transcription is active, **When** the recording is in progress, **Then** all audio processing happens on the device and no audio or transcript leaves the machine.
5. **Given** a hotkey flag was pressed while the reviewer was mid-sentence, **When** the report is generated, **Then** the spoken text around the flag moment is attached to that flag rather than producing a duplicate issue.

---

### User Story 4 - Review and edit before handoff (Priority: P3)

After stopping, the reviewer sees a review summary where they can scan all captured issues, fix transcription mistakes, delete accidental flags, and edit notes before the final report is written.

**Why this priority**: Improves report quality but is not required for the loop to function — the raw report is already usable.

**Independent Test**: Record with three flags, stop, delete one issue and edit another's text in the summary, confirm. Verify the generated report contains two issues with the edited text.

**Acceptance Scenarios**:

1. **Given** a Review Recording just stopped, **When** the review summary opens, **Then** every captured issue is listed with its screenshot thumbnail, timestamp, and text.
2. **Given** the summary is open, **When** the reviewer edits an issue's text or deletes an issue and confirms, **Then** the generated bundle reflects those changes.
3. **Given** the summary is open, **When** the reviewer skips it (closes without changes), **Then** the bundle is generated with the issues as captured.

---

### User Story 5 - Configure Review Recording (Priority: P3)

The reviewer can configure the feature in Settings: enable/disable voice notes, choose the transcription language, set the flag hotkey, and choose what the bundle includes (e.g., whether to include the full video, full session transcript).

**Why this priority**: Sensible defaults make this optional for first use; configuration broadens applicability (languages, hotkey conflicts, storage concerns).

**Independent Test**: Change the flag hotkey and disable video inclusion in Settings, run a review session. Verify the new hotkey flags moments and the resulting bundle omits the video.

**Acceptance Scenarios**:

1. **Given** Settings is open, **When** the reviewer changes the flag hotkey, **Then** the new hotkey takes effect for the next Review Recording.
2. **Given** voice notes are disabled in Settings, **When** a Review Recording runs, **Then** no microphone transcription occurs and only manual flags create issues.
3. **Given** a transcription language is selected, **When** the reviewer narrates in that language, **Then** notes are transcribed in that language.

---

### Edge Cases

- Reviewer stops the recording within a second of pressing a flag: the flag's screenshot must still be captured and included.
- Recording is cancelled (not stopped): all flags, screenshots, and transcripts for the session are discarded.
- Recording is paused: flags and transcription are suspended while paused and resume cleanly; timestamps remain relative to recorded (not wall-clock) time.
- Disk runs out of space or the save location is unwritable during bundle generation: the video is preserved if possible and the reviewer gets a clear error telling them what was and wasn't saved.
- Very long session (e.g., 60+ minutes) with many flags (e.g., 100+): flagging must not degrade recording smoothness; report generation may take time but must complete.
- Two flags pressed in rapid succession (under a second apart): both produce distinct issues with distinct screenshots.
- Speech recognizer becomes unavailable mid-session (e.g., language asset missing): the session continues with manual flags; the reviewer is notified once, not repeatedly.
- GIF-format recording: Review Recording applies to video recordings; if the user starts a GIF recording, review mode is not offered.
- Microphone transcription while "record microphone audio" is off: the reviewer's narration must still be transcribed without their voice ending up in the video's audio track.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Users MUST be able to start a screen recording in a distinct "Review" mode, alongside existing recording modes, for any recordable region (display, window, area).
- **FR-002**: During a Review Recording, users MUST be able to flag the current moment via a configurable global hotkey and via a button on the on-screen recording controls.
- **FR-003**: Each flag MUST capture a still image of the recorded content at the flagged moment and record the elapsed recording time, without pausing or visibly disturbing the recording.
- **FR-004**: After flagging, users MUST be offered a non-blocking way to type a short note attached to that flag; ignoring it MUST cost no interaction.
- **FR-005**: When enabled, the system MUST transcribe the reviewer's microphone speech in real time during a Review Recording, entirely on-device, and segment it into discrete spoken observations.
- **FR-006**: Each spoken observation MUST automatically produce a review note containing its transcript and a still image captured at the start of the utterance.
- **FR-007**: A spoken observation overlapping a manual flag MUST be merged into that flag's note rather than creating a duplicate issue.
- **FR-008**: On stop, the system MUST generate a Review Report bundle: one folder containing the video, all issue screenshots, a human-readable Markdown report, and a machine-readable JSON manifest.
- **FR-009**: The Markdown report MUST present issues chronologically, each with embedded screenshot reference, timestamp into the video, typed note, and transcript.
- **FR-010**: The JSON manifest MUST be self-contained: session metadata (date, duration, recorded target) and per-issue id, timestamp, source (manual/voice), note text, transcript, and screenshot path relative to the bundle — consumable by an agentic coding tool without additional context.
- **FR-011**: The bundle MUST be saved under the user's configured save location, appear in capture history, and be offered through the post-capture overlay with a "reveal in Finder" action.
- **FR-012**: Users MUST be able to review, edit, and delete captured issues in a summary step before the bundle is finalized, and MUST be able to skip this step.
- **FR-013**: A Review Recording with no issues and no transcript MUST degrade to a normal recording save, with the user informed.
- **FR-014**: Speech recognition MUST require explicit user permission; denial MUST leave manual flagging fully functional.
- **FR-015**: Settings MUST expose: voice notes on/off, transcription language, flag hotkey, and bundle content options (include video, include full transcript); all persisted across launches.
- **FR-016**: Cancelling a recording MUST discard all session flags, screenshots, and transcripts.
- **FR-017**: Pausing a recording MUST suspend flagging and transcription; timestamps MUST reflect recorded time, excluding paused intervals.
- **FR-018**: No audio, transcript, or screenshot from a review session may be transmitted off the device by this feature.

### Key Entities

- **Review Session**: The in-progress review context attached to one recording; holds the ordered set of review issues and the running transcript; exists only between start and stop/cancel.
- **Review Issue**: One observation; attributes: unique id, timestamp into recording, source (manual flag / voice), optional typed note, optional transcript text, captured screenshot.
- **Review Report Bundle**: The durable output folder; contains the video, screenshot images, human-readable report, machine-readable manifest; identified by session date/name.
- **Review Settings**: User preferences governing the feature (voice notes enabled, language, hotkey, bundle contents).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A reviewer can capture a flagged issue (screenshot + timestamp) with a single keypress in under 1 second of interaction, without leaving the product under review.
- **SC-002**: For a 10-minute review session with 10 issues, the complete handoff artifact is ready within 30 seconds of stopping the recording — versus the multi-step manual screenshot/write-up workflow it replaces.
- **SC-003**: Flagging and voice transcription cause no perceptible recording degradation: recorded video remains smooth (no dropped-frame stutter attributable to flagging) in a 30-minute session with 50 flags.
- **SC-004**: 95% of flag screenshots show the content that was on screen within ≤ 0.5 s of the flag action.
- **SC-005**: A coding agent given only the bundle folder can enumerate every issue with its screenshot and description with zero manual preprocessing (validated by feeding a bundle to an agent and confirming it addresses each listed issue).
- **SC-006**: Voice-originated notes correctly segment distinct observations: in a scripted 10-observation narration test, at least 9 produce exactly one issue each.
- **SC-007**: Zero network transmissions of audio, transcripts, or screenshots attributable to this feature (verifiable by network monitoring during a session).

## Assumptions

- Review Recording applies to video recordings only; GIF mode is out of scope.
- Voice notes default to enabled (with permission prompt on first use); transcription language defaults to the system language when supported.
- Utterance segmentation by natural pauses in speech is the default voice-note boundary; explicit voice command triggers ("flag this") are out of scope for this feature.
- The bundle lives in a plain folder (not an opaque package) so external tools and agents can read it directly.
- Automatic submission of the bundle to a coding agent (e.g., invoking Claude Code) is out of scope; the bundle's manifest format is the integration contract.
- Editing screenshots (annotation) from the review summary reuses the existing annotation editor and is a nice-to-have, not required for this feature.
- Existing microphone permission flow covers audio capture; speech recognition permission is an additional, separate grant.
