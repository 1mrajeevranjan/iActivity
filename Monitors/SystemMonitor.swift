import SwiftUI
import Observation

@MainActor
@Observable
class SystemMonitor {
    var cpu = CPUMonitor()
    var gpu = GPUMonitor()
    var memory = MemoryMonitor()
    var disk = DiskMonitor()
    var battery = BatteryMonitor()
    var network = NetworkMonitor()
    var processes = ProcessMonitor()

    /// Tracks pause/resume state so `applyInterval` — triggered from Settings independently of the
    /// panel — knows whether to touch all six monitors or just the menu bar's active one.
    private var isPanelVisible = false

    init() {
        // Only the category the menu bar displays needs to be live before the dashboard is ever
        // opened — the other five monitors and the process scanner (a full system-wide process
        // walk) have nothing to feed until then.
        pauseBackground()
    }

    /// Every monitor at the user's configured cadence — used while the dashboard panel is open,
    /// since any tab (and its process list) can be switched to at any time.
    func resumeAll() {
        isPanelVisible = true
        if let custom = UserDefaults.standard.object(forKey: "updateInterval") as? Double, custom > 0 {
            applyInterval(custom)
        } else {
            cpu.start()
            gpu.start()
            memory.start()
            disk.start()
            battery.start()
            network.start()
        }
        processes.start()
    }

    /// Stops every monitor except the one feeding the menu bar, and the process scanner — used
    /// while the dashboard panel is closed, when nothing else is visible to update. `interval`
    /// re-applies a just-changed Settings cadence to the still-running active monitor; `nil` just
    /// keeps whatever cadence it already had.
    func pauseBackground(interval: TimeInterval? = nil) {
        isPanelVisible = false
        let activeRaw = UserDefaults.standard.string(forKey: "selectedCategory") ?? MetricCategory.cpu.rawValue
        let active = MetricCategory(rawValue: activeRaw) ?? .cpu

        if active != .cpu { cpu.stop() } else { cpu.start(interval: interval) }
        if active != .gpu { gpu.stop() } else { gpu.start(interval: interval) }
        if active != .memory { memory.stop() } else { memory.start(interval: interval) }
        if active != .disk { disk.stop() } else { disk.start(interval: interval) }
        if active != .battery { battery.stop() } else { battery.start(interval: interval) }
        if active != .network { network.stop() } else { network.start(interval: interval) }
        processes.stop()
    }

    /// Overrides the refresh cadence (used by Settings). While the panel is hidden this only
    /// touches the menu bar's active monitor — applying it to all six would silently undo
    /// `pauseBackground()` the next time Settings' "Update Every" picker changes.
    func applyInterval(_ interval: TimeInterval) {
        guard isPanelVisible else {
            pauseBackground(interval: interval)
            return
        }
        cpu.start(interval: interval)
        gpu.start(interval: interval)
        memory.start(interval: interval)
        disk.start(interval: interval)
        battery.start(interval: interval)
        network.start(interval: interval)
    }

    func stop() {
        cpu.stop()
        gpu.stop()
        memory.stop()
        disk.stop()
        battery.stop()
        network.stop()
        processes.stop()
    }
}

