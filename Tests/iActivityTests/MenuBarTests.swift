import Testing
@testable import iActivity

struct MenuBarSelectionTests {
    @Test("Round-trips through its raw value, so @AppStorage can persist it")
    func roundTrips() {
        let selection = MenuBarSelection([.cpu, .memory, .network])
        #expect(MenuBarSelection(rawValue: selection.rawValue) == selection)
    }

    @Test("Renders in canonical tab order regardless of the order it was built in")
    func normalisesOrder() {
        #expect(MenuBarSelection([.network, .cpu, .memory]).categories == [.cpu, .memory, .network])
    }

    @Test("Drops duplicates — the same category twice would draw two identical segments")
    func dropsDuplicates() {
        #expect(MenuBarSelection([.cpu, .cpu, .gpu]).categories == [.cpu, .gpu])
    }

    @Test("Tolerates unknown tokens in stored data rather than losing the whole selection")
    func ignoresUnknownTokens() {
        #expect(MenuBarSelection(rawValue: "cpu,quantumflux,network")?.categories == [.cpu, .network])
    }

    @Test("Missing key seeds from the dashboard category, so an existing install looks identical after upgrade")
    func migratesFromSelectedCategory() {
        #expect(MenuBarSelection.resolved(rawValue: nil, fallback: .battery).categories == [.battery])
    }

    @Test("An empty selection falls back rather than leaving a zero-width, unclickable status item")
    func emptyFallsBack() {
        #expect(MenuBarSelection.resolved(rawValue: "", fallback: .gpu).categories == [.gpu])
        #expect(MenuBarSelection.resolved(rawValue: "nonsense", fallback: .gpu).categories == [.gpu])
    }

    @Test("A stored selection wins over the fallback")
    func storedWinsOverFallback() {
        #expect(MenuBarSelection.resolved(rawValue: "cpu,disk", fallback: .battery).categories == [.cpu, .disk])
    }
}

struct MenuBarStatusTests {
    @Test("CPU and GPU warn at 70% and turn critical at 90%")
    func processorThresholds() {
        for category in [MetricCategory.cpu, .gpu] {
            #expect(MenuBarStatus.level(for: category, value: 0.69, isCharging: false) == .normal)
            #expect(MenuBarStatus.level(for: category, value: 0.70, isCharging: false) == .warning)
            #expect(MenuBarStatus.level(for: category, value: 0.90, isCharging: false) == .critical)
        }
    }

    @Test("Memory warns at 75%, disk only at 85% — a full disk is less urgent than memory pressure")
    func storageThresholds() {
        #expect(MenuBarStatus.level(for: .memory, value: 0.75, isCharging: false) == .warning)
        #expect(MenuBarStatus.level(for: .memory, value: 0.90, isCharging: false) == .critical)
        #expect(MenuBarStatus.level(for: .disk, value: 0.84, isCharging: false) == .normal)
        #expect(MenuBarStatus.level(for: .disk, value: 0.85, isCharging: false) == .warning)
        #expect(MenuBarStatus.level(for: .disk, value: 0.95, isCharging: false) == .critical)
    }

    @Test("Battery is inverted — low is bad — and never alarms while charging")
    func batteryThresholds() {
        #expect(MenuBarStatus.level(for: .battery, value: 0.10, isCharging: false) == .critical)
        #expect(MenuBarStatus.level(for: .battery, value: 0.20, isCharging: false) == .warning)
        #expect(MenuBarStatus.level(for: .battery, value: 0.50, isCharging: false) == .normal)
        #expect(MenuBarStatus.level(for: .battery, value: 0.05, isCharging: true) == .normal)
    }

    @Test("Network has no ceiling to be a percentage of, so it never alarms")
    func networkNeverAlarms() {
        #expect(MenuBarStatus.level(for: .network, value: 1.0, isCharging: false) == .normal)
    }
}

struct CPUClusterTests {
    @Test("Averages each cluster separately — the kernel reports E-cores first on Apple Silicon")
    func splitsClusters() {
        let averages = CPUMonitor.clusterAverages(
            coreUsages: [0.10, 0.20, 0.80, 0.90],
            efficiencyCoreCount: 2
        )
        #expect(abs(averages.efficiency - 0.15) < 0.0001)
        #expect(abs(averages.performance - 0.85) < 0.0001)
    }

    @Test("Intel reports no split, so everything counts as performance and efficiency reads zero")
    func intelHasNoSplit() {
        let averages = CPUMonitor.clusterAverages(coreUsages: [0.4, 0.6], efficiencyCoreCount: 0)
        #expect(abs(averages.performance - 0.5) < 0.0001)
        #expect(averages.efficiency == 0)
    }

    @Test("Empty core list averages to zero instead of dividing by zero")
    func emptyIsZero() {
        let averages = CPUMonitor.clusterAverages(coreUsages: [], efficiencyCoreCount: 0)
        #expect(averages.performance == 0)
        #expect(averages.efficiency == 0)
    }

    @Test("A count larger than the core list is clamped rather than crashing on a bad sysctl")
    func clampsOversizedCount() {
        let averages = CPUMonitor.clusterAverages(coreUsages: [0.5, 0.7], efficiencyCoreCount: 99)
        #expect(abs(averages.efficiency - 0.6) < 0.0001)
        #expect(averages.performance == 0)
    }
}
