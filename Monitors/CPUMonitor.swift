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
    
    private var timer: Timer?
    private var previousInfo: processor_info_array_t?
    private var previousCount: mach_msg_type_number_t = 0
    
    init() {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        let brandString = brand.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        self.modelName = brandString.trimmingCharacters(in: .controlCharacters)
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
        if let info = previousInfo {
            let infoSize = MemoryLayout<integer_t>.stride * Int(previousCount)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), vm_size_t(infoSize))
            previousInfo = nil
        }
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
