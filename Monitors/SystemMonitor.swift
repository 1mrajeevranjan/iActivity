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

    /// Tracks pause/resume state so `applyInterval` — triggered from Settings independently of
    /// the panel — knows whether to touch all six monitors or just the menu bar's active set.
    private var isPanelVisible = false

    init() {
        // Only the categories the menu bar displays need to be live before the dashboard is
        // ever opened — the remaining monitors and the process scanner (a full system-wide
        // process walk) have nothing to feed until then.
        pauseBackground()
    }

    /// Every monitor at the user's configured cadence — used while the dashboard panel is open,
    /// since any tab (and its process list) can be switched to at any time.
    func resumeAll() {
        isPanelVisible = true
        SMCHelper.isDashboardVisible = true
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

    /// Stops every monitor the menu bar is not showing, plus the process scanner — used while
    /// the dashboard panel is closed, when nothing else is visible to update. `interval`
    /// re-applies a just-changed Settings cadence to the monitors still running; `nil` just
    /// keeps whatever cadence they already had.
    func pauseBackground(interval: TimeInterval? = nil) {
        isPanelVisible = false
        SMCHelper.isDashboardVisible = false
        // The menu bar may now show several categories at once, so this keeps the whole set
        // alive rather than a single one. Idle cost scales with that set — the price of the
        // feature, and the reason Settings says so next to the picker.
        let active = Set(MenuBarSelection.current.categories)

        if active.contains(.cpu) { cpu.start(interval: interval) } else { cpu.stop() }
        if active.contains(.gpu) { gpu.start(interval: interval) } else { gpu.stop() }
        if active.contains(.memory) { memory.start(interval: interval) } else { memory.stop() }
        if active.contains(.disk) { disk.start(interval: interval) } else { disk.stop() }
        if active.contains(.battery) { battery.start(interval: interval) } else { battery.stop() }
        if active.contains(.network) { network.start(interval: interval) } else { network.stop() }
        processes.stop()
    }

    /// Overrides the refresh cadence (used by Settings). While the panel is hidden this only
    /// touches the menu bar's active monitors — applying it to all six would silently undo
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

    /// Re-applies the pause policy after the menu bar's category set changes. Without this a
    /// newly ticked category shows a frozen reading until the dashboard is next opened.
    func menuBarSelectionChanged() {
        guard !isPanelVisible else { return }
        pauseBackground()
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

