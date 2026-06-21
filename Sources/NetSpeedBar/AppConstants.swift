import AppKit
import SwiftUI

/// Shared app styling constants.
enum AppConstants {
    /// Polling interval options shown in the menu.
    static let pollIntervals: [(label: String, seconds: TimeInterval)] = [
        ("0.25 s", 0.25),
        ("0.5 s",  0.5),
        ("1 s",    1.0),
    ]

    /// How far back the live graph and sparkline remember samples.
    static let historyWindow: TimeInterval = 120

    /// Cap on stored samples to keep memory bounded at high poll rates.
    static let maxHistorySamples = 2000

    /// Download speed color (green).
    static let downloadColor = Color(red: 0.25, green: 0.7, blue: 0.35)

    /// Upload speed color (blue).
    static let uploadColor = Color(red: 0.2, green: 0.5, blue: 0.95)
}

extension AppConstants {
    /// AppKit colors for drawing into `NSImage`.
    enum AppKit {
        static let downloadColor = NSColor(red: 0.25, green: 0.7, blue: 0.35, alpha: 1)
        static let uploadColor   = NSColor(red: 0.2,  green: 0.5, blue: 0.95, alpha: 1)
    }
}
