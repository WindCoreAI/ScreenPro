# Feature Specification: Basic Screenshot Capture

**Feature Branch**: `002-basic-capture`
**Created**: 2025-12-22
**Status**: Draft
**Input**: User description: "Implement basic screenshot capture functionality including area, window, and fullscreen capture based on milestone 02-basic-capture.md"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Area Screenshot Capture (Priority: P1)

As a user, I want to capture a specific rectangular region of my screen so that I can share only the relevant portion of my display without including unnecessary content.

**Why this priority**: Area capture is the most frequently used screenshot mode, providing users with precise control over what they capture. This is the fundamental screenshot operation users expect.

**Independent Test**: Can be fully tested by triggering area capture, selecting a region on screen, and verifying the captured image matches the selected area dimensions and content.

**Acceptance Scenarios**:

1. **Given** the app is running with screen recording permission granted, **When** I trigger area capture via menu or keyboard shortcut, **Then** a full-screen selection overlay appears with a crosshair cursor.
2. **Given** the selection overlay is visible, **When** I click and drag to select a region, **Then** the selection area is highlighted with a border and corner handles, and dimensions (width x height) are displayed in real-time.
3. **Given** I have selected a region on screen, **When** I release the mouse button, **Then** the selected area is captured as an image, the overlay closes, and the capture is saved to file and copied to clipboard.
4. **Given** the selection overlay is visible, **When** I press the Escape key, **Then** the selection is cancelled and the overlay closes without capturing.
5. **Given** I am selecting an area, **When** the selection is less than 5x5 pixels, **Then** the capture is cancelled (prevents accidental micro-captures).

---

### User Story 2 - Window Screenshot Capture (Priority: P1)

As a user, I want to capture a specific application window so that I can quickly capture complete windows without manually aligning a selection.

**Why this priority**: Window capture is equally critical as area capture, enabling users to capture application windows cleanly with proper boundaries.

**Independent Test**: Can be fully tested by triggering window capture, hovering over and clicking a window, and verifying the captured image contains only that window's content.

**Acceptance Scenarios**:

1. **Given** the app is running with screen recording permission granted, **When** I trigger window capture via menu or keyboard shortcut, **Then** a window selection mode activates where I can hover over windows.
2. **Given** window selection mode is active, **When** I hover over an application window, **Then** the window is visually highlighted to indicate it will be captured.
3. **Given** a window is highlighted, **When** I click on it, **Then** the window is captured as an image, the selection mode closes, and the capture is saved to file and copied to clipboard.
4. **Given** window selection mode is active, **When** I press the Escape key, **Then** the selection is cancelled without capturing.
5. **Given** window selection mode is active, **When** I hover over the app's own windows or system windows smaller than 50x50 pixels, **Then** they are excluded from selection.

---

### User Story 3 - Fullscreen Screenshot Capture (Priority: P1)

As a user, I want to capture my entire screen quickly so that I can document my complete desktop state with a single action.

**Why this priority**: Fullscreen capture is the simplest capture mode and essential for capturing complete screen states. It requires no user interaction after triggering.

**Independent Test**: Can be fully tested by triggering fullscreen capture and verifying the captured image matches the full display dimensions and content.

**Acceptance Scenarios**:

1. **Given** the app is running with screen recording permission granted, **When** I trigger fullscreen capture via menu or keyboard shortcut, **Then** the entire main display is captured immediately.
2. **Given** a fullscreen capture completes, **Then** the captured image has the correct resolution matching the display's native resolution (accounting for Retina scaling).
3. **Given** the capture is successful, **Then** an audio feedback sound plays (if enabled in settings) and the image is saved to the configured location and copied to clipboard.

---

### User Story 4 - Capture Audio Feedback (Priority: P2)

As a user, I want to hear an audio confirmation when a screenshot is taken so that I have clear feedback that the capture was successful.

**Why this priority**: Audio feedback provides important user feedback but is not essential to the core capture functionality.

**Independent Test**: Can be tested by enabling capture sound in settings, taking a screenshot, and verifying the system "Grab" sound plays.

**Acceptance Scenarios**:

1. **Given** capture sound is enabled in settings, **When** any screenshot capture completes successfully, **Then** the macOS "Grab" sound plays.
2. **Given** capture sound is disabled in settings, **When** any screenshot capture completes, **Then** no sound plays.

---

### User Story 5 - Multi-Monitor Support (Priority: P2)

As a user with multiple displays, I want captures to work correctly across all my monitors so that I can capture content from any screen.

**Why this priority**: Multi-monitor support extends the core functionality to professional users with complex setups.

**Independent Test**: Can be tested on a multi-monitor setup by capturing content from each display and verifying correct resolution and positioning.

**Acceptance Scenarios**:

1. **Given** I have multiple monitors connected, **When** I trigger area capture, **Then** the selection overlay appears on the screen where my cursor is located.
2. **Given** multiple monitors are connected, **When** I perform fullscreen capture, **Then** the main display (or display containing the cursor) is captured.
3. **Given** windows span multiple monitors, **When** I use window capture, **Then** windows from all displays are available for selection.

---

### Edge Cases

- What happens when screen recording permission is not granted? The app should request permission and prevent capture until granted.
- How does the system handle very large selections (e.g., 8K display)? The system should capture at native resolution using appropriate scaling.
- What happens if the user tries to capture while another capture is in progress? The new capture request should be queued or ignored to prevent conflicts.
- How are areas that span multiple monitors handled in area capture? The capture should include content from all intersecting displays.
- What happens if a window is minimized or hidden during window selection? The window should not appear in the selection list (only on-screen windows are shown).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide area capture mode where users can select a rectangular region by clicking and dragging.
- **FR-002**: System MUST display a crosshair cursor during area selection that extends to screen edges for alignment reference.
- **FR-003**: System MUST show real-time dimensions (width x height in pixels) of the selected area during selection.
- **FR-004**: System MUST display corner handles on the selection rectangle to indicate the selected region boundaries.
- **FR-005**: System MUST provide window capture mode where users can click on any visible window to capture it.
- **FR-006**: System MUST highlight windows visually when hovered during window selection mode.
- **FR-007**: System MUST filter out system windows, the app's own windows, and windows smaller than 50x50 pixels from window selection.
- **FR-008**: System MUST provide fullscreen capture mode that captures the entire display with a single action.
- **FR-009**: System MUST capture images at native display resolution (Retina-aware with appropriate scaling factor).
- **FR-010**: System MUST automatically save captured images to the user's configured save location.
- **FR-011**: System MUST automatically copy captured images to the system clipboard after capture.
- **FR-012**: System MUST play the macOS "Grab" sound upon successful capture (when enabled in settings).
- **FR-013**: System MUST support cancellation of capture operations via the Escape key.
- **FR-014**: System MUST display instructional text on the selection overlay (e.g., "Click and drag to select an area").
- **FR-015**: System MUST integrate with AppCoordinator state machine to manage capture flow states.
- **FR-016**: System MUST support multiple monitors by showing selection overlays on the appropriate display.
- **FR-017**: System MUST use file naming patterns configured in settings for saved screenshots.
- **FR-018**: System MUST use the image format (PNG, JPEG, TIFF) configured in settings.
- **FR-019**: System MUST include or exclude cursor in captures based on user settings.

### Key Entities

- **CaptureService**: Core service managing screenshot operations, content discovery, and image output.
- **CaptureResult**: Data structure containing the captured image, metadata (timestamp, source rect, capture mode), and unique identifier.
- **SelectionWindow/SelectionOverlayView**: Full-screen overlay window for area selection with crosshair, dimensions, and selection rectangle.
- **WindowPickerController**: Controller for window selection mode including highlight and selection logic.
- **DisplayManager**: Utility for managing multiple display configurations and coordinate conversions.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can capture a screen region from trigger to image saved in under 500 milliseconds (excluding user selection time).
- **SC-002**: Area selection dimensions display updates in real-time with no perceptible lag during mouse movement.
- **SC-003**: Captured images match the exact pixel dimensions of the selected area at native Retina resolution.
- **SC-004**: Window highlight appears within 50 milliseconds of hovering over a selectable window.
- **SC-005**: All three capture modes (area, window, fullscreen) function correctly on systems with 1-4 connected displays.
- **SC-006**: Captured images are simultaneously available in the filesystem and clipboard immediately after capture.
- **SC-007**: Users can successfully cancel any capture operation using Escape key 100% of the time.
- **SC-008**: Selection overlay does not interfere with other application windows while visible.
