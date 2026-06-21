import AppKit
import Combine
import SwiftUI

@main
struct NetSpeedBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No main window – the app lives only in the menu bar.
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: NetworkMonitor!
    private var statusController: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor = NetworkMonitor(interval: 1.0)
        statusController = StatusBarController(monitor: monitor)
        monitor.start()
    }
}

// MARK: - Status Bar Controller

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let monitor: NetworkMonitor
    private var cancellables = Set<AnyCancellable>()

    init(monitor: NetworkMonitor) {
        self.monitor = monitor
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        renderLabel(down: 0, up: 0)
        observeSpeeds()

        statusItem.menu = NSMenu()
        statusItem.menu?.delegate = self
    }

    private func observeSpeeds() {
        monitor.$downloadBytesPerSec
            .combineLatest(monitor.$uploadBytesPerSec)
            .receive(on: RunLoop.main)
            .sink { [weak self] down, up in
                self?.renderLabel(down: down, up: up)
            }
            .store(in: &cancellables)
    }

    private func renderLabel(down: Double, up: Double) {
        guard let button = statusItem.button else { return }

        button.attributedTitle = NSAttributedString(
            string: SpeedFormatter.barLabel(down: down, up: up),
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)]
        )

        if monitor.history.count >= 2 {
            button.image = BarSparkline.image(for: monitor.history)
            button.imagePosition = .imageLeft
            button.imageScaling = .scaleNone
        }
    }
}

// MARK: - Menu Building

extension StatusBarController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.autoenablesItems = false

        addSpeedHeader(to: menu)
        addGraphSection(to: menu)
        addIntervalSection(to: menu)
        addInterfaceSection(to: menu)
        addSystemSection(to: menu)
        addQuitItem(to: menu)
    }

    private func addSpeedHeader(to menu: NSMenu) {
        menu.add(disabled: "↓ \(SpeedFormatter.rate(bytesPerSec: monitor.downloadBytesPerSec))")
        menu.add(disabled: "↑ \(SpeedFormatter.rate(bytesPerSec: monitor.uploadBytesPerSec))")
        menu.addItem(.separator())
    }

    private func addGraphSection(to menu: NSMenu) {
        menu.add(disabled: "Last 2 minutes")

        let graphItem = NSMenuItem()
        graphItem.view = NSHostingView(
            rootView: SpeedGraphView(monitor: monitor)
                .frame(width: 300, height: 110)
                .padding(.vertical, 4)
        )
        graphItem.isEnabled = false
        menu.addItem(graphItem)
        menu.addItem(.separator())
    }

    private func addIntervalSection(to menu: NSMenu) {
        menu.add(disabled: "Poll interval")

        for entry in AppConstants.pollIntervals {
            let selected = abs(entry.seconds - monitor.interval) < 0.001
            let prefix = selected ? "✓" : " "
            let item = NSMenuItem(
                title: "\(prefix) \(entry.label)",
                action: #selector(setInterval(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = entry.seconds
            menu.addItem(item)
        }
        menu.addItem(.separator())
    }

    private func addInterfaceSection(to menu: NSMenu) {
        if monitor.perInterface.isEmpty {
            menu.add(disabled: "No active interfaces")
            return
        }

        menu.add(disabled: "Per Interface")
        for (name, rates) in monitor.perInterface.sorted(by: { $0.key < $1.key }) {
            let label = "\(name)   ↓ \(SpeedFormatter.rate(bytesPerSec: rates.down))   ↑ \(SpeedFormatter.rate(bytesPerSec: rates.up))"
            menu.add(disabled: label)
        }
    }

    private func addSystemSection(to menu: NSMenu) {
        menu.addItem(.separator())
        menu.add(disabled: "System")

        if let memory = SystemMonitor.memoryStatus() {
            let free = SpeedFormatter.bytes(memory.freeBytes)
            let total = SpeedFormatter.bytes(memory.totalBytes)
            menu.add(disabled: "Free memory   \(free) / \(total)")
        } else {
            menu.add(disabled: "Free memory   unavailable")
        }
    }

    private func addQuitItem(to menu: NSMenu) {
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit NetSpeedBar",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
    }

    @objc private func setInterval(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? Double {
            monitor.setInterval(value)
        } else if let value = sender.representedObject as? NSNumber {
            monitor.setInterval(value.doubleValue)
        }
    }
}

// MARK: - Helpers

private extension NSMenu {
    func removeAllItems() {
        while !items.isEmpty {
            removeItem(at: 0)
        }
    }

    func add(disabled title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        addItem(item)
    }
}
