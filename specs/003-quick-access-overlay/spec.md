# Feature Specification: Quick Access Overlay

**Feature Branch**: `003-quick-access-overlay`
**Created**: 2025-12-22
**Status**: Draft
**Input**: User description: "Implement the floating thumbnail overlay that appears after capture, providing quick actions and drag-and-drop functionality"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Capture Preview (Priority: P1)

As a user who just took a screenshot, I want to see a preview thumbnail immediately so I can verify I captured the correct content without navigating to another location.

**Why this priority**: This is the core value proposition of the Quick Access Overlay - providing immediate visual feedback after capture. Without this, users have no way to interact with their capture through the overlay.

**Independent Test**: Can be fully tested by taking any screenshot and verifying a floating thumbnail appears showing the captured content. Delivers instant visual confirmation of capture success.

**Acceptance Scenarios**:

1. **Given** a user has just completed any type of capture (area, window, or fullscreen), **When** the capture completes successfully, **Then** a floating thumbnail overlay appears within 200ms showing a preview of the captured image
2. **Given** the Quick Access Overlay is visible, **When** the user views the thumbnail, **Then** the thumbnail displays the captured content at a recognizable size (approximately 120x80 pixels) with image dimensions shown
3. **Given** the overlay is displayed, **When** no user interaction occurs, **Then** the overlay remains visible until the user interacts or the configurable auto-dismiss timer expires

---

### User Story 2 - Quick Copy to Clipboard (Priority: P1)

As a user who wants to share my screenshot quickly, I want to copy it to the clipboard with a single action so I can immediately paste it into another application.

**Why this priority**: Copy to clipboard is the most frequent action users perform with screenshots. It enables the fastest workflow for sharing captures.

**Independent Test**: Can be tested by capturing a screenshot, clicking the copy button, and pasting into any application that accepts images. Delivers immediate sharing capability.

**Acceptance Scenarios**:

1. **Given** the Quick Access Overlay is visible with a capture, **When** I hover over the thumbnail, **Then** action buttons become visible including a Copy button
2. **Given** action buttons are visible, **When** I click the Copy button or press Cmd+C, **Then** the image is copied to the system clipboard and the capture is removed from the overlay
3. **Given** the image was copied to clipboard, **When** I paste in another application, **Then** the full-resolution captured image is pasted correctly

---

### User Story 3 - Quick Save to Disk (Priority: P1)

As a user who wants to keep my screenshot, I want to save it to my configured location with one click so I can preserve it without additional steps.

**Why this priority**: Saving to disk is a fundamental capture workflow. Users need a quick way to persist their captures to their preferred location.

**Independent Test**: Can be tested by capturing a screenshot, clicking the save button, and verifying the file appears in the configured save location. Delivers permanent storage of captures.

**Acceptance Scenarios**:

1. **Given** action buttons are visible on the overlay, **When** I click the Save button or press Cmd+S, **Then** the capture is saved to my configured default save location
2. **Given** a capture is being saved, **When** the save completes, **Then** the capture is removed from the overlay queue
3. **Given** saving fails (e.g., disk full, permissions), **When** the error occurs, **Then** an appropriate error message is displayed to the user

---

### User Story 4 - Drag and Drop to Applications (Priority: P1)

As a user who wants to insert my screenshot directly into another application, I want to drag the thumbnail from the overlay and drop it into my target app so I can work with it immediately.

**Why this priority**: Drag and drop is a natural macOS interaction pattern that enables seamless workflows. It allows users to directly move captures into documents, messages, or design tools.

**Independent Test**: Can be tested by capturing a screenshot and dragging the thumbnail into Finder, a text document, or an image editor. Delivers native app integration.

**Acceptance Scenarios**:

1. **Given** the Quick Access Overlay is visible with a capture, **When** I click and drag the thumbnail, **Then** a drag operation begins with a visual preview of the image
2. **Given** I am dragging a capture thumbnail, **When** I drop it into Finder, **Then** a PNG file is created at the drop location
3. **Given** I am dragging a capture thumbnail, **When** I drop it into an application that accepts images (e.g., Slack, Pages, Figma), **Then** the image is inserted into that application
4. **Given** a drag operation completes successfully, **When** the drop is accepted by the target, **Then** the capture remains in the overlay queue (not automatically dismissed)

---

### User Story 5 - Dismiss Capture (Priority: P1)

As a user who captured the wrong content or no longer needs a capture, I want to dismiss it quickly so it doesn't clutter the overlay or waste storage.

**Why this priority**: Users frequently need to discard unwanted captures. Quick dismissal keeps the workflow clean and prevents accidental saves of unwanted content.

**Independent Test**: Can be tested by capturing a screenshot and clicking the close button or pressing Escape. Delivers immediate cleanup capability.

**Acceptance Scenarios**:

1. **Given** the Quick Access Overlay is visible, **When** I click the Close button on a capture item, **Then** that capture is removed from the overlay without saving
2. **Given** the Quick Access Overlay is visible with a single capture, **When** I press Escape, **Then** the capture is dismissed and the overlay hides
3. **Given** multiple captures are queued, **When** I dismiss one capture, **Then** only that capture is removed and remaining captures stay visible

---

### User Story 6 - Open in Annotation Editor (Priority: P2)

As a user who wants to mark up my screenshot, I want to open it in the annotation editor directly from the overlay so I can add annotations before sharing.

**Why this priority**: While important for power users, annotation is a secondary workflow that builds upon the basic capture-and-share flow. Users can still manually open captures for editing if this isn't available.

**Independent Test**: Can be tested by capturing a screenshot and clicking the Annotate button, verifying the annotation editor opens with the capture loaded.

**Acceptance Scenarios**:

1. **Given** action buttons are visible on the overlay, **When** I click the Annotate button or press Return/Enter, **Then** the annotation editor opens with my captured image
2. **Given** I opened a capture in the annotation editor, **When** the editor opens, **Then** the capture is removed from the overlay queue

---

### User Story 7 - Manage Multiple Captures (Priority: P2)

As a user who takes multiple screenshots in succession, I want the overlay to queue my captures so I can act on each one without losing any.

**Why this priority**: Multi-capture workflows are common in documentation and comparison tasks. However, single-capture workflows are more frequent, making this a secondary priority.

**Independent Test**: Can be tested by taking 3+ screenshots rapidly and verifying all appear stacked in the overlay. Delivers batch capture capability.

**Acceptance Scenarios**:

1. **Given** the Quick Access Overlay is visible with one capture, **When** I take another screenshot, **Then** the new capture is added to the top of the queue and both are visible
2. **Given** multiple captures are queued, **When** I view the overlay, **Then** captures are displayed in a vertical stack with the most recent at the top
3. **Given** multiple captures are visible, **When** I click on any capture's action buttons, **Then** that specific capture is acted upon
4. **Given** the maximum visible captures (5) is reached, **When** more captures are taken, **Then** the overlay scrolls or shows indication of additional captures

---

### User Story 8 - Keyboard Navigation (Priority: P2)

As a power user who prefers keyboard shortcuts, I want to navigate and act on captures using only my keyboard so I can work efficiently without reaching for the mouse.

**Why this priority**: Keyboard navigation improves accessibility and power user efficiency, but mouse interaction covers the majority of use cases.

**Independent Test**: Can be tested by taking screenshots and using arrow keys to navigate, Cmd+C to copy, Cmd+S to save. Delivers keyboard-only workflow.

**Acceptance Scenarios**:

1. **Given** the Quick Access Overlay is visible with the focus, **When** I press Up/Down arrow keys, **Then** the selection moves between queued captures with visual indication
2. **Given** a capture is selected, **When** I press Cmd+C, **Then** the selected capture is copied to clipboard
3. **Given** a capture is selected, **When** I press Cmd+S, **Then** the selected capture is saved to disk
4. **Given** a capture is selected, **When** I press Escape, **Then** the selected capture is dismissed

---

### User Story 9 - Configure Overlay Position (Priority: P3)

As a user who has their own screen layout preferences, I want to choose which corner the overlay appears in so it doesn't obstruct my important screen areas.

**Why this priority**: Position customization is a nice-to-have that improves user experience for specific workflows but doesn't block core functionality. Default bottom-left works for most users.

**Independent Test**: Can be tested by changing the overlay position setting and taking a screenshot, verifying the overlay appears in the selected corner.

**Acceptance Scenarios**:

1. **Given** I am in the app preferences, **When** I select a different corner position (bottom-left, bottom-right, top-left, top-right), **Then** subsequent captures show the overlay in my selected corner
2. **Given** the overlay is displayed, **When** I move it by dragging, **Then** the overlay repositions (per-session, not persisted)

---

### User Story 10 - Auto-Dismiss After Timeout (Priority: P3)

As a user who sometimes forgets to dismiss captures, I want the overlay to automatically disappear after a period of inactivity so my screen stays clean.

**Why this priority**: Auto-dismiss is a convenience feature that prevents screen clutter but is not essential for core capture workflows.

**Independent Test**: Can be tested by capturing a screenshot and waiting for the configured timeout period without interaction. Delivers automatic cleanup.

**Acceptance Scenarios**:

1. **Given** the overlay is visible and auto-dismiss is enabled with a timeout, **When** no user interaction occurs for the timeout duration, **Then** all captures in the queue are dismissed
2. **Given** the auto-dismiss timer is running, **When** I hover over the overlay, **Then** the timer is paused/reset
3. **Given** auto-dismiss is disabled (timeout = 0), **When** the overlay is displayed, **Then** it remains visible until manually dismissed

---

### Edge Cases

- What happens when the configured save location becomes unavailable (e.g., external drive disconnected)?
  - Display error message and keep capture in queue for retry or alternative action
- How does the overlay behave on multiple displays?
  - Overlay appears on the screen where the capture occurred
- What happens when the system enters sleep mode with captures in queue?
  - Captures remain in queue after wake; no auto-save occurs
- How does the overlay handle very large captures (e.g., 8K resolution)?
  - Thumbnail is generated at reduced resolution (max 300px longest side); full resolution preserved for actions
- What happens if copy to clipboard fails (e.g., extremely large image)?
  - Display error message; capture remains in queue for alternative action

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display a floating thumbnail overlay within 200ms after any successful screenshot capture
- **FR-002**: System MUST show a thumbnail preview that maintains the aspect ratio of the captured image
- **FR-003**: System MUST display capture dimensions (width x height in pixels) for each queued capture
- **FR-004**: System MUST show relative timestamp for each capture (e.g., "Just now", "2m ago")
- **FR-005**: System MUST provide a Copy action that copies the full-resolution image to the system clipboard
- **FR-006**: System MUST provide a Save action that saves the image to the user's configured default location
- **FR-007**: System MUST provide an Annotate action that opens the capture in the annotation editor
- **FR-008**: System MUST provide a Dismiss/Close action that removes the capture from the queue without saving
- **FR-009**: System MUST support drag-and-drop of thumbnails to other applications
- **FR-010**: Drag operations MUST provide the image as both NSImage and PNG data for maximum compatibility
- **FR-011**: System MUST queue multiple captures when taken in succession, displaying them in a vertical stack
- **FR-012**: System MUST support keyboard shortcuts (Cmd+C, Cmd+S, Cmd+A, Escape, Arrow keys)
- **FR-013**: System MUST visually indicate which capture is currently selected when using keyboard navigation
- **FR-014**: System MUST support configurable overlay position (four corners of the screen)
- **FR-015**: System MUST support configurable auto-dismiss timeout (including disabled option)
- **FR-016**: System MUST pause the auto-dismiss timer when the user hovers over the overlay
- **FR-017**: System MUST remain visible across macOS Spaces (virtual desktops)
- **FR-018**: System MUST allow the overlay window to be dragged by the user within the current session
- **FR-019**: Action buttons MUST be revealed on hover over a capture item
- **FR-020**: System MUST remove a capture from the queue after successfully completing Copy, Save, or Annotate actions

### Key Entities

- **CaptureItem**: Represents a single screenshot in the queue
  - Unique identifier
  - Full-resolution image data
  - Thumbnail image (scaled for display)
  - Capture timestamp
  - Dimensions (width, height)
  - Relationship to original CaptureResult from CaptureService

- **CaptureQueue**: Manages the ordered collection of pending captures
  - Ordered list of CaptureItems (newest first)
  - Selected item index for keyboard navigation
  - Maximum capacity for visible items

- **OverlaySettings**: User preferences for overlay behavior
  - Screen corner position (bottom-left, bottom-right, top-left, top-right)
  - Auto-dismiss timeout duration
  - Show/hide Quick Access overlay toggle

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Overlay appears within 200ms of capture completion (measured from capture complete to overlay visible)
- **SC-002**: Users can complete copy-to-clipboard action in under 2 seconds from capture completion
- **SC-003**: Users can complete save-to-disk action in under 2 seconds from capture completion
- **SC-004**: Drag-and-drop operations work with at least 95% of common macOS applications (Finder, Mail, Messages, Slack, Pages, etc.)
- **SC-005**: System supports queuing at least 10 captures without performance degradation
- **SC-006**: Overlay memory footprint stays under 50MB with 5 captures in queue
- **SC-007**: All keyboard shortcuts are discoverable via tooltips on hover
- **SC-008**: 90% of users can successfully complete their intended action (copy/save/annotate) on first attempt without instructions
