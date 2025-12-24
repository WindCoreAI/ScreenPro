import Foundation
import AppKit
import Combine

// MARK: - SelfTimerController (T042)

/// Controller managing self-timer countdown for delayed capture.
@MainActor
final class SelfTimerController: ObservableObject {
    // MARK: - Published Properties

    /// Current timer state.
    @Published private(set) var state: TimerState = .inactive

    /// Whether the timer is currently active.
    @Published private(set) var isActive = false

    // MARK: - Properties

    /// The timer configuration.
    private var config: TimerConfig = .fiveSeconds

    /// The countdown timer.
    private var countdownTimer: Timer?

    /// Action to perform when countdown completes.
    private var completionAction: (() -> Void)?

    /// Action to perform when countdown is cancelled.
    private var cancellationAction: (() -> Void)?

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Starts the timer with the specified configuration.
    /// - Parameters:
    ///   - config: Timer configuration.
    ///   - onComplete: Action when countdown completes.
    ///   - onCancel: Action when countdown is cancelled.
    func start(
        config: TimerConfig,
        onComplete: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        cancel() // Cancel any existing timer

        self.config = config
        self.completionAction = onComplete
        self.cancellationAction = onCancel
        self.state = .initial(from: config)
        self.isActive = true

        // Play initial sound
        if config.playSounds {
            playCountdownSound()
        }

        // Start countdown timer
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    /// Cancels the current countdown.
    func cancel() {
        countdownTimer?.invalidate()
        countdownTimer = nil

        if isActive {
            cancellationAction?()
        }

        state = .inactive
        isActive = false
        completionAction = nil
        cancellationAction = nil
    }

    /// Pauses the countdown.
    func pause() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    /// Resumes the countdown.
    func resume() {
        guard isActive, state.remainingSeconds > 0 else { return }

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    // MARK: - Private Methods

    /// Handles a timer tick.
    private func tick() {
        guard isActive else { return }

        let newRemaining = state.remainingSeconds - 1

        if newRemaining <= 0 {
            // Countdown complete
            countdownTimer?.invalidate()
            countdownTimer = nil

            state = TimerState(
                remainingSeconds: 0,
                totalSeconds: state.totalSeconds,
                isActive: true
            )

            // Play capture sound
            if config.playSounds {
                playCaptureSound()
            }

            // Execute completion action
            isActive = false
            completionAction?()
            completionAction = nil
            cancellationAction = nil
        } else {
            // Update state
            state = TimerState(
                remainingSeconds: newRemaining,
                totalSeconds: state.totalSeconds,
                isActive: true
            )

            // Play countdown sound
            if config.playSounds {
                playCountdownSound()
            }
        }
    }

    /// Plays the countdown tick sound.
    private func playCountdownSound() {
        NSSound(named: "Tink")?.play()
    }

    /// Plays the capture sound when timer completes.
    private func playCaptureSound() {
        NSSound(named: "Pop")?.play()
    }
}
