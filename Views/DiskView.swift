import SwiftUI

struct DiskView: View {
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage("temperatureUnit") private var temperatureUnit: TemperatureUnit = .celsius

    private var tint: Color { AppTheme.Colors.accentColor(for: .disk) }

    var body: some View {
        VStack(spacing: AppTheme.Metrics.groupSpacing) {
            StatTileRow(tiles: [
                .init(icon: "thermometer.medium", label: "Temp", value: temperatureUnit.reading(fromCelsius: monitor.disk.temperature)),
                .init(icon: "internaldrive", label: "Size", value: formatBytes(monitor.disk.total)),
                .init(icon: "tray", label: "Free", value: formatBytes(monitor.disk.free)),
            ], tint: tint)

            CardDivider()

            VStack(alignment: .leading, spacing: AppTheme.Metrics.rowSpacing) {
                GroupLabel(text: "Storage")
                MetricRow(
                    label: "Used",
                    value: "\(Int(monitor.disk.usagePercentage * 100))%",
                    fraction: monitor.disk.usagePercentage,
                    tint: tint
                )
            }

            CardDivider()

            VStack(alignment: .leading, spacing: AppTheme.Metrics.rowSpacing) {
                GroupLabel(text: "Activity")
                MetricRow(
                    label: "Read",
                    value: formatBitrate(monitor.disk.readSpeed),
                    tint: AppTheme.Colors.brandBlue,
                    icon: "arrow.down",
                    history: monitor.disk.readHistory
                )
                MetricRow(
                    label: "Write",
                    value: formatBitrate(monitor.disk.writeSpeed),
                    tint: .purple,
                    icon: "arrow.up",
                    history: monitor.disk.writeHistory
                )
            }

            CardDivider()

            VStack(alignment: .leading, spacing: AppTheme.Metrics.rowSpacing) {
                GroupLabel(text: "Most active processes")
                TopProcessesView(processes: monitor.processes.topByDisk, metric: .disk, tint: tint)
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.countStyle = .file
        formatter.isAdaptive = false
        formatter.allowsNonnumericFormatting = false
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
            return String(format: "%.0f KB/s", bytesPerSecond / 1_000)
        } else {
            return String(format: "%.0f B/s", bytesPerSecond)
        }
    }
}
