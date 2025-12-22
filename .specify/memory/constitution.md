<!--
================================================================================
SYNC IMPACT REPORT
================================================================================
Version Change: 0.0.0 → 1.0.0 (MAJOR - Initial constitution ratification)

Modified Principles: N/A (initial creation)

Added Sections:
  - Core Principles (7 principles)
  - Technology Constraints
  - Development Workflow
  - Governance

Removed Sections: N/A (initial creation)

Templates Requiring Updates:
  ✅ .specify/templates/plan-template.md - Constitution Check section compatible
  ✅ .specify/templates/spec-template.md - Requirements format compatible
  ✅ .specify/templates/tasks-template.md - Phase structure compatible

Follow-up TODOs: None

================================================================================
-->

# ScreenPro Constitution

## Core Principles

### I. Native macOS First

All features MUST be implemented using Apple's native frameworks. No cross-platform dependencies or abstraction layers permitted.

**Required Frameworks**:
- ScreenCaptureKit for all screen capture operations (NOT deprecated CGWindowListCreateImage)
- AVFoundation for video/audio encoding and recording
- Vision for OCR and image analysis
- Core Image and Core Graphics for image processing
- ImageIO for GIF encoding
- SwiftData for persistence

**Rationale**: Native frameworks provide optimal performance, system integration, and long-term platform compatibility. Cross-platform abstractions add overhead and limit access to platform-specific features.

### II. Privacy by Default

All data processing MUST occur on-device. User data MUST NOT leave the device without explicit user action.

**Requirements**:
- OCR processing MUST use Vision framework on-device (no cloud APIs)
- No telemetry, analytics, or crash reporting without explicit opt-in
- Cloud uploads MUST require explicit user action for each upload
- Capture history MUST be stored locally only
- No third-party SDKs that transmit user data

**Rationale**: Screenshot and recording content often contains sensitive information. Users must have complete control over their data.

### III. UX Excellence

The application MUST follow the "invisible until needed" design philosophy. The Quick Access Overlay is the primary post-capture interaction point.

**Requirements**:
- Menu bar presence MUST be unobtrusive
- Capture operations MUST complete without interrupting user workflow
- Quick Access Overlay MUST appear within 200ms of capture completion
- All features MUST be keyboard-accessible
- Design MUST follow macOS Human Interface Guidelines
- Annotation editor MUST support non-destructive editing

**Rationale**: CleanShot X's success stems from minimizing friction. ScreenPro must match or exceed this standard.

### IV. Performance Standards

Capture and display operations MUST meet strict latency targets. The app MUST remain responsive under all conditions.

**Targets**:
- Screenshot capture: < 50ms from trigger to image ready
- Quick Access Overlay display: < 200ms from capture complete
- Annotation tool response: < 16ms (60fps interaction)
- Video encoding: Real-time with no frame drops at target FPS
- Memory (idle, menu bar only): < 50MB
- Memory (annotation editor, large image): < 300MB

**Rationale**: Users expect instant response from screenshot tools. Perceptible delays break workflow immersion.

### V. Testing Discipline

Tests SHOULD accompany non-trivial implementations. Integration and contract tests take priority over unit tests.

**Guidelines**:
- Integration tests SHOULD cover user-facing workflows
- Contract tests SHOULD verify API/service boundaries
- Unit tests SHOULD cover complex business logic
- Test coverage is NOT a blocking gate, but regressions in tested functionality MUST be fixed
- New features SHOULD include at least one integration test for the happy path

**Rationale**: Balanced approach ensures quality without creating excessive development overhead for a native app with strong type safety.

### VI. Accessibility Compliance

The application MUST be usable by people with disabilities. VoiceOver support is mandatory for all interactive elements.

**Requirements**:
- All buttons and controls MUST have accessible labels
- Keyboard navigation MUST reach all features
- Color MUST NOT be the only indicator of state
- Minimum contrast ratio: 4.5:1 for text
- Support macOS "Reduce Motion" preference
- Support macOS "Increase Contrast" preference
- Focus indicators MUST be visible on all interactive elements

**Rationale**: Accessibility is a legal requirement in many jurisdictions and expands the user base. Building it in from the start is far easier than retrofitting.

### VII. Security Boundaries

The application MUST operate within the App Sandbox. Permissions MUST be requested only when needed and clearly explained.

**Requirements**:
- App Sandbox MUST be enabled
- Screen Recording permission: Required at first capture attempt, not at launch
- Microphone permission: Required only when mic recording is enabled
- Accessibility permission: Required only for keystroke capture feature
- All network requests MUST use HTTPS
- Sensitive data (if any) MUST be stored in Keychain
- No remote code execution or dynamic library loading

**Rationale**: macOS users expect apps to respect security boundaries. Sandboxing limits blast radius of any potential vulnerability.

## Technology Constraints

**Language**: Swift 5.9+ with strict concurrency checking enabled

**UI Framework**: SwiftUI as primary, AppKit for system integration (NSStatusItem, NSWindow for overlays)

**Minimum Deployment**: macOS 14.0 (Sonoma) for full ScreenCaptureKit screenshot API

**Architecture**: Apple Silicon + Intel (Universal Binary)

**Dependencies**: Apple frameworks only. No external package dependencies for core functionality. Optional: Sparkle for auto-updates (if distributing outside App Store).

**Concurrency**: Swift Concurrency (async/await, actors) for all asynchronous operations. No completion handler callbacks for new code.

## Development Workflow

**Code Organization**:
- Feature-based module structure (see system-architecture.md)
- Each module MUST have a single responsibility
- Services MUST be protocol-based for testability
- @MainActor for all UI-related code

**Review Requirements**:
- All changes MUST be reviewed before merge
- Constitution compliance MUST be verified in review
- Performance-sensitive changes MUST include benchmarks

**Documentation**:
- Public APIs MUST have documentation comments
- Non-obvious implementation choices MUST have inline comments explaining rationale
- Architecture decisions MUST be documented in /docs

## Governance

This constitution supersedes all other development practices for the ScreenPro project.

**Amendment Process**:
1. Proposed changes MUST be documented with rationale
2. Changes MUST be reviewed by project maintainer(s)
3. Breaking changes (principle removal/redefinition) require MAJOR version bump
4. Additions require MINOR version bump
5. Clarifications require PATCH version bump

**Compliance**:
- All pull requests MUST verify compliance with applicable principles
- Non-compliance MUST be explicitly justified in PR description
- Justified exceptions MUST be documented in plan.md Complexity Tracking section

**Version**: 1.0.0 | **Ratified**: 2025-12-22 | **Last Amended**: 2025-12-22
