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
    
    init() {
        start()
    }
    
    func start() {
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

    /// Overrides every monitor's refresh cadence with a single global interval (used by Settings).
    func applyInterval(_ interval: TimeInterval) {
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

