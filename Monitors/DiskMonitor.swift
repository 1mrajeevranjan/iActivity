import Foundation
import Observation

@MainActor
@Observable
class DiskMonitor {
    var total: Int64 = 0
    var free: Int64 = 0
    var used: Int64 = 0
    var usagePercentage: Double = 0
    
    private var timer: Timer?
    
    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
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
        let fileManager = FileManager.default
        let path = "/"
        
        do {
            let values = try fileManager.attributesOfFileSystem(forPath: path)
            if let totalSize = values[.systemSize] as? Int64,
               let freeSize = values[.systemFreeSize] as? Int64 {
                self.total = totalSize
                self.free = freeSize
                self.used = totalSize - freeSize
                self.usagePercentage = totalSize > 0 ? Double(self.used) / Double(totalSize) : 0
            }
        } catch {
            print("Error retrieving disk usage: \(error)")
        }
    }
}
