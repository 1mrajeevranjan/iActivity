import Foundation
import Darwin
import Observation

// MARK: - C interop for libproc
// These match the macOS <sys/proc_info.h> structures
private let PROC_PIDTASKINFO_FLAVOR: Int32 = 4
private let PROC_PIDVNODEPATHINFO_FLAVOR: Int32 = 9

// Matches struct proc_taskinfo in <sys/proc_info.h>
private struct proc_taskinfo_raw {
    var pti_virtual_size: UInt64 = 0
    var pti_resident_size: UInt64 = 0
    var pti_total_user: UInt64 = 0
    var pti_total_system: UInt64 = 0
    var pti_threads_user: UInt64 = 0
    var pti_threads_system: UInt64 = 0
    var pti_policy: Int32 = 0
    var pti_faults: Int32 = 0
    var pti_pageins: Int32 = 0
    var pti_cow_faults: Int32 = 0
    var pti_messages_sent: Int32 = 0
    var pti_messages_received: Int32 = 0
    var pti_syscalls_mach: Int32 = 0
    var pti_syscalls_unix: Int32 = 0
    var pti_csw: Int32 = 0
    var pti_threadnum: Int32 = 0
    var pti_numrunning: Int32 = 0
    var pti_priority: Int32 = 0
}

@MainActor
@Observable
class ProcessMonitor {
    
    struct ProcessEntry: Identifiable, Sendable {
        let id = UUID()
        let pid: Int32
        let name: String
        let cpuPercent: Double
        let memoryMB: Double
    }
    
    var processes: [ProcessEntry] = []
    private var timer: Timer?
    
    // MARK: - Previous CPU snapshot for delta calculation
    private var prevSnapshot: [Int32: (user: UInt64, system: UInt64, time: Double)] = [:]
    
    // MARK: - Top 5 sorted views
    
    var topByCPU: [ProcessEntry] {
        Array(processes
            .filter { $0.cpuPercent > 0 }
            .sorted { $0.cpuPercent > $1.cpuPercent }
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
    
    nonisolated private static func fetchAll(
        prevSnapshot: [Int32: (user: UInt64, system: UInt64, time: Double)]
    ) -> ([ProcessEntry], [Int32: (user: UInt64, system: UInt64, time: Double)]) {
        
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
        var newSnapshot: [Int32: (user: UInt64, system: UInt64, time: Double)] = [:]
        
        for pid in pids {
            // 2. Get task info (memory + CPU ticks)
            var taskInfo = proc_taskinfo_raw()
            let infoSize = Int32(MemoryLayout<proc_taskinfo_raw>.size)
            let ret = withUnsafeMutablePointer(to: &taskInfo) { ptr in
                ptr.withMemoryRebound(to: UInt8.self, capacity: Int(infoSize)) { rawPtr in
                    proc_pidinfo(pid, PROC_PIDTASKINFO_FLAVOR, 0, rawPtr, infoSize)
                }
            }
            guard ret == infoSize else { continue }
            
            // 3. Get process name
            var nameBuffer = [CChar](repeating: 0, count: 1024)
            proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            let name = nameBuffer.withUnsafeBytes { bytes in
                String(bytes: bytes.prefix(while: { $0 != 0 }), encoding: .utf8) ?? ""
            }
            guard !name.isEmpty else { continue }
            
            // 4. Calculate CPU % from delta
            let userTicks = taskInfo.pti_total_user
            let sysTicks  = taskInfo.pti_total_system
            var cpuPercent = 0.0
            
            if let prev = prevSnapshot[pid] {
                let deltaUser   = Double(userTicks   &- prev.user)
                let deltaSys    = Double(sysTicks    &- prev.system)
                let deltaTime   = now - prev.time
                if deltaTime > 0 {
                    // ticks are in nanoseconds; 1e9 ns per sec
                    let totalNs = (deltaUser + deltaSys)
                    cpuPercent = (totalNs / 1e9) / deltaTime * 100.0
                }
            }
            
            newSnapshot[pid] = (user: userTicks, system: sysTicks, time: now)
            
            // 5. Memory in MB from resident_size (bytes)
            let memMB = Double(taskInfo.pti_resident_size) / (1024 * 1024)
            
            // Skip system kernel and idle
            if name == "kernel_task" || name == "launchd" { continue }
            
            entries.append(ProcessEntry(
                pid: pid,
                name: name,
                cpuPercent: cpuPercent,
                memoryMB: memMB
            ))
        }
        
        return (entries, newSnapshot)
    }
}
