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
    
    private var lastInBytes: UInt32 = 0
    private var lastOutBytes: UInt32 = 0
    /// Switching Wi-Fi ↔ Ethernet swaps in another interface's counters; diffing across the
    /// switch would report a bogus multi-GB spike, so the first tick after one only re-baselines.
    private var lastInterface = ""
    private var hasBaseline = false
    private var lastTime: Date = Date()
    private var timer: Timer?
    private var currentInterval: TimeInterval = 1.0

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

        // `if_data` counters are 32-bit and wrap every 4 GB — seconds apart on a fast link.
        // Wrapping subtraction below turns a wrap into the correct small delta instead of a zero.
        var totalInBytes: UInt32 = 0
        var totalOutBytes: UInt32 = 0

        var ptr = ifaddr
        while ptr != nil {
            let interface = ptr!.pointee
            if String(cString: interface.ifa_name) == primary, let data = interface.ifa_data {
                let ifData = data.assumingMemoryBound(to: if_data.self)
                totalInBytes = ifData.pointee.ifi_ibytes
                totalOutBytes = ifData.pointee.ifi_obytes
            }
            ptr = interface.ifa_next
        }

        self.primaryInterfaceName = primary
        self.isConnected = true
        
        let now = Date()
        let interval = now.timeIntervalSince(lastTime)
        
        if hasBaseline && primary == lastInterface && interval > 0 {
            let inDelta = totalInBytes &- lastInBytes
            let outDelta = totalOutBytes &- lastOutBytes
            
            self.downloadSpeed = Double(inDelta) / interval
            self.uploadSpeed = Double(outDelta) / interval
            
            self.downloadHistory.removeFirst()
            self.downloadHistory.append(downloadSpeed)
            self.uploadHistory.removeFirst()
            self.uploadHistory.append(uploadSpeed)
        }
        
        self.lastInBytes = totalInBytes
        self.lastOutBytes = totalOutBytes
        self.lastInterface = primary
        self.hasBaseline = true
        self.lastTime = now
    }

    /// One session with configd for the app's lifetime — opening a new one every tick was an
    /// extra IPC connection setup per second.
    private static let store = SCDynamicStoreCreate(nil, "iActivity" as CFString, nil, nil)

    private static func primaryInterfaceFromSystemConfiguration() -> String? {
        guard let store,
              let value = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let interface = value["PrimaryInterface"] as? String else {
            return nil
        }
        return interface
    }
}
