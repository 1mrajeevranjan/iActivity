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
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AGXAccelerator"))
        if service == 0 { return }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
              let propsDict = props?.takeRetainedValue() as? [String: Any] else { return }

        // PerformanceStatistics is the standard key for GPU load
        if let stats = propsDict["PerformanceStatistics"] as? [String: Any] {
            if let util = stats["Device Utilization %"] as? Int64 {
                self.utilization = Double(util) / 100.0
            }
        }

        // For VRAM, on M-series chips, it's unified memory
        if let vram = propsDict["VRAM,total-size"] as? Int64 {
            self.vramTotal = vram
        }

        self.history.removeFirst()
        self.history.append(utilization)
    }
}
