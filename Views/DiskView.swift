import SwiftUI

struct DiskView: View {
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage("temperatureUnit") private var temperatureUnit: TemperatureUnit = .celsius

    private var tint: Color { AppTheme.Colors.accentColor(for: .disk) }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
                CircularGauge(
                    value: monitor.disk.usagePercentage,
                    title: "Storage",
                    unit: "\(Int(monitor.disk.usagePercentage * 100))%",
                    gradient: AppTheme.Colors.diskGradient
                )
                .glassTile(padding: AppTheme.Spacing.large, tint: tint)

                StatTileGrid(tiles: [
                    ("internaldrive", "Size", formatBytes(monitor.disk.total)),
                    ("thermometer.medium", "Temp", temperatureUnit.string(fromCelsius: monitor.disk.temperature)),
                    ("externaldrive.badge.checkmark", "Free", formatBytes(monitor.disk.free)),
                    ("checkmark.shield.fill", "Status", "Healthy"),
                ], tint: tint)
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: AppTheme.Spacing.medium) {
                ChartCard(
                    title: "Read Speed",
                    value: formatBitrate(monitor.disk.readSpeed),
                    data: monitor.disk.readHistory,
                    gradient: Gradient(colors: [.blue, .cyan]),
                    tint: .blue,
                    height: 60
                )
                ChartCard(
                    title: "Write Speed",
                    value: formatBitrate(monitor.disk.writeSpeed),
                    data: monitor.disk.writeHistory,
                    gradient: Gradient(colors: [.purple, .pink]),
                    tint: .purple,
                    height: 60
                )
            }

            TopProcessesView(
                title: "Most Active Processes",
                processes: monitor.processes.topByCPU,
                metric: .cpu,
                color: tint
            )
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.countStyle = .file
        formatter.isAdaptive = false
        let raw = formatter.string(fromByteCount: bytes)
        // Round to a whole number so it always fits the tile ("494 GB", not "494.38…").
        guard let dotIndex = raw.firstIndex(of: "."), let unitStart = raw.firstIndex(of: " ") else { return raw }
        return String(raw[raw.startIndex..<dotIndex]) + String(raw[unitStart...])
    }

    private func formatBitrate(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000_000 {
            return String(format: "%.1f GB/s", bytesPerSecond / 1_000_000_000)
        } else if bytesPerSecond >= 1_000_000 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_000_000)
        } else if bytesPerSecond >= 1_000 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1_000)
        } else {
            return String(format: "%.0f B/s", bytesPerSecond)
        }
    }
}
