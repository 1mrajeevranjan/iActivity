import Foundation
import Observation

@MainActor
@Observable
class DiskMonitor {
    var total: Int64 = 0
    var free: Int64 = 0
    var used: Int64 = 0
    var usagePercentage: Double = 0
    var temperature: Double = 0
    
    var readSpeed: Double = 0
    var writeSpeed: Double = 0
    var readHistory: [Double] = Array(repeating: 0, count: 60)
    var writeHistory: [Double] = Array(repeating: 0, count: 60)

    private var timer: Timer?
    private var lastReadBytes: Int64 = 0
    private var lastWriteBytes: Int64 = 0
    private var lastUpdate: Date = Date()
    private var currentInterval: TimeInterval = 1.0
    /// The capacity query costs ~10 ms (it asks the system to total purgeable space), and free
    /// space moves slowly — so it runs on every start and then at most this often, not per tick.
    private static let usageRefreshInterval: TimeInterval = 30
    private var lastUsageRefresh: Date = .distantPast

    func start(interval: TimeInterval? = nil) {
        stop()
        if let interval { currentInterval = interval }
        lastUsageRefresh = .distantPast
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
        temperature = SMCHelper.diskTemperature()
        if Date().timeIntervalSince(lastUsageRefresh) >= Self.usageRefreshInterval {
            lastUsageRefresh = Date()
            updateUsage()
        }
        updateIOStats()
    }

    private func updateUsage() {
        // Finder's "Available" counts purgeable space (caches, local snapshots) that macOS frees
        // on demand; `systemFreeSize` does not, so it understated free space by tens of GB.
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let totalSize = values.volumeTotalCapacity,
              let freeSize = values.volumeAvailableCapacityForImportantUsage else { return }
        self.total = Int64(totalSize)
        self.free = freeSize
        self.used = max(self.total - freeSize, 0)
        self.usagePercentage = self.total > 0 ? Double(self.used) / Double(self.total) : 0
    }

    private func updateIOStats() {
        var read: Int64 = 0
        var write: Int64 = 0

        // Cumulative I/O byte counters live on IOBlockStorageDriver, keyed "Bytes (Read)" /
        // "Bytes (Write)" — not on IOMedia's "Statistics" dict, which doesn't carry those keys on
        // Apple Silicon's NVMe storage stack (verified against `ioreg -c IOBlockStorageDriver`).
        // Querying IOMedia here always returned nil, so read/write speed was silently stuck at 0
        // regardless of actual disk activity.
        let matching = IOServiceMatching("IOBlockStorageDriver")
        var iter: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == kIOReturnSuccess {
            var service = IOIteratorNext(iter)
            while service != 0 {
                // Just the one property — copying the driver's whole dictionary cost twice as much.
                if let stats = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString, kCFAllocatorDefault, 0)?
                    .takeRetainedValue() as? [String: Any] {
                    if let bytesRead = stats["Bytes (Read)"] as? NSNumber {
                        read += bytesRead.int64Value
                    }
                    if let bytesWritten = stats["Bytes (Write)"] as? NSNumber {
                        write += bytesWritten.int64Value
                    }
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iter)
            }
            IOObjectRelease(iter)
        }
        
        let now = Date()
        let interval = now.timeIntervalSince(lastUpdate)
        
        if lastReadBytes > 0 && interval > 0 {
            // A drive unmounting mid-interval drops its counters from the sum; clamp so that reads
            // as idle rather than a negative speed.
            readSpeed = Double(max(read - lastReadBytes, 0)) / interval
            writeSpeed = Double(max(write - lastWriteBytes, 0)) / interval
            
            readHistory.removeFirst()
            readHistory.append(readSpeed)
            writeHistory.removeFirst()
            writeHistory.append(writeSpeed)
        } else {
            // First run, just set the baseline
            readSpeed = 0
            writeSpeed = 0
        }
        
        lastReadBytes = read
        lastWriteBytes = write
        lastUpdate = now
    }
}
