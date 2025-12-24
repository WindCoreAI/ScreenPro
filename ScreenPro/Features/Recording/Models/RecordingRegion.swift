import Foundation
import ScreenCaptureKit

/// The region of the screen to record
enum RecordingRegion: Sendable {
    /// Record an entire display
    case display(SCDisplay)

    /// Record a specific window
    case window(SCWindow)

    /// Record a user-selected area on a display
    case area(CGRect, SCDisplay)
}
