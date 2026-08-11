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

    func start(interval: TimeInterval? = nil) {
        stop()
        if let interval { currentInterval = interval }
        timer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: true) { [weak self] _ in
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
        temperature = SMCHelper.diskTemperature()
        updateUsage()
        updateIOStats()
    }

    private func updateUsage() {
        let fileManager = FileManager.default
        do {
            let values = try fileManager.attributesOfFileSystem(forPath: "/")
            if let totalSize = values[.systemSize] as? Int64,
               let freeSize = values[.systemFreeSize] as? Int64 {
                self.total = totalSize
                self.free = freeSize
                self.used = totalSize - freeSize
                self.usagePercentage = totalSize > 0 ? Double(self.used) / Double(totalSize) : 0
            }
        } catch {}
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
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                   let dict = props?.takeRetainedValue() as? [String: Any],
                   let stats = dict["Statistics"] as? [String: Any] {
                    if let bytesRead = stats["Bytes (Read)"] as? Int64 {
                        read += bytesRead
                    }
                    if let bytesWritten = stats["Bytes (Write)"] as? Int64 {
                        write += bytesWritten
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
            readSpeed = Double(read - lastReadBytes) / interval
            writeSpeed = Double(write - lastWriteBytes) / interval
            
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
