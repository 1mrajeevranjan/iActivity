import Foundation
import IOKit

/// Real temperature readings from the System Management Controller.
///
/// The key names differ on every chip generation (M1's CPU sensors are not M4's), so rather than
/// carrying a per-chip table this enumerates every key the SMC reports once, keeps the float
/// temperature keys, and groups them by prefix: `Tp`/`Te` are the performance/efficiency CPU
/// clusters, `Tg` the GPU, `TB` the battery, `TH` the SSD, `Tm` memory. Intel's `TC`/`TG` keys are
/// the fallback where the Apple Silicon ones are absent. A category with no sensor reads 0, which
/// every view treats as "no reading" rather than inventing one.
@MainActor
enum SMCHelper {
    private static var connection: io_connect_t = 0
    private static var didOpen = false
    /// Every temperature key on this machine, with the byte size and type each read needs.
    private static var temperatureKeys: [(key: UInt32, name: String, info: KeyInfo)]?

    /// Set by `SystemMonitor`. With the dashboard closed, the menu bar's temperature toggle is
    /// the only thing on screen that shows a reading. Each reading is one SMC round-trip per
    /// sensor — dozens per category — and was the largest idle cost with temperatures hidden.
    static var isDashboardVisible = false

    private static var isReadingNeeded: Bool {
        isDashboardVisible || (UserDefaults.standard.object(forKey: "showTemperature") as? Bool ?? true)
    }

    // MARK: - Per-component readings (°C, 0 when the machine has no such sensor)

    static func cpuTemperature() -> Double { average(prefixes: ["Tp", "Te"], fallback: ["TC"]) }
    static func gpuTemperature() -> Double { average(prefixes: ["Tg"], fallback: ["TG"]) }
    static func memoryTemperature() -> Double { average(prefixes: ["Tm", "TM"]) }
    static func diskTemperature() -> Double { average(prefixes: ["TH"]) }
    static func batteryTemperature() -> Double { average(prefixes: ["TB"]) }

    private static func average(prefixes: [String], fallback: [String] = []) -> Double {
        guard isReadingNeeded else { return 0 }
        let primary = readings(prefixes: prefixes)
        let values = primary.isEmpty ? readings(prefixes: fallback) : primary
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func readings(prefixes: [String]) -> [Double] {
        guard !prefixes.isEmpty else { return [] }
        return allTemperatureKeys()
            .filter { entry in prefixes.contains { entry.name.hasPrefix($0) } }
            .compactMap { read($0.key, info: $0.info) }
            // Unpopulated sensor slots report 0 or a small constant; nothing real sits outside this.
            .filter { $0 > 10 && $0 < 130 }
    }

    // MARK: - SMC protocol

    /// Mirrors `SMCKeyData_t` from the AppleSMC user client, including the 3 bytes of padding C
    /// inserts after the nested key-info struct — without them every field after it is misread.
    private struct KeyData {
        typealias Bytes = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                           UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                           UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                           UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
        var key: UInt32 = 0
        var vers = (UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt16(0))
        var pLimit = (UInt16(0), UInt16(0), UInt32(0), UInt32(0), UInt32(0))
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
        var padding = (UInt8(0), UInt8(0), UInt8(0))
        var result: UInt8 = 0
        var status: UInt8 = 0
        var command: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: Bytes = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }

    private struct KeyInfo {
        let size: UInt32
        let type: UInt32
    }

    private static let handleEvent: UInt32 = 2
    private static let readBytesCommand: UInt8 = 5
    private static let keyAtIndexCommand: UInt8 = 8
    private static let keyInfoCommand: UInt8 = 9
    private static let floatType = fourCC("flt ")
    private static let sp78Type = fourCC("sp78")

    private static func open() -> Bool {
        if didOpen { return connection != 0 }
        didOpen = true
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        if IOServiceOpen(service, mach_task_self_, 0, &connection) != kIOReturnSuccess {
            connection = 0
        }
        return connection != 0
    }

    private static func call(_ input: KeyData) -> KeyData? {
        var input = input
        var output = KeyData()
        var outputSize = MemoryLayout<KeyData>.stride
        let result = IOConnectCallStructMethod(
            connection, handleEvent, &input, MemoryLayout<KeyData>.stride, &output, &outputSize
        )
        guard result == kIOReturnSuccess, output.result == 0 else { return nil }
        return output
    }

    private static func keyInfo(_ key: UInt32) -> KeyInfo? {
        var input = KeyData()
        input.key = key
        input.command = keyInfoCommand
        guard let output = call(input) else { return nil }
        return KeyInfo(size: output.dataSize, type: output.dataType)
    }

    /// Enumerated once — there are thousands of keys, but the set never changes while running.
    private static func allTemperatureKeys() -> [(key: UInt32, name: String, info: KeyInfo)] {
        if let temperatureKeys { return temperatureKeys }
        guard open() else {
            temperatureKeys = []
            return []
        }

        var found: [(key: UInt32, name: String, info: KeyInfo)] = []
        let countKey = fourCC("#KEY")
        let count = keyInfo(countKey).flatMap { rawBytes(countKey, info: $0) }
            .map { $0.reduce(0) { $0 << 8 | Int($1) } } ?? 0

        for index in 0..<count {
            var input = KeyData()
            input.command = keyAtIndexCommand
            input.data32 = UInt32(index)
            guard let output = call(input) else { continue }
            let name = string(fromFourCC: output.key)
            guard name.hasPrefix("T"), let info = keyInfo(output.key),
                  info.type == floatType || info.type == sp78Type else { continue }
            found.append((output.key, name, info))
        }
        temperatureKeys = found
        return found
    }

    private static func rawBytes(_ key: UInt32, info: KeyInfo) -> [UInt8]? {
        var input = KeyData()
        input.key = key
        input.dataSize = info.size
        input.command = readBytesCommand
        guard let output = call(input) else { return nil }
        return withUnsafeBytes(of: output.bytes) { Array($0.prefix(Int(min(info.size, 32)))) }
    }

    private static func read(_ key: UInt32, info: KeyInfo) -> Double? {
        guard let bytes = rawBytes(key, info: info) else { return nil }
        if info.type == floatType, bytes.count >= 4 {
            return Double(bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) })
        }
        if info.type == sp78Type, bytes.count >= 2 {
            // Signed fixed point, 8 fractional bits, big-endian.
            return Double(Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256
        }
        return nil
    }

    private static func fourCC(_ string: String) -> UInt32 {
        string.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }

    private static func string(fromFourCC value: UInt32) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8((value >> UInt32($0)) & 0xff) }
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }
}
