import Foundation
import AVFoundation

// MARK: - MicrophoneAudioHub (008-review-recording)
//
// AVAudioEngine permits exactly one tap per input bus, but microphone audio
// can have multiple simultaneous consumers (the recording's mic track and the
// review-session speech recognizer). The hub owns the single tap and fans
// buffers out to registered consumers. The engine runs while at least one
// consumer is registered and stops with the last removal, so the mic
// indicator never stays on longer than needed (research.md R4).

final class MicrophoneAudioHub: @unchecked Sendable {
    /// Called on the audio tap thread — implementations must be thread-safe
    /// and must not block.
    typealias Consumer = (AVAudioPCMBuffer, AVAudioTime) -> Void

    enum HubError: Error {
        case invalidInputFormat
        case engineStartFailed(String)
    }

    private let lock = NSLock()
    private var consumers: [UUID: Consumer] = [:]
    private var engine: AVAudioEngine?

    /// Registers a consumer, starting the engine and installing the tap if
    /// this is the first one. Returns a token for removal.
    func addConsumer(_ consumer: @escaping Consumer) throws -> UUID {
        lock.lock(); defer { lock.unlock() }

        if engine == nil {
            try startEngineLocked()
        }

        let token = UUID()
        consumers[token] = consumer
        return token
    }

    /// Removes a consumer; stops the engine when none remain.
    func removeConsumer(_ token: UUID) {
        lock.lock(); defer { lock.unlock() }

        consumers[token] = nil
        if consumers.isEmpty {
            stopEngineLocked()
        }
    }

    /// The current input format, available while the engine runs (used by the
    /// speech recognizer to configure its request).
    var inputFormat: AVAudioFormat? {
        lock.lock(); defer { lock.unlock() }
        return engine?.inputNode.outputFormat(forBus: 0)
    }

    // MARK: - Engine lifecycle (lock held)

    private func startEngineLocked() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0 && format.channelCount > 0 else {
            throw HubError.invalidInputFormat
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, time in
            self?.dispatch(buffer, time: time)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw HubError.engineStartFailed(error.localizedDescription)
        }

        self.engine = engine
    }

    private func stopEngineLocked() {
        guard let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
    }

    private func dispatch(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Snapshot under lock; invoke outside it so a slow consumer can't
        // block add/remove (it still must not block the tap thread).
        lock.lock()
        let snapshot = Array(consumers.values)
        lock.unlock()

        for consumer in snapshot {
            consumer(buffer, time)
        }
    }
}
