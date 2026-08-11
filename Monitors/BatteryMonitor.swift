import Foundation
import Observation
import IOKit.ps

@MainActor
@Observable
class BatteryMonitor {
    var level: Int = 0
    var isCharging: Bool = false
    var powerSource: String = "Unknown"
    var timeToFull: Int = 0
    var timeToEmpty: Int = 0
    var temperature: Double = 0
    
    var watts: Double = 0
    var levelHistory: [Double] = Array(repeating: 0, count: 60)
    var powerHistory: [Double] = Array(repeating: 0, count: 60)
    
    var healthPercentage: Double = 0
    var cycleCount: Int = 0

    private var timer: Timer?
    private var currentInterval: TimeInterval = 5.0

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
        temperature = SMCHelper.batteryTemperature()

        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

        for source in sources {
            if let description = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] {
                if let capacity = description[kIOPSCurrentCapacityKey] as? Int,
                    let maxCapacity = description[kIOPSMaxCapacityKey] as? Int {
                    self.level = Int(Double(capacity) / Double(maxCapacity) * 100)
                }

                if let isCharging = description[kIOPSIsChargingKey] as? Bool {
                    self.isCharging = isCharging
                }

                if let powerSource = description[kIOPSPowerSourceStateKey] as? String {
                    self.powerSource = powerSource
                }

                if let timeToFull = description[kIOPSTimeToFullChargeKey] as? Int {
                    self.timeToFull = timeToFull
                }

                if let timeToEmpty = description[kIOPSTimeToEmptyKey] as? Int {
                    self.timeToEmpty = timeToEmpty
                }
                
                if let cycles = description["Cycle Count"] as? Int {
                    self.cycleCount = cycles
                }
                
                // kIOPSMaxCapacityKey/"DesignCapacity" here are already percentages (0-100),
                // not mAh — IOPSCopyPowerSourcesInfo never exposes a real DesignCapacity key at
                // all, so health is computed from raw AppleSmartBattery IORegistry fields below
                // instead (AppleRawMaxCapacity / DesignCapacity, both true mAh).

                // Calculate Watts
                if let voltage = description["Voltage"] as? Int,
                   let amperage = description["Current"] as? Int {
                    // voltage is in mV, amperage is in mA
                    self.watts = abs(Double(voltage) * Double(amperage)) / 1_000_000.0
                } else {
                    // Fallback for Apple Silicon or detailed stats from IORegistry
                    self.watts = fetchWattsFromIORegistry()
                }
            }
        }
        
        // Cycle count and health always come from raw IORegistry fields — IOPS never exposes a
        // real (mAh) DesignCapacity to compute health from.
        if self.cycleCount == 0 || self.healthPercentage == 0 {
            let props = fetchBatteryPropertiesFromIORegistry()
            if self.cycleCount == 0, let c = props.cycleCount { self.cycleCount = c }
            if self.healthPercentage == 0, let max = props.maxCapacity, let design = props.designCapacity, design > 0 {
                self.healthPercentage = min(100.0, Double(max) / Double(design) * 100.0)
            }
        }
        
        levelHistory.removeFirst()
        levelHistory.append(Double(level) / 100.0)
        
        powerHistory.removeFirst()
        powerHistory.append(watts)
    }

    private func fetchWattsFromIORegistry() -> Double {
        let matching = IOServiceMatching("AppleSmartBattery")
        var iter: io_iterator_t = 0
        var foundWatts: Double = 0
        
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == kIOReturnSuccess {
            var service = IOIteratorNext(iter)
            while service != 0 {
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                   let dict = props?.takeRetainedValue() as? [String: Any] {
                    let voltage = dict["Voltage"] as? Int ?? 0
                    let amperage = dict["Amperage"] as? Int ?? 0
                    // Amperage can be negative (discharging) or positive (charging)
                    foundWatts = abs(Double(voltage) * Double(amperage)) / 1_000_000.0
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iter)
            }
            IOObjectRelease(iter)
        }
        return foundWatts
    }
    
    private func fetchBatteryPropertiesFromIORegistry() -> (cycleCount: Int?, designCapacity: Int?, maxCapacity: Int?) {
        let matching = IOServiceMatching("AppleSmartBattery")
        var iter: io_iterator_t = 0
        var foundCycleCount: Int? = nil
        var foundDesignCapacity: Int? = nil
        var foundMaxCapacity: Int? = nil
        
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == kIOReturnSuccess {
            var service = IOIteratorNext(iter)
            while service != 0 {
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                   let dict = props?.takeRetainedValue() as? [String: Any] {
                    
                    if foundCycleCount == nil, let cycleCount = dict["CycleCount"] as? Int {
                        foundCycleCount = cycleCount
                    }
                    if foundDesignCapacity == nil, let designCapacity = dict["DesignCapacity"] as? Int {
                        foundDesignCapacity = designCapacity
                    }
                    // "MaxCapacity" at this layer is percentage-shaped (0-100), not mAh — the real
                    // mAh-scale max capacity, comparable to DesignCapacity, is AppleRawMaxCapacity.
                    if foundMaxCapacity == nil, let maxCapacity = dict["AppleRawMaxCapacity"] as? Int {
                        foundMaxCapacity = maxCapacity
                    }
                    
                    if foundCycleCount != nil && foundDesignCapacity != nil && foundMaxCapacity != nil {
                        IOObjectRelease(service)
                        break
                    }
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iter)
            }
            IOObjectRelease(iter)
        }
        
        return (cycleCount: foundCycleCount, designCapacity: foundDesignCapacity, maxCapacity: foundMaxCapacity)
    }
}
