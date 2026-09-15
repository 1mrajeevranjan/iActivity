import Foundation
import Observation

@MainActor
@Observable
class CPUMonitor {
    var usage: Double = 0
    var coreUsages: [Double] = []
    var history: [Double] = Array(repeating: 0, count: 60)
    var temperature: Double = 0
    var modelName: String = "Apple Silicon"

    /// How many of the cores in `coreUsages` are efficiency cores. On Apple Silicon the kernel
    /// reports them first, so indices `0..<efficiencyCoreCount` are E-cores and the rest are P.
    /// Zero on Intel, where there is no split and every core is just "Core N".
    var efficiencyCoreCount: Int = 0

    /// Label and class for one core, for the expanded core list.
    func coreKind(at index: Int) -> CoreKind {
        guard efficiencyCoreCount > 0 else { return .undifferentiated(index) }
        return index < efficiencyCoreCount
            ? .efficiency(index + 1)
            : .performance(index - efficiencyCoreCount + 1)
    }

    enum CoreKind {
        case efficiency(Int)
        case performance(Int)
        case undifferentiated(Int)

        var label: String {
            switch self {
            case .efficiency(let n): return "E-Core \(n)"
            case .performance(let n): return "P-Core \(n)"
            case .undifferentiated(let n): return "Core \(n)"
            }
        }

        /// Spoken in full — VoiceOver reads "E-Core" as the letter E.
        var spokenLabel: String {
            switch self {
            case .efficiency(let n): return "Efficiency core \(n)"
            case .performance(let n): return "Performance core \(n)"
            case .undifferentiated(let n): return "Core \(n)"
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

        // perflevel0 is the Performance cluster, perflevel1 the Efficiency one. Both keys are
        // absent on Intel, where the count stays zero and the cores go unlabelled.
        self.efficiencyCoreCount = Self.sysctlInt("hw.perflevel1.logicalcpu") ?? 0
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
            
            // Cleanup previous info
            let prevSize = MemoryLayout<integer_t>.stride * Int(previousCount)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: previousInfo)), vm_size_t(prevSize))
        }
        
        self.previousInfo = processorInfo
        self.previousCount = infoCount
    }
}
