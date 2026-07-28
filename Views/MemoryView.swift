import SwiftUI

struct MemoryView: View {
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage("temperatureUnit") private var temperatureUnit: TemperatureUnit = .celsius

    private var tint: Color { AppTheme.Colors.accentColor(for: .memory) }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
                CircularGauge(
                    value: monitor.memory.usagePercentage,
                    title: "Memory",
                    unit: "\(Int(monitor.memory.usagePercentage * 100))%",
                    gradient: AppTheme.Colors.memGradient
                )
                .glassTile(padding: AppTheme.Spacing.large, tint: tint)

                StatTileGrid(tiles: [
                    ("thermometer.medium", "Temp", temperatureUnit.string(fromCelsius: monitor.memory.temperature)),
                    ("memorychip", "Total", formatBytes(Int64(monitor.memory.total))),
                ], tint: tint)
                .frame(maxWidth: .infinity)
            }

            ChartCard(
                title: "Usage History",
                value: "\(Int(monitor.memory.usagePercentage * 100))%",
                data: monitor.memory.usageHistory,
                gradient: AppTheme.Colors.memGradient,
                tint: tint
            )

            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Composition")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                StatTileGrid(tiles: [
                    ("circle.fill", "Wired", formatBytes(Int64(monitor.memory.wired))),
                    ("circle.fill", "Active", formatBytes(Int64(monitor.memory.active))),
                    ("circle.fill", "Compressed", formatBytes(Int64(monitor.memory.compressed))),
                    ("circle.fill", "Free", formatBytes(Int64(monitor.memory.free))),
                ], tint: tint)
            }

            TopProcessesView(
                title: "Top Memory Processes",
                processes: monitor.processes.topByMemory,
                metric: .memory,
                color: tint
            )
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
}
