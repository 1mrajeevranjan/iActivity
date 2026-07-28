import SwiftUI

struct GPUView: View {
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage("temperatureUnit") private var temperatureUnit: TemperatureUnit = .celsius

    private var tint: Color { AppTheme.Colors.accentColor(for: .gpu) }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
                CircularGauge(
                    value: monitor.gpu.utilization,
                    title: "GPU",
                    unit: "\(Int(monitor.gpu.utilization * 100))%",
                    gradient: AppTheme.Colors.gpuGradient
                )
                .glassTile(padding: AppTheme.Spacing.large, tint: tint)

                StatTileGrid(tiles: [
                    ("thermometer.medium", "Temp", temperatureUnit.string(fromCelsius: monitor.gpu.temperature)),
                    ("memorychip", "VRAM", monitor.gpu.vramTotal > 0 ? formatBytes(monitor.gpu.vramTotal) : "Unified"),
                    ("bolt.fill", "Status", monitor.gpu.utilization > 0.8 ? "High Load" : "Normal"),
                ], tint: tint)
                .frame(maxWidth: .infinity)
            }

            StatTile(icon: "square.grid.3x1.below.line.grid.1x2", label: "Renderer", value: monitor.gpu.rendererName, tint: tint)

            ChartCard(
                title: "Utilization History",
                value: "\(Int(monitor.gpu.utilization * 100))%",
                data: monitor.gpu.history,
                gradient: AppTheme.Colors.gpuGradient,
                tint: tint
            )

            TopProcessesView(
                title: "Top GPU Processes",
                processes: monitor.processes.topByCPU,
                metric: .cpu,
                color: tint
            )
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
}
