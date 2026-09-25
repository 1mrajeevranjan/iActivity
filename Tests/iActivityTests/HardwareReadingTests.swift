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

    @Test("Process rankings keep the top five per measure and drop idle entries")
    func processRankings() {
        let entries = (1...8).map { (n: Int) -> ProcessMonitor.ProcessEntry in
            let disk: Double = n == 3 ? 500 : 0
            return ProcessMonitor.ProcessEntry(
                pid: Int32(n), name: "p\(n)",
                cpuPercent: Double(n * 3 % 8), memoryMB: Double(n * 10), diskBytesPerSecond: disk
            )
        }
        let ranked = ProcessMonitor.rank(entries)
        #expect(ranked.cpu.map { $0.pid } == [5, 2, 7, 4, 1])
        #expect(ranked.memory.map { $0.pid } == [8, 7, 6, 5, 4])
        #expect(ranked.disk.map { $0.pid } == [3])
    }

    @Test("CPU tick counters that wrap past Int32.max yield the small true delta")
    func cpuTickWrap() {
        #expect(CPUMonitor.tickDelta(Int32.min + 4, Int32.max - 5) == 10)
        #expect(CPUMonitor.tickDelta(-2, -12) == 10)
        #expect(CPUMonitor.tickDelta(250, 100) == 150)
    }
}
