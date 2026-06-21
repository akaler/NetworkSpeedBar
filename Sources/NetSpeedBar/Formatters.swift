import Foundation

enum SpeedFormatter {
    /// Human-friendly rate: 1.2 MB/s, 45 KB/s, 320 B/s.
    static func rate(bytesPerSec: Double) -> String {
        let bytes = max(0, bytesPerSec)
        if bytes >= 1_000_000 {
            return String(format: "%.1f MB/s", bytes / 1_000_000)
        } else if bytes >= 1_000 {
            return String(format: "%.0f KB/s", bytes / 1_000)
        } else {
            return String(format: "%.0f B/s", bytes)
        }
    }

    /// Compact form used by the menu bar label and graph axis.
    static func compactMagnitude(bytesPerSec: Double) -> String {
        let bytes = max(0, bytesPerSec)
        if bytes >= 1_000_000 {
            return String(format: "%.1fM", bytes / 1_000_000)
        } else if bytes >= 1_000 {
            return String(format: "%.0fK", bytes / 1_000)
        } else {
            return String(format: "%.0f", bytes)
        }
    }

    /// Fixed-width label so the menu bar width stays stable as values change.
    static func barLabel(down: Double, up: Double) -> String {
        "↓\(compactFixedWidth(bytesPerSec: down))  ↑\(compactFixedWidth(bytesPerSec: up))"
    }

    /// Bytes to human-readable size: 8.2 GB, 512 MB, etc.
    static func bytes(_ byteCount: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowsNonnumericFormatting = false
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(byteCount))
    }

    // MARK: - Private

    private static let barFieldWidth = 5

    private static func compactFixedWidth(bytesPerSec: Double) -> String {
        let s = compactMagnitude(bytesPerSec: bytesPerSec)
        guard s.count < barFieldWidth else { return s }
        let pad = String(repeating: "\u{2007}", count: barFieldWidth - s.count)
        return pad + s
    }
}
