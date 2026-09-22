import Foundation
import Observation

@MainActor
@Observable
class CPUMonitor {
    var usage: Double = 0
    var coreUsages: [Double] = []
    var history: [Double] = Array(repeating: 0, count: 60)

    /// Mean utilisation of each cluster, and their own history buffers. The overall `usage`
    /// above averages every core together, which hides exactly the thing a P/E machine is
    /// interesting for: four performance cores pinned while six efficiency cores idle reads
    /// as a middling number that describes neither cluster.
    var performanceUsage: Double = 0
    var efficiencyUsage: Double = 0
    var performanceHistory: [Double] = Array(repeating: 0, count: 60)
    var efficiencyHistory: [Double] = Array(repeating: 0, count: 60)
    var temperature: Double = 0
    var modelName: String = "Apple Silicon"

    /// How many of the cores in `coreUsages` sit below the most performant cluster. The kernel
    /// enumerates the least performant cores first, so indices `0..<efficiencyCoreCount` are
    /// those and the rest are the top cluster. Zero on Intel, where there is no split at all.
    var efficiencyCoreCount: Int = 0

    /// The CPU's clusters, in core-enumeration order, named by macOS itself.
    var clusters: [CoreCluster] = []

    /// macOS's own names for the two ends of the split, used by the legend and the cluster row.
    /// The fallbacks only apply where there is no split to name.
    var performanceClusterName: String { clusters.last?.name ?? "Performance" }
    var efficiencyClusterName: String { (clusters.count >= 2 ? clusters.first?.name : nil) ?? "Efficiency" }

    /// One of the CPU's performance clusters, named by macOS itself.
    ///
    /// `hw.perflevelN.name` is what the kernel calls each cluster on this exact machine —
    /// "Performance" and "Efficiency" on an M4. Reading it means the labels follow whatever
    /// Apple ships next, instead of this app carrying a table of per-chip core names that
    /// would have to be guessed at now and corrected with every new generation.
    struct CoreCluster: Sendable, Equatable {
        /// macOS's own name for the cluster, e.g. "Performance".
        let name: String
        /// Compact form for the narrow core-list column, e.g. "P-Core".
        let shortName: String
        let coreCount: Int
    }

    /// Builds the cluster list in CORE ENUMERATION order, which is the reverse of the sysctl
    /// order: `host_processor_info` enumerates the least performant cores first. Verified on an
    /// M4, where `perflevel0` is Performance with 4 cores but indices 0–5 are the 6 Efficiency
    /// cores. `nonisolated` and pure so the naming is testable without a sysctl.
    nonisolated static func clusters(levelNames: [String], levelCounts: [Int]) -> [CoreCluster] {
        let levels = min(levelNames.count, levelCounts.count)
        guard levels > 0 else { return [] }
        let names = Array(levelNames.prefix(levels).reversed())
        let counts = Array(levelCounts.prefix(levels).reversed())
        let shortNames = names.map { name in name.first.map { "\($0)-Core" } ?? name }
        // Two clusters whose names share an initial would render as two identical labels, so
        // the whole set falls back to the names macOS reported rather than inventing one.
        let initialsAreDistinct = Set(shortNames).count == shortNames.count
        return (0..<levels).map { index in
            CoreCluster(
                name: names[index],
                shortName: initialsAreDistinct ? shortNames[index] : names[index],
                coreCount: counts[index]
            )
        }
    }

    /// True only where the kernel actually reports two clusters. Intel has none, and drawing a
    /// P/E split there would be inventing a distinction the hardware does not make.
    var hasCoreSplit: Bool { efficiencyCoreCount > 0 }

    /// Mean utilisation of each cluster. `nonisolated` and pure: it takes the readings rather
    /// than reaching for them, so the split can be tested without a Mach call.
    ///
    /// On Apple Silicon the kernel reports efficiency cores first, so `0..<efficiencyCoreCount`
    /// are E and the remainder are P — the same convention `coreKind(at:)` relies on. The count
    /// is clamped because it comes from a sysctl that may not agree with the core list.
    nonisolated static func clusterAverages(
        coreUsages: [Double],
        efficiencyCoreCount: Int
    ) -> (performance: Double, efficiency: Double) {
        guard !coreUsages.isEmpty else { return (0, 0) }
        let split = min(max(efficiencyCoreCount, 0), coreUsages.count)
        func mean(_ values: ArraySlice<Double>) -> Double {
            values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        }
        return (mean(coreUsages.dropFirst(split)), mean(coreUsages.prefix(split)))
    }

    /// Label and class for one core, for the expanded core list.
    func coreKind(at index: Int) -> CoreKind {
        guard clusters.count >= 2 else { return .undifferentiated(index + 1) }
        var start = 0
        for (offset, cluster) in clusters.enumerated() {
            let end = start + cluster.coreCount
            if index < end {
                let ordinal = index - start + 1
                // The last cluster in enumeration order is perflevel0, the most performant one.
                return offset == clusters.count - 1
                    ? .performance(ordinal: ordinal, cluster: cluster)
                    : .efficiency(ordinal: ordinal, cluster: cluster)
            }
            start = end
        }
        return .undifferentiated(index + 1)
    }

    /// Which end of the split a core sits on, carrying the cluster macOS named it after so the
    /// labels never hardcode "P-Core" for a chip that calls it something else.
    enum CoreKind: Equatable {
        case efficiency(ordinal: Int, cluster: CoreCluster)
        case performance(ordinal: Int, cluster: CoreCluster)
        case undifferentiated(Int)

        var label: String {
            switch self {
            case .efficiency(let ordinal, let cluster), .performance(let ordinal, let cluster):
                return "\(cluster.shortName) \(ordinal)"
            case .undifferentiated(let ordinal):
                return "Core \(ordinal)"
            }
        }

        /// Spoken in full — VoiceOver reads an abbreviation like "E-Core" as the letter E.
        var spokenLabel: String {
            switch self {
            case .efficiency(let ordinal, let cluster), .performance(let ordinal, let cluster):
                return "\(cluster.name) core \(ordinal)"
            case .undifferentiated(let ordinal):
                return "Core \(ordinal)"
            }
        }
    }

    private var timer: Timer?
    private var previousInfo: processor_info_array_t?
    private var previousCount: mach_msg_type_number_t = 0
    private var currentInterval: TimeInterval = 2.0
    
    init() {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        let brandString = brand.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        self.modelName = brandString.trimmingCharacters(in: .controlCharacters)

        // macOS names its own clusters, so the labels follow whatever chip this is. Every one
        // of these keys is absent on Intel, where there are no clusters and each core is just
        // "Core N".
        let levelCount = max(Self.sysctlInt("hw.nperflevels") ?? 0, 0)
        let levelNames = (0..<levelCount).compactMap { Self.sysctlString("hw.perflevel\($0).name") }
        let levelCounts = (0..<levelCount).compactMap { Self.sysctlInt("hw.perflevel\($0).logicalcpu") }
        self.clusters = Self.clusters(levelNames: levelNames, levelCounts: levelCounts)
        // Everything below the most performant cluster. `clusterAverages` splits the core list
        // at this index and `coreKind` tints those cores as efficiency cores.
        self.efficiencyCoreCount = self.clusters.dropLast().reduce(0) { $0 + $1.coreCount }
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let value = buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func sysctlInt(_ name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return Int(value)
    }
    
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
        // Deliberately keeps `previousInfo` — clearing it here (as this used to) means every
        // restart's first tick has no baseline to diff against, so `update()` produces no data
        // at all: 0% usage, an empty core list, until the *second* tick. Invisible when the
        // monitor only ever started once at launch, but glaring now that pausing/resuming with
        // the dashboard panel restarts it constantly — every reopened tab flashed blank. Every
        // other monitor already gets this right; the stale-but-present baseline just means the
        // first post-resume reading averages over the paused interval, same as they do.
    }
    
    private func update() {
        let host = mach_host_self()
        var processorCount: UInt32 = 0
        var processorInfo: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        
        let result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &processorCount, &processorInfo, &infoCount)
        
        guard result == KERN_SUCCESS, let processorInfo = processorInfo else { return }
        
        // Update temperature from SMCHelper
        if let temp = SMCHelper.readTemperature("TC0P") {
            self.temperature = temp
        }
        
        var totalUsage: Double = 0
        var coreUsages: [Double] = []
        
        if let previousInfo = previousInfo, infoCount == previousCount {
            for i in 0..<Int(processorCount) {
                let base = i * Int(CPU_STATE_MAX)
                let prevBase = i * Int(CPU_STATE_MAX)
                
                let user = Double(processorInfo[base + Int(CPU_STATE_USER)] - previousInfo[prevBase + Int(CPU_STATE_USER)])
                let system = Double(processorInfo[base + Int(CPU_STATE_SYSTEM)] - previousInfo[prevBase + Int(CPU_STATE_SYSTEM)])
                let idle = Double(processorInfo[base + Int(CPU_STATE_IDLE)] - previousInfo[prevBase + Int(CPU_STATE_IDLE)])
                let nice = Double(processorInfo[base + Int(CPU_STATE_NICE)] - previousInfo[prevBase + Int(CPU_STATE_NICE)])
                
                let total = user + system + idle + nice
                let usage = total > 0 ? (user + system + nice) / total : 0
                
                coreUsages.append(usage)
                totalUsage += usage
            }
            
            let avgUsage = totalUsage / Double(processorCount)
            self.usage = avgUsage
            self.coreUsages = coreUsages
            self.history.removeFirst()
            self.history.append(avgUsage)

            let clusters = Self.clusterAverages(coreUsages: coreUsages, efficiencyCoreCount: efficiencyCoreCount)
            self.performanceUsage = clusters.performance
            self.efficiencyUsage = clusters.efficiency
            self.performanceHistory.removeFirst()
            self.performanceHistory.append(clusters.performance)
            self.efficiencyHistory.removeFirst()
            self.efficiencyHistory.append(clusters.efficiency)
            
            // Cleanup previous info
            let prevSize = MemoryLayout<integer_t>.stride * Int(previousCount)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: previousInfo)), vm_size_t(prevSize))
        }
        
        self.previousInfo = processorInfo
        self.previousCount = infoCount
    }
}
