// MARK: - RecordingServiceProtocol
// Contract for Screen Recording Service
// Feature: 005-screen-recording

import Foundation
import ScreenCaptureKit
import Combine

/// Protocol defining the public interface for the recording service.
/// All implementations must be @MainActor isolated for UI thread safety.
@MainActor
protocol RecordingServiceProtocol: ObservableObject {
    // MARK: - Published State

    /// Current recording state
    var state: RecordingState { get }

    /// Current recording duration in seconds
    var duration: TimeInterval { get }

    /// The region currently being recorded (nil when idle)
    var recordingRegion: RecordingRegion? { get }

    // MARK: - Recording Lifecycle

    /// Start a new recording with the specified region and format.
    /// - Parameters:
    ///   - region: The screen region to record
    ///   - format: The output format (video or GIF)
    /// - Throws: RecordingError if recording cannot start
    func startRecording(region: RecordingRegion, format: RecordingFormat) async throws

    /// Pause the current recording.
    /// - Note: Only valid when state is .recording
    func pauseRecording()

    /// Resume a paused recording.
    /// - Note: Only valid when state is .paused
    func resumeRecording()

    /// Stop the recording and finalize the output file.
    /// - Returns: The recording result with file URL and metadata
    /// - Throws: RecordingError if finalization fails
    func stopRecording() async throws -> RecordingResult

    /// Cancel the recording and delete any partial output.
    /// - Note: Valid from any recording state
    func cancelRecording()
}

// MARK: - Convenience Computed Properties

extension RecordingServiceProtocol {
    /// Whether a recording is currently in progress (recording or paused)
    var isRecording: Bool {
        state == .recording || state == .paused
    }

    /// Whether the recording is currently paused
    var isPaused: Bool {
        state == .paused
    }

    /// Whether the service is idle and ready to start a new recording
    var isIdle: Bool {
        state == .idle
    }
}
