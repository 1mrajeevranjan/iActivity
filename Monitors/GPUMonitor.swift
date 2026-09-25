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

    /// Looked up once: searching the registry for the accelerator and copying its full property
    /// dictionary every tick cost ~70× more than reading one key off a held service.
    /// ponytail: held for the app's lifetime, never released — there is only ever one.
    private let service: io_service_t

    init() {
        // AGXAccelerator on Apple Silicon; IOAccelerator matches every GPU driver including Intel/AMD.
        var service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AGXAccelerator"))
        if service == 0 { service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOAccelerator")) }
        self.service = service

        // The accelerator's own "model" ("Apple M4") is the same name Metal reports. Creating a
        // Metal device just to read it loaded the GPU driver stack into the process (~5 MB), so
        // Metal is only asked where the registry has no name.
        if service != 0, let model = Self.property("model", of: service) as? String {
            rendererName = model
        } else if let device = MTLCreateSystemDefaultDevice() {
            rendererName = device.name
        }

        // Discrete GPUs (Intel Macs) report dedicated VRAM; Apple Silicon has none. Fixed for the
        // life of the machine, so read once.
        if service != 0 {
            if let vram = Self.property("VRAM,totalMB", of: service) as? NSNumber {
                vramTotal = vram.int64Value * 1024 * 1024
            } else if let vram = Self.property("VRAM,total-size", of: service) as? NSNumber {
                vramTotal = vram.int64Value
            }
        }
    }

    private static func property(_ key: String, of service: io_service_t) -> Any? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    func start(interval: TimeInterval? = nil) {
        stop()
        if let interval { currentInterval = interval }
        // Scheduled on the main run loop, so the callback is already on the main actor. The
        // tolerance lets macOS coalesce this wakeup with the other monitors' and the system's.
        timer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        timer?.tolerance = currentInterval * 0.1
        update()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func update() {
        // Update GPU temperature
        temperature = SMCHelper.gpuTemperature()

        guard service != 0 else { return }

        // PerformanceStatistics is the standard key for GPU load. Read through NSNumber: a bare
        // `as? Int64` fails whenever the registry stores the value as a different width.
        if let stats = Self.property("PerformanceStatistics", of: service) as? [String: Any] {
            if let util = stats["Device Utilization %"] as? NSNumber {
                self.utilization = min(max(util.doubleValue / 100.0, 0), 1)
            }
            // Unified memory: what the GPU driver currently has resident in system RAM.
            if let inUse = stats["In use system memory"] as? NSNumber {
                self.vramUsed = inUse.int64Value
            }
        }

        self.history.removeFirst()
        self.history.append(utilization)
    }
}
