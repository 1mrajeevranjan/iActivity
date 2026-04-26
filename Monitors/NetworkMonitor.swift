import Foundation
import Observation

@MainActor
@Observable
class NetworkMonitor {
    var downloadSpeed: Double = 0 // Bytes per second
    var uploadSpeed: Double = 0   // Bytes per second
    var downloadHistory: [Double] = Array(repeating: 0, count: 60)
    var uploadHistory: [Double] = Array(repeating: 0, count: 60)
    
    private var lastInBytes: UInt64 = 0
    private var lastOutBytes: UInt64 = 0
    private var lastTime: Date = Date()
    private var timer: Timer?
    
    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
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
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return }
        defer { freeifaddrs(ifaddr) }
        
        var totalInBytes: UInt64 = 0
        var totalOutBytes: UInt64 = 0
        
        var ptr = ifaddr
        while ptr != nil {
            let interface = ptr!.pointee
            let flags = Int32(interface.ifa_flags)
            // let name = String(cString: interface.ifa_name) // Removed unused variable
            
            // Check for EN0 (Wi-Fi on Mac) or other active interfaces, excluding loopback
            if (flags & IFF_UP) != 0 && (flags & IFF_LOOPBACK) == 0 {
                if let data = interface.ifa_data {
                    let ifData = data.assumingMemoryBound(to: if_data.self)
                    totalInBytes += UInt64(ifData.pointee.ifi_ibytes)
                    totalOutBytes += UInt64(ifData.pointee.ifi_obytes)
                }
            }
            ptr = interface.ifa_next
        }
        
        let now = Date()
        let interval = now.timeIntervalSince(lastTime)
        
        if lastInBytes > 0 && interval > 0 {
            let inDelta = totalInBytes >= lastInBytes ? totalInBytes - lastInBytes : 0
            let outDelta = totalOutBytes >= lastOutBytes ? totalOutBytes - lastOutBytes : 0
            
            self.downloadSpeed = Double(inDelta) / interval
            self.uploadSpeed = Double(outDelta) / interval
            
            self.downloadHistory.removeFirst()
            self.downloadHistory.append(downloadSpeed)
            self.uploadHistory.removeFirst()
            self.uploadHistory.append(uploadSpeed)
        }
        
        self.lastInBytes = totalInBytes
        self.lastOutBytes = totalOutBytes
        self.lastTime = now
    }
}
