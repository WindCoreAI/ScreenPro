import Foundation

/// Recording service state
enum RecordingState: Equatable, Sendable {
    /// No recording in progress
    case idle

    /// Recording is starting (initializing capture)
    case starting

    /// Actively recording
    case recording

    /// Recording is paused
    case paused

    /// Recording is stopping (finalizing output)
    case stopping
}
