import Combine
import Darwin
import Foundation

struct SpeedSample: Equatable {
    let date: Date
    let down: Double
    let up: Double
}

struct InterfaceStats: Equatable {
    let rxBytes: UInt64
    let txBytes: UInt64
}

/// Polls `getifaddrs()` and publishes live upload/download speeds.
final class NetworkMonitor: ObservableObject {
    @Published private(set) var downloadBytesPerSec: Double = 0
    @Published private(set) var uploadBytesPerSec: Double = 0
    @Published private(set) var perInterface: [String: (down: Double, up: Double)] = [:]
    @Published private(set) var history: [SpeedSample] = []

    private(set) var interval: TimeInterval {
        didSet {
            guard interval != oldValue else { return }
            stop()
            start()
        }
    }

    private var lastStats: [String: InterfaceStats] = [:]
    private var lastSampleDate: Date?
    private var timer: Timer?

    // Exponential moving average state so the graph stays calm.
    private var smoothedDown: Double?
    private var smoothedUp: Double?
    private let smoothingTimeConstant: TimeInterval = 3.0

    init(interval: TimeInterval = 1.0) {
        self.interval = interval
        self.lastStats = currentStats()
        self.lastSampleDate = Date()
    }

    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setInterval(_ value: TimeInterval) {
        interval = value
    }

    func clearHistory() {
        DispatchQueue.main.async { [weak self] in
            self?.history.removeAll()
        }
    }

    // MARK: - Sampling

    private func tick() {
        let now = Date()
        guard let lastDate = lastSampleDate, now > lastDate else { return }

        let elapsed = now.timeIntervalSince(lastDate)
        let current = currentStats()

        var totalDown: Double = 0
        var totalUp: Double = 0
        var activeInterfaces: [String: (down: Double, up: Double)] = [:]

        for (name, stats) in current {
            guard !isIgnoredInterface(name) else { continue }

            let previous = lastStats[name] ?? InterfaceStats(rxBytes: 0, txBytes: 0)
            let downDelta = signedDiff(current: stats.rxBytes, previous: previous.rxBytes)
            let upDelta   = signedDiff(current: stats.txBytes, previous: previous.txBytes)

            let down = max(0, downDelta / elapsed)
            let up   = max(0, upDelta / elapsed)

            if down > 0 || up > 0 {
                activeInterfaces[name] = (down, up)
            }
            totalDown += down
            totalUp   += up
        }

        let (smoothedDown, smoothedUp) = smooth(down: totalDown, up: totalUp, elapsed: elapsed)

        DispatchQueue.main.async { [weak self] in
            self?.downloadBytesPerSec = totalDown
            self?.uploadBytesPerSec = totalUp
            self?.perInterface = activeInterfaces
            self?.addHistorySample(date: now, down: smoothedDown, up: smoothedUp)
        }

        lastStats = current
        lastSampleDate = now
    }

    private func isIgnoredInterface(_ name: String) -> Bool {
        name == "lo0" || name.hasPrefix("gif") || name.hasPrefix("stf")
    }

    private func signedDiff(current: UInt64, previous: UInt64) -> Double {
        Double(Int64(bitPattern: current) &- Int64(bitPattern: previous))
    }

    private func smooth(down: Double, up: Double, elapsed: TimeInterval) -> (down: Double, up: Double) {
        let alpha = 1.0 - exp(-elapsed / smoothingTimeConstant)
        let nextDown = smoothedDown.map { $0 + alpha * (down - $0) } ?? down
        let nextUp   = smoothedUp.map   { $0 + alpha * (up   - $0) } ?? up
        self.smoothedDown = nextDown
        self.smoothedUp = nextUp
        return (nextDown, nextUp)
    }

    private func addHistorySample(date: Date, down: Double, up: Double) {
        history.append(SpeedSample(date: date, down: down, up: up))

        let cutoff = date.addingTimeInterval(-AppConstants.historyWindow)
        while history.first?.date ?? Date.distantFuture < cutoff {
            history.removeFirst()
        }
        if history.count > AppConstants.maxHistorySamples {
            history.removeFirst(history.count - AppConstants.maxHistorySamples)
        }
    }

    // MARK: - getifaddrs

    private func currentStats() -> [String: InterfaceStats] {
        var result: [String: InterfaceStats] = [:]

        var ifaddrsPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrsPtr) == 0, let firstAddr = ifaddrsPtr else {
            return result
        }
        defer { freeifaddrs(firstAddr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let ifa = cursor {
            cursor = ifa.pointee.ifa_next

            guard let name = ifa.pointee.ifa_name,
                  let addrPtr = ifa.pointee.ifa_addr,
                  addrPtr.pointee.sa_family == sa_family_t(AF_LINK),
                  let dataPtr = ifa.pointee.ifa_data else { continue }

            let data = dataPtr.assumingMemoryBound(to: if_data.self)
            result[String(cString: name)] = InterfaceStats(
                rxBytes: UInt64(data.pointee.ifi_ibytes),
                txBytes: UInt64(data.pointee.ifi_obytes)
            )
        }

        return result
    }
}
