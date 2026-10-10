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
    private var lastTime: TimeInterval = ProcessInfo.processInfo.systemUptime
    
    func update() {
        // getifaddrs enumerates every UP interface — including idle virtual adapters
        // (anpi0/anpi1, bridge0, ap1) that macOS lists ahead of the real Wi-Fi/Ethernet
        // device. Taking "the first UP, non-loopback interface" as primary picked one of
        // those virtual adapters instead of en0, and summing bytes across all of them
        // mixed in unrelated tunnel/AWDL traffic. The real primary interface is whichever
        // one owns the default route, which SystemConfiguration reports directly.
        guard let primary = Self.primaryInterfaceFromSystemConfiguration() else {
            recordSample(interface: nil, inBytes: 0, outBytes: 0, time: ProcessInfo.processInfo.systemUptime)
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

        recordSample(interface: primary, inBytes: totalInBytes, outBytes: totalOutBytes,
                     time: ProcessInfo.processInfo.systemUptime)
    }

    func recordSample(interface: String?, inBytes: UInt32, outBytes: UInt32, time: TimeInterval) {
        primaryInterfaceName = interface ?? "—"
        isConnected = interface != nil
        let elapsed = time - lastTime
        if let interface, hasBaseline, interface == lastInterface, elapsed > 0 {
            downloadSpeed = Double(inBytes &- lastInBytes) / elapsed
            uploadSpeed = Double(outBytes &- lastOutBytes) / elapsed
        } else {
            // Disconnects and interface changes must clear the previous link's rates.
            downloadSpeed = 0
            uploadSpeed = 0
        }
        downloadHistory.removeFirst()
        downloadHistory.append(downloadSpeed)
        uploadHistory.removeFirst()
        uploadHistory.append(uploadSpeed)
        lastInBytes = inBytes
        lastOutBytes = outBytes
        lastInterface = interface ?? ""
        hasBaseline = interface != nil
        lastTime = time
    }

    /// One session with configd for the app's lifetime — opening a new one every tick was an
    /// extra IPC connection setup per second.
    private static let store = SCDynamicStoreCreate(nil, "iActivity" as CFString, nil, nil)

    private static func primaryInterfaceFromSystemConfiguration() -> String? {
        guard let store else { return nil }
        for family in ["IPv4", "IPv6"] {
            if let value = SCDynamicStoreCopyValue(store, "State:/Network/Global/\(family)" as CFString) as? [String: Any],
               let interface = value["PrimaryInterface"] as? String { return interface }
        }
        return nil
    }
}
