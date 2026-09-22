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

struct CoreClusterNamingTests {
    private func clusters(_ names: [String], _ counts: [Int]) -> [CPUMonitor.CoreCluster] {
        CPUMonitor.clusters(levelNames: names, levelCounts: counts)
    }

    @Test("Listed in core-enumeration order, which is the reverse of the perflevel order")
    func reversesPerflevelOrder() {
        // Verified on an M4: perflevel0 is Performance (4 cores) but host_processor_info
        // enumerates the 6 Efficiency cores first, at indices 0–5.
        let built = clusters(["Performance", "Efficiency"], [4, 6])
        #expect(built.map(\.name) == ["Efficiency", "Performance"])
        #expect(built.map(\.coreCount) == [6, 4])
    }

    @Test("Short names come from the reported name, so they track whatever Apple ships")
    func derivesShortNames() {
        #expect(clusters(["Performance", "Efficiency"], [4, 6]).map(\.shortName) == ["E-Core", "P-Core"])
    }

    @Test("A future chip's own names are used verbatim rather than mapped onto P and E")
    func usesReportedNamesVerbatim() {
        let built = clusters(["Ultra", "Standard"], [2, 8])
        #expect(built.map(\.name) == ["Standard", "Ultra"])
        #expect(built.map(\.shortName) == ["S-Core", "U-Core"])
    }

    @Test("Colliding initials fall back to full names instead of two identical labels")
    func fallsBackWhenInitialsCollide() {
        let built = clusters(["Performance", "Power-efficient"], [4, 4])
        #expect(built.map(\.shortName) == ["Power-efficient", "Performance"])
    }

    @Test("Intel reports no perf levels at all, so there are no clusters to name")
    func intelHasNoClusters() {
        #expect(clusters([], []).isEmpty)
    }

    @Test("Mismatched name and count arrays are tolerated rather than crashing on a bad sysctl")
    func toleratesMismatchedArrays() {
        #expect(clusters(["Performance", "Efficiency"], [4]).map(\.name) == ["Performance"])
    }
}

struct CoreKindLabelTests {
    private let performance = CPUMonitor.CoreCluster(name: "Performance", shortName: "P-Core", coreCount: 4)

    @Test("The core list uses the compact form, VoiceOver the full reported name")
    func labelsUseReportedNames() {
        let kind = CPUMonitor.CoreKind.performance(ordinal: 2, cluster: performance)
        #expect(kind.label == "P-Core 2")
        #expect(kind.spokenLabel == "Performance core 2")
    }

    @Test("Undifferentiated cores are numbered from one, not zero")
    func undifferentiatedIsOneBased() {
        #expect(CPUMonitor.CoreKind.undifferentiated(1).label == "Core 1")
    }
}

/// Exercises the live sysctl path. The pure tests above cannot catch a mistyped key —
/// `hw.perflevel0.name` returning nil would silently degrade every Mac to "Core N" — so these
/// read the machine actually running the suite. They no-op on a CPU with no clusters to report.
@MainActor
struct LiveCoreClusterTests {
    @Test("Cluster names come back from the live sysctls, not from a hardcoded table")
    func readsThisMachinesClusters() {
        let monitor = CPUMonitor()
        guard monitor.clusters.count >= 2 else { return }

        for cluster in monitor.clusters {
            #expect(!cluster.name.isEmpty)
            #expect(!cluster.shortName.isEmpty)
            #expect(cluster.coreCount > 0)
        }

        // The split index must land inside the real core list, or clusterAverages would
        // quietly average the wrong cores together.
        let total = monitor.clusters.reduce(0) { $0 + $1.coreCount }
        #expect(monitor.efficiencyCoreCount > 0)
        #expect(monitor.efficiencyCoreCount < total)
        #expect(monitor.performanceClusterName == monitor.clusters.last?.name)
        #expect(monitor.efficiencyClusterName == monitor.clusters.first?.name)
    }

    @Test("Cores are numbered within their own cluster, each starting at one")
    func labelsAreClusterRelative() {
        let monitor = CPUMonitor()
        guard monitor.clusters.count >= 2 else { return }

        #expect(monitor.coreKind(at: 0).label.hasSuffix(" 1"))
        // The first core of the top cluster restarts at 1 rather than continuing the count.
        #expect(monitor.coreKind(at: monitor.efficiencyCoreCount).label.hasSuffix(" 1"))

        // And the two ends really are classified as opposite kinds.
        if case .efficiency = monitor.coreKind(at: 0) {} else { Issue.record("core 0 should be an efficiency core") }
        if case .performance = monitor.coreKind(at: total(monitor) - 1) {} else { Issue.record("last core should be a performance core") }
    }

    private func total(_ monitor: CPUMonitor) -> Int {
        monitor.clusters.reduce(0) { $0 + $1.coreCount }
    }
}
