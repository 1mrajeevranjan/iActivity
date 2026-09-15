import SwiftUI

struct NetworkView: View {
    @Environment(SystemMonitor.self) private var monitor

    private var tint: Color { AppTheme.Colors.accentColor(for: .network) }

    var body: some View {
        VStack(spacing: AppTheme.Metrics.groupSpacing) {
            StatTileRow(tiles: [
                .init(icon: "arrow.down", label: "Down", value: formatSpeed(monitor.network.downloadSpeed)),
                .init(icon: "arrow.up", label: "Up", value: formatSpeed(monitor.network.uploadSpeed)),
            ], tint: tint)

            CardDivider()

            VStack(alignment: .leading, spacing: AppTheme.Metrics.rowSpacing) {
                HStack(spacing: 8) {
                    GroupLabel(text: "Throughput")
                    StatusPill(
                        text: monitor.network.isConnected ? "Connected" : "Offline",
                        color: monitor.network.isConnected ? AppTheme.Colors.batteryGreen : .red
                    )
                    Spacer(minLength: 0)
                }

                // Throughput has no ceiling to fill a bar against, so these rows are a reading
                // plus a trend — inventing a percentage here would be a lie.
                MetricRow(
                    label: "Download",
                    value: formatSpeed(monitor.network.downloadSpeed),
                    tint: AppTheme.Colors.brandBlue,
                    icon: "arrow.down",
                    history: monitor.network.downloadHistory
                )
                MetricRow(
                    label: "Upload",
                    value: formatSpeed(monitor.network.uploadSpeed),
                    tint: AppTheme.Colors.batteryGreen,
                    icon: "arrow.up",
                    history: monitor.network.uploadHistory
                )
            }

            CardDivider()

            VStack(alignment: .leading, spacing: AppTheme.Metrics.rowSpacing) {
                GroupLabel(text: "Peaks")
                FactRow(label: "Peak down", value: formatSpeed(monitor.network.downloadHistory.max() ?? 0), icon: "arrow.down.to.line", tint: AppTheme.Colors.brandBlue)
                FactRow(label: "Peak up", value: formatSpeed(monitor.network.uploadHistory.max() ?? 0), icon: "arrow.up.to.line", tint: AppTheme.Colors.batteryGreen)
                FactRow(label: "Interface", value: monitor.network.primaryInterfaceName, icon: "wifi", tint: tint)
            }

            CardDivider()

            VStack(alignment: .leading, spacing: AppTheme.Metrics.rowSpacing) {
                GroupLabel(text: "Most active processes")
                TopProcessesView(processes: monitor.processes.topByCPU, metric: .cpu, tint: tint)
            }
        }
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_000_000)
        } else if bytesPerSecond >= 1_000 {
            return String(format: "%.0f KB/s", bytesPerSecond / 1_000)
        } else {
            return String(format: "%.0f B/s", bytesPerSecond)
        }
    }
}
