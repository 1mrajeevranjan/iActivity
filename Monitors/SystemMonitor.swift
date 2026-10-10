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
    private var activeCategories: Set<MetricCategory> = []
    private var timer: Timer?
    private var samplingInterval: TimeInterval = RefreshInterval.normal.rawValue

    init() {
        // Only the categories the menu bar displays need to be live before the dashboard is
        // ever opened — the remaining monitors and the process scanner (a full system-wide
        // process walk) have nothing to feed until then.
        pauseBackground(interval: currentInterval)
    }

    /// Every monitor at the user's configured cadence — used while the dashboard panel is open,
    /// since any tab (and its process list) can be switched to at any time.
    func resumeAll() {
        isPanelVisible = true
        SMCHelper.isDashboardVisible = true
        applyInterval(currentInterval)
    }

    private var currentInterval: TimeInterval {
        let stored = UserDefaults.standard.object(forKey: "updateInterval") as? Double
        return stored.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? RefreshInterval.normal.rawValue
    }

    /// Stops every monitor the menu bar is not showing, plus the process scanner — used while
    /// the dashboard panel is closed, when nothing else is visible to update. `interval`
    /// re-applies a just-changed Settings cadence to the monitors still running; `nil` just
    /// keeps whatever cadence they already had.
    func pauseBackground(interval: TimeInterval? = nil) {
        isPanelVisible = false
        SMCHelper.isDashboardVisible = false
        processes.stop()
        activeCategories = Set(MenuBarSelection.current.categories)
        schedule(interval: interval)
    }

    /// Overrides the refresh cadence (used by Settings). While the panel is hidden this only
    /// touches the menu bar's active monitors — applying it to all six would silently undo
    /// `pauseBackground()` the next time Settings' "Update Every" picker changes.
    func applyInterval(_ interval: TimeInterval) {
        guard interval.isFinite, interval > 0 else { return }
        guard isPanelVisible else {
            pauseBackground(interval: interval)
            return
        }
        processes.stop()
        activeCategories = Set(MetricCategory.allCases)
        schedule(interval: interval)
    }

    /// Re-applies the pause policy after the menu bar's category set changes. Without this a
    /// newly ticked category shows a frozen reading until the dashboard is next opened.
    func menuBarSelectionChanged() {
        guard !isPanelVisible else { return }
        pauseBackground(interval: currentInterval)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        processes.stop()
        activeCategories = []
        isPanelVisible = false
        SMCHelper.isDashboardVisible = false
    }

    isolated deinit {
        timer?.invalidate()
    }

    private func schedule(interval: TimeInterval?) {
        if let interval, interval.isFinite, interval > 0 { samplingInterval = interval }
        timer?.invalidate()
        // ponytail: one clock batches every live reading and its UI update. Seven independent
        // timers staggered kernel calls and redraws; all categories still keep the chosen cadence.
        let timer = Timer(timeInterval: samplingInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        timer.tolerance = samplingInterval * 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        update()
    }

    private func update() {
        if activeCategories.contains(.cpu) { cpu.update() }
        if activeCategories.contains(.gpu) { gpu.update() }
        if activeCategories.contains(.memory) { memory.update() }
        if activeCategories.contains(.disk) { disk.update() }
        if activeCategories.contains(.battery) { battery.update() }
        if activeCategories.contains(.network) { network.update() }
        if isPanelVisible { processes.update() }
    }
}

