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
            }
        }
    }
}
