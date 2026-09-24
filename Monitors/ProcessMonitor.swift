import Foundation
import Darwin
import Observation

@MainActor
@Observable
class ProcessMonitor {
    
    struct ProcessEntry: Identifiable, Sendable {
        let id = UUID()
        let pid: Int32
        let name: String
        let cpuPercent: Double
        let memoryMB: Double
        /// Bytes read plus written per second since the previous sample.
        let diskBytesPerSecond: Double
    }

    /// Cumulative counters from the previous sample, diffed to get rates.
    struct Sample: Sendable {
        let cpuTime: UInt64
        let diskBytes: UInt64
        let time: Double
    }
    
    var processes: [ProcessEntry] = []
    private var timer: Timer?
    
    // MARK: - Previous CPU snapshot for delta calculation
    private var prevSnapshot: [Int32: Sample] = [:]
    
    // MARK: - Top 5 sorted views
    
    var topByCPU: [ProcessEntry] {
        Array(processes
            .filter { $0.cpuPercent > 0 }
            .sorted { $0.cpuPercent > $1.cpuPercent }
            .prefix(5))
    }
    
    var topByDisk: [ProcessEntry] {
        Array(processes
            .filter { $0.diskBytesPerSecond > 0 }
            .sorted { $0.diskBytesPerSecond > $1.diskBytesPerSecond }
            .prefix(5))
    }

    var topByMemory: [ProcessEntry] {
        Array(processes
            .filter { $0.memoryMB > 1 }
            .sorted { $0.memoryMB > $1.memoryMB }
            .prefix(5))
    }
    
    // MARK: - Lifecycle
    
    func start() {
        stop()
        // Fetch immediately on start
        doFetch()
        // Then every 5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.doFetch()
            }
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Fetch (called on any thread, posts to main)
    
    private func doFetch() {
        let snapshot = self.prevSnapshot
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let (entries, newSnapshot) = Self.fetchAll(prevSnapshot: snapshot)
            DispatchQueue.main.async {
                self.prevSnapshot = newSnapshot
                self.processes = entries
            }
        }
    }
    
    // MARK: - Native proc data fetching (runs on background thread)
    
    /// Mach absolute-time ticks per nanosecond. Process CPU times arrive in ticks, and on Apple
    /// Silicon a tick is 41.67 ns, not 1 — treating them as nanoseconds (as this used to) showed
    /// every process at about 1/42 of its real CPU usage.
    nonisolated private static let nanosecondsPerTick: Double = {
        var info = mach_timebase_info()
        mach_timebase_info(&info)
        return info.denom > 0 ? Double(info.numer) / Double(info.denom) : 1
    }()

    nonisolated private static func fetchAll(
        prevSnapshot: [Int32: Sample]
    ) -> ([ProcessEntry], [Int32: Sample]) {

        // 1. Get list of all PIDs
        let capacity = 4096
        let pidBuffer = UnsafeMutablePointer<Int32>.allocate(capacity: capacity)
        defer { pidBuffer.deallocate() }

        let byteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, pidBuffer, Int32(capacity * MemoryLayout<Int32>.size))
        guard byteCount > 0 else { return ([], [:]) }

        let pidCount = Int(byteCount) / MemoryLayout<Int32>.size
        let pids = Array(UnsafeBufferPointer(start: pidBuffer, count: pidCount)).filter { $0 > 0 }

        let now = Date().timeIntervalSinceReferenceDate
        var entries: [ProcessEntry] = []
        var newSnapshot: [Int32: Sample] = [:]

        for pid in pids {
            // 2. One call gives CPU time, memory footprint and disk I/O.
            var usage = rusage_info_v4()
            let ret = withUnsafeMutablePointer(to: &usage) { ptr in
                ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
                }
            }
            guard ret == 0 else { continue }

            // 3. Get process name
            var nameBuffer = [CChar](repeating: 0, count: 1024)
            proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            let name = nameBuffer.withUnsafeBytes { bytes in
                String(bytes: bytes.prefix(while: { $0 != 0 }), encoding: .utf8) ?? ""
            }
            guard !name.isEmpty else { continue }

            // 4. Rates from the delta against the previous sample
            let sample = Sample(
                cpuTime: usage.ri_user_time &+ usage.ri_system_time,
                diskBytes: usage.ri_diskio_bytesread &+ usage.ri_diskio_byteswritten,
                time: now
            )
            var cpuPercent = 0.0
            var diskRate = 0.0
            // A counter going backwards means the pid was reused by a new process — no baseline.
            if let prev = prevSnapshot[pid], now > prev.time,
               sample.cpuTime >= prev.cpuTime, sample.diskBytes >= prev.diskBytes {
                let elapsed = now - prev.time
                let cpuNs = Double(sample.cpuTime &- prev.cpuTime) * nanosecondsPerTick
                cpuPercent = cpuNs / 1e9 / elapsed * 100.0
                diskRate = Double(sample.diskBytes &- prev.diskBytes) / elapsed
            }
            newSnapshot[pid] = sample

            // 5. Physical footprint is what Activity Monitor's Memory column shows; resident size
            // also counts shared framework pages and overstated every app.
            let memMB = Double(usage.ri_phys_footprint) / (1024 * 1024)

            // Skip system kernel and idle
            if name == "kernel_task" || name == "launchd" { continue }

            entries.append(ProcessEntry(
                pid: pid,
                name: name,
                cpuPercent: cpuPercent,
                memoryMB: memMB,
                diskBytesPerSecond: diskRate
            ))
        }

        return (entries, newSnapshot)
    }
}
