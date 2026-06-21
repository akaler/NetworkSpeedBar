import AppKit

/// Small down/upload sparkline drawn into the menu bar status button.
enum BarSparkline {
    static let width: CGFloat = 50
    static let height: CGFloat = 16

    static func image(for history: [SpeedSample]) -> NSImage {
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.isTemplate = false

        let peak = max(history.map { $0.down }.max() ?? 1,
                       history.map { $0.up }.max()   ?? 1, 1) * 1.05

        image.lockFocus()
        strokePath(samples: history.map { $0.down }, peak: peak, color: AppConstants.AppKit.downloadColor)
        strokePath(samples: history.map { $0.up },   peak: peak, color: AppConstants.AppKit.uploadColor)
        image.unlockFocus()

        return image
    }

    private static func strokePath(samples: [Double], peak: Double, color: NSColor) {
        guard samples.count >= 2 else { return }

        let path = NSBezierPath()
        path.lineWidth = 1.2
        color.set()

        let columns = Int(width)
        for col in 0..<columns {
            let value = average(samples, over: Double(col) ..< Double(col + 1), totalColumns: columns)
            let x = CGFloat(col) + 0.5
            let y = (CGFloat(value / peak) * (height - 1)) + 0.5

            if col == 0 {
                path.move(to: NSPoint(x: x, y: y))
            } else {
                path.line(to: NSPoint(x: x, y: y))
            }
        }
        path.stroke()
    }

    private static func average(_ samples: [Double], over columnRange: Range<Double>, totalColumns: Int) -> Double {
        let count = samples.count
        let start = columnRange.lowerBound * Double(count) / Double(totalColumns)
        let end   = columnRange.upperBound * Double(count) / Double(totalColumns)

        var sum: Double = 0
        var weight: Double = 0
        var i = Int(start)
        while i < count && Double(i) < end {
            let segStart = max(Double(i), start)
            let segEnd   = min(Double(i + 1), end)
            let w = segEnd - segStart
            sum += samples[i] * w
            weight += w
            i += 1
        }
        return weight > 0 ? sum / weight : 0
    }
}
