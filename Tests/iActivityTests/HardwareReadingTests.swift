import Foundation
import Testing
@testable import iActivity

struct HardwareReadingTests {
    @Test("Discharge current stored as an unsigned bit pattern still yields watts")
    func negativeAmperageYieldsWatts() {
        // -618 mA as the registry actually returns it: a UInt64 bit pattern.
        let registry: [String: Any] = [
            "Voltage": NSNumber(value: 12_598),
            "Amperage": NSNumber(value: UInt64(bitPattern: -618)),
        ]
        let watts = BatteryMonitor.systemPower(from: registry)
        #expect(abs(watts - 7.785) < 0.01)
    }

    @Test("SMC system load wins over voltage × current")
    func systemLoadPreferred() {
        let registry: [String: Any] = [
            "PowerTelemetryData": ["SystemLoad": NSNumber(value: 3_804)],
            "Voltage": NSNumber(value: 12_598),
            "Amperage": NSNumber(value: -618),
        ]
        #expect(BatteryMonitor.systemPower(from: registry) == 3.804)
    }

    @Test("Health falls back to nominal capacity nested under BatteryData")
    func healthFromNestedBatteryData() {
        let registry: [String: Any] = [
            "BatteryData": ["DesignCapacity": NSNumber(value: 4_629), "NominalChargeCapacity": NSNumber(value: 4_295)],
        ]
        let health = BatteryMonitor.capacityHealth(from: registry) ?? 0
        #expect(abs(health - 92.78) < 0.01)
    }

    @Test("Maximum Capacity parses from system_profiler JSON")
    func parsesSystemProfilerHealth() {
        let json = #"{"SPPowerDataType":[{"_name":"x","sppower_battery_health_info":{"sppower_battery_health_maximum_capacity":"96%"}}]}"#
        #expect(BatteryMonitor.maximumCapacity(fromSystemProfilerJSON: Data(json.utf8)) == 96)
    }

    @Test("A missing sensor shows a dash, never a number")
    func missingSensorShowsDash() {
        #expect(TemperatureUnit.celsius.reading(fromCelsius: 0) == "—")
        #expect(TemperatureUnit.celsius.reading(fromCelsius: 47.6) == "48°C")
    }
}
