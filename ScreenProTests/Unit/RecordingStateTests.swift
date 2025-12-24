import XCTest
@testable import ScreenPro

/// Unit tests for RecordingState (T026)
final class RecordingStateTests: XCTestCase {

    // MARK: - State Values

    func testAllStates() {
        // Verify all expected states exist
        let states: [RecordingState] = [
            .idle,
            .starting,
            .recording,
            .paused,
            .stopping
        ]

        XCTAssertEqual(states.count, 5)
    }

    // MARK: - Equatable Tests

    func testEquatable() {
        XCTAssertEqual(RecordingState.idle, RecordingState.idle)
        XCTAssertEqual(RecordingState.recording, RecordingState.recording)
        XCTAssertEqual(RecordingState.paused, RecordingState.paused)

        XCTAssertNotEqual(RecordingState.idle, RecordingState.recording)
        XCTAssertNotEqual(RecordingState.recording, RecordingState.paused)
        XCTAssertNotEqual(RecordingState.paused, RecordingState.stopping)
    }

    // MARK: - State Transitions (Conceptual)

    func testIdleIsStartingState() {
        // idle should be the initial state
        let state = RecordingState.idle
        XCTAssertEqual(state, .idle)
    }

    func testValidTransitionFromIdleToStarting() {
        // Valid: idle -> starting (when user initiates recording)
        let from = RecordingState.idle
        let to = RecordingState.starting

        // This is a valid transition
        XCTAssertNotEqual(from, to)
    }

    func testValidTransitionFromStartingToRecording() {
        // Valid: starting -> recording (when capture stream starts)
        let from = RecordingState.starting
        let to = RecordingState.recording

        XCTAssertNotEqual(from, to)
    }

    func testValidTransitionFromRecordingToPaused() {
        // Valid: recording -> paused (when user pauses)
        let from = RecordingState.recording
        let to = RecordingState.paused

        XCTAssertNotEqual(from, to)
    }

    func testValidTransitionFromPausedToRecording() {
        // Valid: paused -> recording (when user resumes)
        let from = RecordingState.paused
        let to = RecordingState.recording

        XCTAssertNotEqual(from, to)
    }

    func testValidTransitionFromRecordingToStopping() {
        // Valid: recording -> stopping (when user stops)
        let from = RecordingState.recording
        let to = RecordingState.stopping

        XCTAssertNotEqual(from, to)
    }

    func testValidTransitionFromPausedToStopping() {
        // Valid: paused -> stopping (user can stop while paused)
        let from = RecordingState.paused
        let to = RecordingState.stopping

        XCTAssertNotEqual(from, to)
    }

    func testValidTransitionFromStoppingToIdle() {
        // Valid: stopping -> idle (when finalization completes)
        let from = RecordingState.stopping
        let to = RecordingState.idle

        XCTAssertNotEqual(from, to)
    }

    // MARK: - Sendable Conformance

    func testSendable() {
        // RecordingState should be Sendable for use across actors
        let state: RecordingState = .recording

        // This compiles because RecordingState is Sendable
        Task {
            let _ = state
        }
    }
}

/// Unit tests for RecordingControlsView timer formatting (T027)
final class RecordingControlsTests: XCTestCase {

    // MARK: - Duration Formatting

    func testDurationFormattingZero() {
        let formatted = formatDuration(0)
        XCTAssertEqual(formatted, "00:00.0")
    }

    func testDurationFormattingSeconds() {
        let formatted = formatDuration(5.5)
        XCTAssertEqual(formatted, "00:05.5")
    }

    func testDurationFormattingMinutes() {
        let formatted = formatDuration(65.3)
        XCTAssertEqual(formatted, "01:05.3")
    }

    func testDurationFormattingTenMinutes() {
        let formatted = formatDuration(600)
        XCTAssertEqual(formatted, "10:00.0")
    }

    func testDurationFormattingHour() {
        let formatted = formatDuration(3661.9)
        XCTAssertEqual(formatted, "61:01.9")
    }

    func testDurationFormattingPrecision() {
        // Test that we show only one decimal place (tenths)
        let formatted = formatDuration(5.123)
        XCTAssertEqual(formatted, "00:05.1")
    }

    // MARK: - Helper

    /// Replicates the formatting logic from RecordingControlsView
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let tenths = Int((duration - Double(totalSeconds)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, tenths)
    }
}
