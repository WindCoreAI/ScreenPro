import Foundation

// MARK: - TimerState (T041)

/// State of the self-timer during countdown.
struct TimerState: Equatable {
    /// Current remaining seconds.
    let remainingSeconds: Int

    /// Total seconds for the timer.
    let totalSeconds: Int

    /// Whether the timer is currently counting down.
    let isActive: Bool

    /// Creates a timer state.
    /// - Parameters:
    ///   - remainingSeconds: Remaining seconds.
    ///   - totalSeconds: Total seconds.
    ///   - isActive: Whether active.
    init(remainingSeconds: Int, totalSeconds: Int, isActive: Bool = true) {
        self.remainingSeconds = max(0, remainingSeconds)
        self.totalSeconds = max(1, totalSeconds)
        self.isActive = isActive
    }

    /// Creates an initial state from a config.
    /// - Parameter config: The timer configuration.
    /// - Returns: Initial timer state.
    static func initial(from config: TimerConfig) -> TimerState {
        TimerState(
            remainingSeconds: config.seconds,
            totalSeconds: config.seconds,
            isActive: true
        )
    }

    /// An inactive timer state.
    static var inactive: TimerState {
        TimerState(remainingSeconds: 0, totalSeconds: 1, isActive: false)
    }

    /// Progress of the countdown (0.0 to 1.0).
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    /// Whether the countdown has completed.
    var isComplete: Bool {
        remainingSeconds == 0 && isActive
    }
}
