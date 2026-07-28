import SwiftUI

struct NetworkView: View {
    @Environment(SystemMonitor.self) private var monitor

    private var tint: Color { AppTheme.Colors.accentColor(for: .network) }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            StatTileGrid(tiles: [
                ("arrow.down.circle.fill", "Download", formatSpeed(monitor.network.downloadSpeed)),
                ("arrow.up.circle.fill", "Upload", formatSpeed(monitor.network.uploadSpeed)),
                ("arrow.down.to.line.circle", "Peak Down", formatSpeed(monitor.network.downloadHistory.max() ?? 0)),
                ("arrow.up.to.line.circle", "Peak Up", formatSpeed(monitor.network.uploadHistory.max() ?? 0)),
            ], tint: tint)

            ChartCard(
                title: "Download",
                value: formatSpeed(monitor.network.downloadSpeed),
                data: monitor.network.downloadHistory,
                gradient: Gradient(colors: [.blue, .cyan]),
                tint: .blue,
                height: 60
            )

            ChartCard(
                title: "Upload",
                value: formatSpeed(monitor.network.uploadSpeed),
                data: monitor.network.uploadHistory,
                gradient: Gradient(colors: [AppTheme.Colors.batteryGreen, .mint]),
                tint: AppTheme.Colors.batteryGreen,
                height: 60
            )

            HStack(spacing: AppTheme.Spacing.medium) {
                StatTile(icon: "wifi", label: "Interface", value: monitor.network.primaryInterfaceName, tint: tint)
                StatTile(icon: monitor.network.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill", label: "Status", value: monitor.network.isConnected ? "Connected" : "Offline", tint: monitor.network.isConnected ? AppTheme.Colors.batteryGreen : .red)
            }

            TopProcessesView(
                title: "Most Active Processes",
                processes: monitor.processes.topByCPU,
                metric: .cpu,
                color: tint
            )
        }
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_000_000)
        } else if bytesPerSecond >= 1_000 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1_000)
        } else {
            return String(format: "%.0f B/s", bytesPerSecond)
        }
    }
}
