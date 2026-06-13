import Foundation
import AVFoundation

// MARK: - Speech Transcription Contract (008-review-recording)
//
// Wraps SFSpeechRecognizer with strict on-device recognition (FR-005, FR-018)
// and silence-timeout utterance segmentation (research.md R2).

/// One segmented spoken observation.
struct Utterance: Sendable, Equatable {
    /// Recorded time (pause-adjusted) at which the utterance began.
    let start: TimeInterval
    /// Recorded time of the last recognized word.
    let end: TimeInterval
    /// Best transcription, trimmed; never empty.
    let text: String
}

@MainActor
protocol SpeechTranscriptionServiceProtocol: AnyObject {
    /// True when the locale supports on-device recognition and authorization
    /// is granted. Checked at session start; never falls back to server (R1).
    var isAvailable: Bool { get }

    /// Requests speech authorization if not determined. Returns granted state.
    func requestAuthorization() async -> Bool

    /// Begins streaming recognition.
    /// - Parameters:
    ///   - locale: empty string → current system locale.
    ///   - recordedClock: pause-adjusted recorded-time source for stamping.
    ///   - onUtterance: called on the main actor for each closed utterance.
    /// - Throws: when the locale is unsupported on-device or the recognizer
    ///   cannot start (session then proceeds manual-only, FR-014).
    func start(locale: String,
               recordedClock: @escaping @Sendable () -> TimeInterval,
               onUtterance: @escaping @MainActor (Utterance) -> Void) throws

    /// Feed microphone audio (registered as a MicrophoneAudioHub consumer).
    /// Called on the audio tap thread; implementation must be thread-safe.
    nonisolated func append(_ buffer: AVAudioPCMBuffer)

    /// Pause/resume consumption around recording pause (FR-017).
    func suspend()
    func resume()

    /// Ends recognition, flushing any open utterance.
    func stop()
}

// MARK: - Segmentation core (pure, unit-testable — research.md R10)

/// Drives utterance boundaries from partial-result events + a clock.
/// No Speech framework types so tests can inject events directly.
protocol UtteranceSegmenting {
    /// Silence gap that closes an utterance (default 1.2 s).
    var silenceThreshold: TimeInterval { get }

    /// Report a partial transcription at a recorded time.
    mutating func partial(text: String, at time: TimeInterval)

    /// Periodic tick; returns a closed utterance when silence elapsed.
    mutating func tick(now: TimeInterval) -> Utterance?

    /// Flush at stop; returns the open utterance if non-empty.
    mutating func flush(now: TimeInterval) -> Utterance?
}
