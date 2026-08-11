import Foundation
import Observation
import SystemConfiguration

@MainActor
@Observable
class NetworkMonitor {
    var downloadSpeed: Double = 0 // Bytes per second
    var uploadSpeed: Double = 0   // Bytes per second
    var downloadHistory: [Double] = Array(repeating: 0, count: 60)
    var uploadHistory: [Double] = Array(repeating: 0, count: 60)
    var primaryInterfaceName: String = "—"
    var isConnected: Bool = false
    
    private var lastInBytes: UInt64 = 0
    private var lastOutBytes: UInt64 = 0
    private var lastTime: Date = Date()
    private var timer: Timer?
    private var currentInterval: TimeInterval = 1.0

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
        // getifaddrs enumerates every UP interface — including idle virtual adapters
        // (anpi0/anpi1, bridge0, ap1) that macOS lists ahead of the real Wi-Fi/Ethernet
        // device. Taking "the first UP, non-loopback interface" as primary picked one of
        // those virtual adapters instead of en0, and summing bytes across all of them
        // mixed in unrelated tunnel/AWDL traffic. The real primary interface is whichever
        // one owns the default route, which SystemConfiguration reports directly.
        guard let primary = Self.primaryInterfaceFromSystemConfiguration() else {
            self.primaryInterfaceName = "—"
            self.isConnected = false
            return
        }

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return }
        defer { freeifaddrs(ifaddr) }

        var totalInBytes: UInt64 = 0
        var totalOutBytes: UInt64 = 0

        var ptr = ifaddr
        while ptr != nil {
            let interface = ptr!.pointee
            if String(cString: interface.ifa_name) == primary, let data = interface.ifa_data {
                let ifData = data.assumingMemoryBound(to: if_data.self)
                totalInBytes += UInt64(ifData.pointee.ifi_ibytes)
                totalOutBytes += UInt64(ifData.pointee.ifi_obytes)
            }
            ptr = interface.ifa_next
        }

        self.primaryInterfaceName = primary
        self.isConnected = true
        
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

    private static func primaryInterfaceFromSystemConfiguration() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "iActivity" as CFString, nil, nil),
              let value = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let interface = value["PrimaryInterface"] as? String else {
            return nil
        }
        return interface
    }
}
