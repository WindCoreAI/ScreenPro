// MARK: - OverlayControllerProtocol
// Contract for Recording Overlay Controllers
// Feature: 005-screen-recording

import Foundation
import AppKit

/// Protocol for overlay controllers that display visual feedback during recording.
/// All implementations must be @MainActor isolated for window management.
@MainActor
protocol OverlayControllerProtocol {
    /// Start monitoring and displaying the overlay.
    /// Creates the overlay window and begins event monitoring.
    func start()

    /// Stop monitoring and hide the overlay.
    /// Removes event monitors and closes the overlay window.
    func stop()
}

// MARK: - Click Overlay Specific

/// Protocol for click visualization overlay.
@MainActor
protocol ClickOverlayProtocol: OverlayControllerProtocol {
    /// Currently active click effects (for testing/inspection)
    var activeEffects: [ClickEffect] { get }
}

// MARK: - Keystroke Overlay Specific

/// Protocol for keystroke visualization overlay.
@MainActor
protocol KeystrokeOverlayProtocol: OverlayControllerProtocol {
    /// Currently displayed key presses (for testing/inspection)
    var displayedKeys: [KeyPress] { get }

    /// Maximum number of keys to display simultaneously
    var maxDisplayedKeys: Int { get }

    /// How long keys remain visible after being pressed (in seconds)
    var displayDuration: TimeInterval { get }
}
