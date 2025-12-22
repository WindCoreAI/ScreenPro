# Feature Specification: Project Setup & Core Infrastructure

**Feature Branch**: `001-project-setup`
**Created**: 2025-12-22
**Status**: Draft
**Input**: User description: "Project Setup and Core Infrastructure for ScreenPro macOS Application focusing on Milestone 1"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Launch and Access App via Menu Bar (Priority: P1)

A user installs ScreenPro and wants to quickly access screenshot and recording features from any application without switching contexts. They expect the app to run silently in the background and be accessible through the macOS menu bar.

**Why this priority**: This is the foundational user experience - without menu bar presence and basic accessibility, no other features can be used. This represents the minimum viable product for user interaction.

**Independent Test**: Can be fully tested by launching the app and verifying the menu bar icon appears with a functional dropdown menu, delivering the core entry point for all app functionality.

**Acceptance Scenarios**:

1. **Given** the user has installed ScreenPro, **When** they launch the application, **Then** a menu bar icon appears in the macOS status bar area
2. **Given** the app is running, **When** the user clicks the menu bar icon, **Then** a dropdown menu displays all capture and recording options
3. **Given** the app is running, **When** the user checks the Dock, **Then** the app icon does not appear (LSUIElement behavior)
4. **Given** the menu is open, **When** the user clicks any disabled feature, **Then** the item appears grayed out with no action taken

---

### User Story 2 - Grant Screen Recording Permission (Priority: P1)

A user needs to grant screen recording permission to the app before they can capture screenshots or record screens. The app must guide them through this process clearly.

**Why this priority**: Screen recording permission is a hard requirement for all capture features. Without it, no core functionality works, making this equally critical as menu bar presence.

**Independent Test**: Can be tested on a fresh install by observing the permission prompt flow, delivering user confidence that the app handles permissions properly.

**Acceptance Scenarios**:

1. **Given** a fresh install without screen recording permission, **When** the app launches and attempts to access screen content, **Then** the system permission dialog appears requesting screen recording access
2. **Given** the user has denied permission, **When** they try to capture, **Then** the app displays guidance to open System Preferences and grant permission
3. **Given** the user clicks "Open Settings" in the app, **When** the system opens preferences, **Then** it navigates directly to the Screen Recording privacy pane
4. **Given** the user grants permission, **When** they return to the app, **Then** the app recognizes the permission status and enables capture features

---

### User Story 3 - Configure Application Settings (Priority: P2)

A user wants to customize how ScreenPro behaves, including where files are saved, what format to use, and whether sounds play on capture. They expect a settings interface accessible from the menu bar.

**Why this priority**: While the app can function with defaults, users expect customization options. This enables personal workflows but is not blocking for basic functionality.

**Independent Test**: Can be tested by opening settings, changing preferences, restarting the app, and verifying persistence, delivering user confidence in configuration stability.

**Acceptance Scenarios**:

1. **Given** the app is running, **When** the user selects "Settings..." from the menu or presses Cmd+, **Then** a settings window opens with tabbed preferences
2. **Given** the settings window is open, **When** the user changes a setting (e.g., save location), **Then** the change is immediately reflected in the settings model
3. **Given** the user has changed settings, **When** they quit and relaunch the app, **Then** all modified settings are preserved
4. **Given** the user wants to reset settings, **When** they use the reset option, **Then** all settings return to default values

---

### User Story 4 - Use Global Keyboard Shortcuts (Priority: P2)

A user wants to trigger captures using keyboard shortcuts even when ScreenPro is not the active application. Common shortcuts like Cmd+Shift+4 for area capture should work system-wide.

**Why this priority**: Power users rely heavily on keyboard shortcuts for workflow efficiency. While menu access works, shortcuts significantly improve user experience and productivity.

**Independent Test**: Can be tested by focusing any other app and pressing the configured shortcut, verifying the capture action triggers, delivering hands-free capture capability.

**Acceptance Scenarios**:

1. **Given** the app is running with default shortcuts, **When** the user presses Cmd+Shift+4 from any application, **Then** the area capture mode initiates
2. **Given** the app is running, **When** the user presses Cmd+Shift+3 from any application, **Then** the fullscreen capture mode initiates
3. **Given** a shortcut conflicts with a system shortcut, **When** the app detects the conflict, **Then** it provides a warning or graceful handling
4. **Given** the app is running, **When** shortcuts are registered, **Then** they persist and work immediately after app launch without user intervention

---

### User Story 5 - Manage Microphone Permission for Recording (Priority: P3)

A user planning to record screen with audio needs to grant microphone permission. The app should check and display this permission status clearly.

**Why this priority**: Microphone permission is only needed for recording with audio, which is a feature in a later milestone. However, the permission infrastructure should be in place.

**Independent Test**: Can be tested by checking the microphone permission status in settings and requesting permission, delivering readiness for future audio recording features.

**Acceptance Scenarios**:

1. **Given** the settings window is open, **When** the user views the Permissions section, **Then** they see the microphone permission status (authorized, denied, or not determined)
2. **Given** microphone permission is not determined, **When** the user clicks "Request", **Then** the system permission dialog appears for microphone access
3. **Given** the user has denied microphone permission, **When** they click "Open Settings", **Then** the system navigates to the Microphone privacy pane

---

### Edge Cases

- What happens when the user revokes screen recording permission while the app is running? The app should detect this on the next capture attempt and gracefully disable capture features with a prompt to re-enable.
- How does the system handle if the menu bar is full and cannot display the icon? The app relies on macOS's standard menu bar behavior; the icon will appear in the overflow area if available.
- What happens if UserDefaults storage fails or becomes corrupted? The app should fall back to default settings and continue functioning.
- What happens if multiple instances of the app are launched? The app should prevent multiple instances or gracefully handle single-instance behavior via standard macOS app lifecycle.
- What happens if global shortcuts fail to register due to system restrictions? The app should inform the user that shortcuts could not be registered and menu-based access remains available.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display a persistent icon in the macOS menu bar when the application is running
- **FR-002**: System MUST hide the application from the macOS Dock (LSUIElement enabled)
- **FR-003**: System MUST provide a dropdown menu from the menu bar icon containing all capture and recording options
- **FR-004**: System MUST check for screen recording permission on launch and prompt the user if not granted
- **FR-005**: System MUST provide a way to navigate users directly to the Screen Recording privacy settings in System Preferences
- **FR-006**: System MUST check for microphone permission status and display it in settings
- **FR-007**: System MUST provide a way to request microphone permission and navigate to Microphone privacy settings
- **FR-008**: System MUST provide a settings window with tabbed organization (General, Capture, Recording, Shortcuts)
- **FR-009**: System MUST persist all user settings across application restarts using local storage
- **FR-010**: System MUST provide configurable settings for: launch at login, menu bar icon visibility, capture sound, save location, file naming pattern, image format, capture options (cursor, crosshair, magnifier), video settings (format, quality, FPS), audio settings, and quick access preferences
- **FR-011**: System MUST register global keyboard shortcuts that work when the app is not focused
- **FR-012**: System MUST provide default keyboard shortcuts (Cmd+Shift+4 for area, Cmd+Shift+3 for fullscreen, Cmd+Shift+5 for all-in-one, Cmd+Shift+6 for recording)
- **FR-013**: System MUST detect and handle keyboard shortcut conflicts with system shortcuts
- **FR-014**: System MUST provide a central state machine (AppCoordinator) managing application state transitions
- **FR-015**: System MUST provide service components for: permission management, shortcut management, settings management, and file storage
- **FR-016**: System MUST properly initialize all services on application launch and clean up on termination
- **FR-017**: System MUST display disabled menu items for features not yet implemented (with visual indication)

### Key Entities

- **AppCoordinator**: Central state machine managing application lifecycle and state transitions (idle, requesting permission, selecting area, capturing, recording, annotating, uploading)
- **PermissionManager**: Service managing screen recording and microphone permission status and requests
- **ShortcutManager**: Service managing global keyboard shortcut registration, conflict detection, and action handling
- **SettingsManager**: Service managing user preferences persistence and retrieval
- **StorageService**: Service managing file operations, clipboard operations, and unique filename generation
- **Settings**: Data model containing all user-configurable preferences (launch behavior, capture settings, recording settings, quick access settings)
- **Shortcut**: Data model representing a keyboard shortcut with key code, modifiers, and display string

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Application launches and displays menu bar icon within 2 seconds of user initiating launch
- **SC-002**: Menu bar dropdown displays all options within 100 milliseconds of user clicking the icon
- **SC-003**: Settings window opens within 500 milliseconds of user triggering the action
- **SC-004**: User preference changes are persisted and correctly restored after application restart with 100% reliability
- **SC-005**: Screen recording permission status is accurately detected and displayed to the user
- **SC-006**: Navigation to System Preferences opens the correct privacy pane 100% of the time
- **SC-007**: Global keyboard shortcuts respond within 200 milliseconds of key press when app is in background
- **SC-008**: Application consumes less than 50MB of memory when idle in menu bar
- **SC-009**: Application builds successfully without compiler warnings
- **SC-010**: All implemented settings tabs are navigable and functional
