import AppKit
import SwiftUI
import Testing
import IOKit
import IOKit.ps
import Observation
@testable import iActivity

@Suite(.serialized)
@MainActor
struct DashboardRegressionTests {
    private func pump(_ seconds: TimeInterval, mode: RunLoop.Mode = .default) {
        let deadline = Date(timeIntervalSinceNow: seconds)
        while Date() < deadline {
            RunLoop.main.run(mode: mode, before: min(deadline, Date(timeIntervalSinceNow: 0.01)))
        }
    }

    @Test("Settings clears the dark override when System is selected")
    func settingsAppearanceRoundTrip() throws {
        let application = NSApplication.shared
        let originalAppearance = application.appearance
        application.appearance = nil
        let systemAppearance = application.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        let domain = "iActivity.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defaults.set("auto", forKey: "appearanceMode")
        let monitor = SystemMonitor()
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 420, height: 540),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: SettingsView().environment(monitor).defaultAppStorage(defaults))
        window.contentView = hosting
        defer {
            window.contentView = nil
            window.close()
            monitor.stop()
            application.appearance = originalAppearance
            defaults.removePersistentDomain(forName: domain)
        }
        hosting.layoutSubtreeIfNeeded()
        pump(0.1)
        for mode in [AppearanceMode.light, .dark, .auto, .dark, .light, .auto] {
            defaults.set(mode.rawValue, forKey: "appearanceMode")
            pump(0.1)
            hosting.layoutSubtreeIfNeeded()
            let expected: NSAppearance.Name? = mode == .auto ? systemAppearance : mode == .dark ? .darkAqua : .aqua
            #expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == expected)
            if mode == .auto { #expect(application.appearance == nil) }
            else { #expect(application.appearance?.bestMatch(from: [.aqua, .darkAqua]) == expected) }
        }
    }

    @Test("Every dashboard keeps equal gutters, including expanded CPU and screen-limited cards")
    func dashboardLayout() throws {
        _ = NSApplication.shared
        let domain = "iActivity.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))
        let monitor = SystemMonitor()
        defer { monitor.stop(); defaults.removePersistentDomain(forName: domain) }
        monitor.cpu.coreUsages = Array(repeating: 0.25, count: ProcessInfo.processInfo.processorCount)
        for category in MetricCategory.allCases {
            for expanded in (category == .cpu ? [false, true] : [false]) {
                for ceiling: CGFloat in [400, 900] {
                    defaults.set(category.rawValue, forKey: "selectedCategory")
                    defaults.set(expanded, forKey: "showCPUCoreDetails")
                    let anchor = PanelAnchor()
                    anchor.maxCardHeight = ceiling
                    let hosting = NSHostingView(rootView: MainDashboardView().environment(monitor).environment(anchor)
                        .transaction { $0.disablesAnimations = true }.defaultAppStorage(defaults))
                    hosting.sizingOptions = []
                    let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: AppTheme.Panel.windowWidth, height: ceiling + 22),
                                          styleMask: [.borderless], backing: .buffered, defer: false)
                    window.isReleasedWhenClosed = false
                    window.contentView = hosting
                    anchor.onContentHeightChange = { height in
                        window.setContentSize(CGSize(width: AppTheme.Panel.windowWidth, height: height + 22))
                    }
                    defer { window.contentView = nil; window.close() }
                    hosting.layoutSubtreeIfNeeded()
                    pump(0.1)
                    let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
                    hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                    let scale = CGFloat(bitmap.pixelsWide) / hosting.bounds.width
                    func color(_ x: CGFloat, _ y: CGFloat) throws -> NSColor {
                        try #require(bitmap.colorAt(x: Int(x * scale), y: Int((hosting.bounds.height - y) * scale))?.usingColorSpace(.deviceRGB))
                    }
                    let gutter: CGFloat = 12
                    let footerTop = AppTheme.Panel.shadowMargin + gutter + AppTheme.Metrics.footerHeight
                    for offset: CGFloat in [3, 6, 9] {
                        let gap = try color(hosting.bounds.midX, footerTop + offset)
                        let side = try color(AppTheme.Panel.shadowMargin + gutter / 2, footerTop + offset)
                        #expect(abs(gap.redComponent - side.redComponent) < 0.04)
                        #expect(abs(gap.greenComponent - side.greenComponent) < 0.04)
                        #expect(abs(gap.blueComponent - side.blueComponent) < 0.04)
                    }
                    #expect(hosting.bounds.height <= ceiling + 22.5)
                    if category == .cpu {
                        let name = expanded ? "expanded" : "compact"
                        try bitmap.representation(using: .png, properties: [:])?.write(to:
                            URL(fileURLWithPath: "/tmp/iactivity-\(name)-\(Int(ceiling)).png"))
                    }
                }
            }
        }
    }

    @Test("Network clears stale readings on disconnect and re-baselines on an interface change")
    func networkTransitions() {
        let network = NetworkMonitor()
        network.recordSample(interface: "en0", inBytes: 100, outBytes: 100, time: 1)
        network.recordSample(interface: "en0", inBytes: 500, outBytes: 300, time: 3)
        #expect(network.downloadSpeed == 200)
        #expect(network.uploadSpeed == 100)
        network.recordSample(interface: nil, inBytes: 0, outBytes: 0, time: 4)
        #expect(!network.isConnected)
        #expect(network.downloadSpeed == 0 && network.uploadSpeed == 0)
        #expect(network.downloadHistory.last == 0)
        network.recordSample(interface: "en0", inBytes: 50, outBytes: 50, time: 5)
        #expect(network.downloadSpeed == 0 && network.uploadSpeed == 0)
        network.recordSample(interface: "en1", inBytes: UInt32.max - 10, outBytes: UInt32.max - 20, time: 6)
        #expect(network.downloadSpeed == 0 && network.uploadSpeed == 0)
        network.recordSample(interface: "en1", inBytes: 9, outBytes: 19, time: 8)
        #expect(network.downloadSpeed == 10 && network.uploadSpeed == 20)
    }

    @Test("Process count changes do not resize dashboard cards")
    func processListHeightIsStable() {
        func entry(_ id: Int) -> ProcessMonitor.ProcessEntry {
            ProcessMonitor.ProcessEntry(pid: Int32(id), name: "process-\(id)",
                                        cpuPercent: Double(id), memoryMB: Double(id * 10),
                                        diskBytesPerSecond: Double(id * 1_000))
        }
        func height(_ processes: [ProcessMonitor.ProcessEntry], metric: TopProcessesView.Metric) -> CGFloat {
            let hosting = NSHostingView(rootView: TopProcessesView(processes: processes, metric: metric, tint: .orange)
                .frame(width: 280))
            hosting.layoutSubtreeIfNeeded()
            return hosting.fittingSize.height
        }

        for metric in [TopProcessesView.Metric.cpu, .memory, .disk] {
            let empty = height([], metric: metric)
            #expect(empty == height([entry(1)], metric: metric))
            #expect(empty == height((1...5).map(entry), metric: metric))
        }
    }

    @Test("Live dashboard values agree with native hardware APIs and update their histories")
    func liveHardwareReadings() async throws {
        let monitor = SystemMonitor()
        defer { monitor.stop() }
        monitor.resumeAll()
        monitor.applyInterval(0.1)
        try await Task.sleep(for: .seconds(1))
        let cpu = monitor.cpu
        #expect(cpu.coreUsages.count == ProcessInfo.processInfo.processorCount)
        #expect(cpu.coreUsages.allSatisfy { (0...1).contains($0) })
        #expect(abs(cpu.usage - cpu.coreUsages.reduce(0, +) / Double(cpu.coreUsages.count)) < 0.00001)
        #expect(cpu.history.last == cpu.usage)
        let averages = CPUMonitor.clusterAverages(coreUsages: cpu.coreUsages, efficiencyCoreCount: cpu.efficiencyCoreCount)
        #expect(cpu.performanceUsage == averages.performance && cpu.efficiencyUsage == averages.efficiency)
        #expect(monitor.memory.total == Double(ProcessInfo.processInfo.physicalMemory))
        #expect(monitor.memory.used == monitor.memory.appMemory + monitor.memory.wired + monitor.memory.compressed)
        #expect((0...1).contains(monitor.memory.usagePercentage))
        #expect(monitor.memory.usageHistory.last == monitor.memory.usagePercentage)
        var vm = vm_statistics64()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let status = withUnsafeMutablePointer(to: &vm) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &vmCount)
            }
        }
        #expect(status == KERN_SUCCESS)
        #expect(abs(monitor.memory.wired - Double(vm.wire_count) * Double(getpagesize())) < 128 * 1024 * 1024)
        let volume = try URL(fileURLWithPath: "/").resourceValues(forKeys:
            [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        #expect(monitor.disk.total == Int64(try #require(volume.volumeTotalCapacity)))
        #expect(abs(monitor.disk.free - (try #require(volume.volumeAvailableCapacityForImportantUsage))) < 512 * 1024 * 1024)
        #expect(monitor.disk.used == max(monitor.disk.total - monitor.disk.free, 0))
        #expect(monitor.disk.readSpeed >= 0 && monitor.disk.writeSpeed >= 0)
        #expect(monitor.disk.readHistory.last == monitor.disk.readSpeed)
        #expect((0...1).contains(monitor.gpu.utilization))
        #expect(monitor.gpu.history.last == monitor.gpu.utilization)
        #expect(monitor.gpu.vramUsed >= 0 && !monitor.gpu.rendererName.isEmpty)
        func registry(_ name: String) -> [String: Any]? {
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(name))
            guard service != 0 else { return nil }
            defer { IOObjectRelease(service) }
            var properties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == kIOReturnSuccess else { return nil }
            return properties?.takeRetainedValue() as? [String: Any]
        }
        if let gpu = registry("AGXAccelerator") ?? registry("IOAccelerator"),
           let stats = gpu["PerformanceStatistics"] as? [String: Any] {
            if let memory = stats["In use system memory"] as? NSNumber {
                #expect(abs(monitor.gpu.vramUsed - memory.int64Value) < 256 * 1024 * 1024)
            }
            if let model = gpu["model"] as? String { #expect(monitor.gpu.rendererName == model) }
        }
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        for source in sources {
            if let description = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any],
               let capacity = description[kIOPSCurrentCapacityKey] as? Int,
               let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0 {
                #expect(monitor.battery.level == Int((Double(capacity) / Double(maximum) * 100).rounded()))
                #expect(monitor.battery.isCharging == description[kIOPSIsChargingKey] as? Bool)
                #expect(monitor.battery.powerSource == description[kIOPSPowerSourceStateKey] as? String)
            }
        }
        #expect(monitor.battery.levelHistory.last == Double(monitor.battery.level) / 100)
        #expect(monitor.battery.watts >= 0)
        if let battery = registry("AppleSmartBattery") {
            if let cycles = battery["CycleCount"] as? NSNumber { #expect(monitor.battery.cycleCount == cycles.intValue) }
            #expect(monitor.battery.watts.isFinite)
            #expect((0...100).contains(monitor.battery.healthPercentage))
        }
        #expect(monitor.network.downloadSpeed >= 0 && monitor.network.uploadSpeed >= 0)
        #expect(monitor.network.downloadHistory.last == monitor.network.downloadSpeed)
        for temperature in [cpu.temperature, monitor.gpu.temperature, monitor.memory.temperature,
                            monitor.disk.temperature, monitor.battery.temperature] {
            #expect(temperature == 0 || (10...130).contains(temperature))
        }
        #expect(!monitor.processes.topByMemory.isEmpty)
        let memory = monitor.processes.topByMemory.map(\.memoryMB)
        #expect(memory == memory.sorted(by: >))
        #expect(monitor.processes.topByCPU.allSatisfy { $0.cpuPercent > 0 && $0.cpuPercent.isFinite })
    }

    @Test("Process lists follow the selected cadence and stop publishing when the dashboard closes")
    func processRefreshAndPause() async throws {
        let monitor = SystemMonitor()
        defer { monitor.stop() }
        monitor.resumeAll()
        monitor.applyInterval(0.1)
        try await Task.sleep(for: .milliseconds(400))
        try await confirmation("A new process sample arrives at the configured interval") { changed in
            withObservationTracking { _ = monitor.processes.topByMemory } onChange: { changed() }
            try await Task.sleep(for: .milliseconds(400))
        }
        monitor.pauseBackground()
        try await confirmation("Paused process scans do not publish late results", expectedCount: 0) { changed in
            withObservationTracking { _ = monitor.processes.topByMemory } onChange: { changed() }
            try await Task.sleep(for: .milliseconds(400))
        }
    }

    @Test("All dashboard histories keep sampling while the run loop tracks mouse input")
    func monitorsUpdateDuringTracking() {
        let monitor = SystemMonitor()
        defer { monitor.stop() }
        monitor.resumeAll()
        monitor.applyInterval(0.1)
        // Sentinels prove another real timer sample arrived, even when hardware is idle.
        monitor.cpu.history[59] = -1
        monitor.gpu.history[59] = -1
        monitor.memory.usageHistory[59] = -1
        monitor.disk.readHistory[59] = -1
        monitor.battery.levelHistory[59] = -1
        monitor.network.downloadHistory[59] = -1
        pump(0.4, mode: .eventTracking)
        #expect(monitor.cpu.history.last != -1)
        #expect(monitor.gpu.history.last != -1)
        #expect(monitor.memory.usageHistory.last != -1)
        #expect(monitor.disk.readHistory.last != -1)
        #expect(monitor.battery.levelHistory.last != -1)
        #expect(monitor.network.downloadHistory.last != -1)
    }

    @Test("The shared sampling clock pauses unseen categories and stops completely")
    func samplingLifecycle() {
        let monitor = SystemMonitor()
        defer { monitor.stop() }
        let active = Set(MenuBarSelection.current.categories)
        func values() -> [MetricCategory: Double] {
            [.cpu: monitor.cpu.history.last!, .gpu: monitor.gpu.history.last!,
             .memory: monitor.memory.usageHistory.last!, .disk: monitor.disk.readHistory.last!,
             .battery: monitor.battery.levelHistory.last!, .network: monitor.network.downloadHistory.last!]
        }
        monitor.pauseBackground(interval: 0.1)
        monitor.cpu.history[59] = -1
        monitor.gpu.history[59] = -1
        monitor.memory.usageHistory[59] = -1
        monitor.disk.readHistory[59] = -1
        monitor.battery.levelHistory[59] = -1
        monitor.network.downloadHistory[59] = -1
        pump(0.3)
        for (category, value) in values() { #expect((value != -1) == active.contains(category)) }
        monitor.resumeAll()
        monitor.applyInterval(0.1)
        pump(0.3)
        #expect(values().values.allSatisfy { $0 >= 0 })
        monitor.stop()
        let stopped = values()
        pump(0.3)
        #expect(values() == stopped)
    }
}
