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
        cpu.start()
        gpu.start()
        memory.start()
        disk.start()
        battery.start()
        network.start()
        processes.start()
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

