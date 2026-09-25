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
    var appMemory: Double = 0
    var cached: Double = 0
    var swapUsed: Double = 0
    var pressure: Pressure = .normal
    var usageHistory: [Double] = Array(repeating: 0, count: 60)
    var temperature: Double = 0

    var usagePercentage: Double {
        total > 0 ? used / total : 0
    }

    /// The kernel's own memory-pressure verdict — the same signal Activity Monitor's pressure
    /// graph colours by. Used percentage alone says nothing about pressure: a Mac at 95% used
    /// with plenty of reclaimable cache is not under pressure at all.
    enum Pressure: Int {
        case normal = 1, warning = 2, critical = 4
    }

    private static func pressureLevel() -> Pressure {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else { return .normal }
        return Pressure(rawValue: Int(level)) ?? .normal
    }

    private static func swapUsage() -> Double {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return 0 }
        return Double(usage.xsu_used)
    }

    private var timer: Timer?
    private var currentInterval: TimeInterval = 2.0
    /// Asked once: every `mach_host_self()` call adds a send-right reference that is never freed.
    private static let host = mach_host_self()

    init() {
        var memSize: Int64 = 0
        var size = MemoryLayout<Int64>.size
        sysctlbyname("hw.memsize", &memSize, &size, nil, 0)
        self.total = Double(memSize)
    }

    func start(interval: TimeInterval? = nil) {
        stop()
        if let interval { currentInterval = interval }
        // Scheduled on the main run loop, so the callback is already on the main actor. The
        // tolerance lets macOS coalesce this wakeup with the other monitors' and the system's.
        timer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        timer?.tolerance = currentInterval * 0.1
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
        let hostPort = Self.host

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
        // Activity Monitor's breakdown: App Memory is anonymous memory that can't simply be
        // dropped, Cached Files is file-backed or purgeable memory the system reclaims on demand.
        // "Memory Used" is App + Wired + Compressed — counting all of `active` (as this used to)
        // included file cache and overstated usage by gigabytes.
        let purgeable = Double(stats.purgeable_count) * pageSize
        self.appMemory = max(Double(stats.internal_page_count) * pageSize - purgeable, 0)
        self.cached = Double(stats.external_page_count) * pageSize + purgeable

        self.used = appMemory + wired + compressed
        self.pressure = Self.pressureLevel()
        self.swapUsed = Self.swapUsage()

        self.usageHistory.removeFirst()
        self.usageHistory.append(usagePercentage)
    }
}
