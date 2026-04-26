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

    private var timer: Timer?

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
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
}
