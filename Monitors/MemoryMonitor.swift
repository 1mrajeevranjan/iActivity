import Foundation
import Observation

@MainActor
@Observable
class MemoryMonitor {
    var total: Double = 0
    var used: Double = 0
    var free: Double = 0
    var active: Double = 0
    var inactive: Double = 0
    var wired: Double = 0
    var compressed: Double = 0
    var usageHistory: [Double] = Array(repeating: 0, count: 60)
    var temperature: Double = 0

    var usagePercentage: Double {
        total > 0 ? used / total : 0
    }

    private var timer: Timer?

    init() {
        var memSize: Int64 = 0
        var size = MemoryLayout<Int64>.size
        sysctlbyname("hw.memsize", &memSize, &size, nil, 0)
        self.total = Double(memSize)
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
        update()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func update() {
        // Update memory / SoC temperature
        temperature = SMCHelper.memoryTemperature()

        var stats = vm_statistics64()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &size)
            }
        }

        guard result == KERN_SUCCESS else { return }

        let pageSize = Double(getpagesize())
        self.active = Double(stats.active_count) * pageSize
        self.inactive = Double(stats.inactive_count) * pageSize
        self.wired = Double(stats.wire_count) * pageSize
        self.compressed = Double(stats.compressor_page_count) * pageSize
        self.free = Double(stats.free_count) * pageSize

        self.used = active + wired + compressed

        self.usageHistory.removeFirst()
        self.usageHistory.append(usagePercentage)
    }
}
