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
                    let maxCapacity = description[kIOPSMaxCapacityKey] as? Int, maxCapacity > 0 {
                    self.level = Int((Double(capacity) / Double(maxCapacity) * 100).rounded())
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

        let registry = Self.smartBatteryProperties()
        if let cycles = registry["CycleCount"] as? NSNumber {
            self.cycleCount = cycles.intValue
        }
        self.watts = Self.systemPower(from: registry)
        if healthPercentage == 0, let health = Self.capacityHealth(from: registry) {
            self.healthPercentage = health
        }
        loadReportedHealthOnce()

        levelHistory.removeFirst()
        levelHistory.append(Double(level) / 100.0)

        powerHistory.removeFirst()
        powerHistory.append(watts)
    }

    /// What the whole Mac is drawing right now, in watts.
    ///
    /// `PowerTelemetryData.SystemLoad` (mW) is the SMC's own system-load figure and is right on
    /// both battery and AC. Where it's missing (Intel), battery voltage × current is the draw
    /// while discharging. Amperage is signed but the registry hands it back as an unsigned
    /// 64-bit number — `as? Int` failed on every negative reading, which is why this used to
    /// show 0.0 W whenever the Mac was on battery.
    nonisolated static func systemPower(from registry: [String: Any]) -> Double {
        if let telemetry = registry["PowerTelemetryData"] as? [String: Any],
           let load = telemetry["SystemLoad"] as? NSNumber, load.int64Value > 0 {
            return Double(load.int64Value) / 1000
        }
        guard let voltage = registry["Voltage"] as? NSNumber,
              let amperage = (registry["InstantAmperage"] ?? registry["Amperage"]) as? NSNumber else { return 0 }
        return abs(Double(voltage.int64Value) * Double(amperage.int64Value)) / 1_000_000
    }

    /// Full-charge capacity against design capacity, both in mAh. Only a stand-in until macOS's
    /// own "Maximum Capacity" figure arrives from `loadReportedHealthOnce()`.
    nonisolated static func capacityHealth(from registry: [String: Any]) -> Double? {
        let batteryData = registry["BatteryData"] as? [String: Any] ?? [:]
        func mAh(_ key: String) -> Double? {
            ((registry[key] ?? batteryData[key]) as? NSNumber).map(\.doubleValue).flatMap { $0 > 0 ? $0 : nil }
        }
        guard let design = mAh("DesignCapacity"),
              let full = mAh("AppleRawMaxCapacity") ?? mAh("NominalChargeCapacity") else { return nil }
        return min(100, full / design * 100)
    }

    private var didRequestReportedHealth = false

    /// The exact "Maximum Capacity" System Settings shows comes from Apple's own battery-health
    /// model, which no public registry key exposes. `system_profiler` reports it, but takes about
    /// a second — it only changes over weeks, so it's read once, off the main thread.
    private func loadReportedHealthOnce() {
        guard !didRequestReportedHealth else { return }
        didRequestReportedHealth = true
        Task.detached(priority: .utility) {
            guard let health = Self.reportedMaximumCapacity() else { return }
            await MainActor.run { self.healthPercentage = health }
        }
    }

    nonisolated private static func reportedMaximumCapacity() -> Double? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPPowerDataType", "-json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return maximumCapacity(fromSystemProfilerJSON: data)
    }

    /// Pulls `sppower_battery_health_maximum_capacity` ("96%") out of `system_profiler` JSON.
    nonisolated static func maximumCapacity(fromSystemProfilerJSON data: Data) -> Double? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = root["SPPowerDataType"] as? [[String: Any]] else { return nil }
        for entry in entries {
            guard let health = entry["sppower_battery_health_info"] as? [String: Any],
                  let raw = health["sppower_battery_health_maximum_capacity"] as? String,
                  let value = Double(raw.trimmingCharacters(in: CharacterSet(charactersIn: "% "))) else { continue }
            return value
        }
        return nil
    }

    nonisolated private static func smartBatteryProperties() -> [String: Any] {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return [:] }
        defer { IOObjectRelease(service) }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
              let dict = props?.takeRetainedValue() as? [String: Any] else { return [:] }
        return dict
    }
}
