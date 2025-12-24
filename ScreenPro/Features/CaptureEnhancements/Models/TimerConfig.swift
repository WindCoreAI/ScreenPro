import Foundation

// MARK: - TimerConfig (T040)

/// Configuration for self-timer capture.
struct TimerConfig: Equatable {
    /// Duration in seconds before capture triggers.
    let seconds: Int

    /// Whether to play countdown sounds.
    let playSounds: Bool

    /// Whether to show visual countdown.
    let showVisual: Bool

    /// Creates a timer configuration.
    /// - Parameters:
    ///   - seconds: Duration in seconds (default 5).
    ///   - playSounds: Play countdown sounds (default true).
    ///   - showVisual: Show visual countdown (default true).
    init(seconds: Int = 5, playSounds: Bool = true, showVisual: Bool = true) {
        self.seconds = max(1, min(30, seconds))
        self.playSounds = playSounds
        self.showVisual = showVisual
    }

    /// Common timer presets.
    static let threeSeconds = TimerConfig(seconds: 3)
    static let fiveSeconds = TimerConfig(seconds: 5)
    static let tenSeconds = TimerConfig(seconds: 10)

    /// Available timer options for UI.
    static var availableOptions: [TimerConfig] {
        [.threeSeconds, .fiveSeconds, .tenSeconds]
    }

    /// Display label for the timer.
    var displayLabel: String {
        "\(seconds)s"
    }
}
