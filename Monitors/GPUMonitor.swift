import Foundation
import Observation
import IOKit
import Metal

@MainActor
@Observable
class GPUMonitor {
    var utilization: Double = 0
    var vramUsed: Int64 = 0
    var vramTotal: Int64 = 0
    var history: [Double] = Array(repeating: 0, count: 60)
    var temperature: Double = 0
    var rendererName: String = "Apple GPU"

    private var timer: Timer?
    private var currentInterval: TimeInterval = 2.0

    init() {
        if let device = MTLCreateSystemDefaultDevice() {
            rendererName = device.name
        }
    }

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
        // Update GPU temperature
        temperature = SMCHelper.gpuTemperature()

        // Query IOKit for "AGXAccelerator" or similar GPU service
        // AGXAccelerator on Apple Silicon; IOAccelerator matches every GPU driver including Intel/AMD.
        var service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AGXAccelerator"))
        if service == 0 { service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOAccelerator")) }
        if service == 0 { return }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
              let propsDict = props?.takeRetainedValue() as? [String: Any] else { return }

        // PerformanceStatistics is the standard key for GPU load. Read through NSNumber: a bare
        // `as? Int64` fails whenever the registry stores the value as a different width.
        if let stats = propsDict["PerformanceStatistics"] as? [String: Any] {
            if let util = stats["Device Utilization %"] as? NSNumber {
                self.utilization = min(max(util.doubleValue / 100.0, 0), 1)
            }
            // Unified memory: what the GPU driver currently has resident in system RAM.
            if let inUse = stats["In use system memory"] as? NSNumber {
                self.vramUsed = inUse.int64Value
            }
        }

        // Discrete GPUs (Intel Macs) report dedicated VRAM here; Apple Silicon has none.
        if let vram = propsDict["VRAM,totalMB"] as? NSNumber {
            self.vramTotal = vram.int64Value * 1024 * 1024
        } else if let vram = propsDict["VRAM,total-size"] as? NSNumber {
            self.vramTotal = vram.int64Value
        }

        self.history.removeFirst()
        self.history.append(utilization)
    }
}
