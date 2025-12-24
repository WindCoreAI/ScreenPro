import Foundation
import CoreGraphics

// MARK: - FreezeState (T047)

/// State of the screen freeze mode.
struct FreezeState: Equatable {
    /// Whether screen is currently frozen.
    let isFrozen: Bool

    /// When the freeze was activated.
    let frozenAt: Date?

    /// The frozen display image (for internal use).
    let displayID: CGDirectDisplayID?

    /// Creates a freeze state.
    /// - Parameters:
    ///   - isFrozen: Whether screen is frozen.
    ///   - frozenAt: When freeze was activated.
    ///   - displayID: The display ID that is frozen.
    init(isFrozen: Bool = false, frozenAt: Date? = nil, displayID: CGDirectDisplayID? = nil) {
        self.isFrozen = isFrozen
        self.frozenAt = frozenAt
        self.displayID = displayID
    }

    /// Default unfrozen state.
    static var unfrozen: FreezeState {
        FreezeState(isFrozen: false)
    }

    /// Creates a frozen state for the specified display.
    /// - Parameter displayID: The display ID to freeze.
    /// - Returns: A frozen state.
    static func frozen(displayID: CGDirectDisplayID) -> FreezeState {
        FreezeState(isFrozen: true, frozenAt: Date(), displayID: displayID)
    }

    /// Duration the screen has been frozen.
    var freezeDuration: TimeInterval? {
        guard let frozenAt = frozenAt else { return nil }
        return Date().timeIntervalSince(frozenAt)
    }
}
