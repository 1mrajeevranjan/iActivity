import SwiftUI

struct GPUView: View {
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage("temperatureUnit") private var temperatureUnit: TemperatureUnit = .celsius

    private var tint: Color { AppTheme.Colors.accentColor(for: .gpu) }

    var body: some View {
        VStack(spacing: AppTheme.Metrics.groupSpacing) {
            StatTileRow(tiles: [
                .init(icon: "thermometer.medium", label: "Temp", value: temperatureUnit.reading(fromCelsius: monitor.gpu.temperature)),
                // Apple Silicon has no VRAM of its own — show what the GPU holds in unified memory.
                .init(icon: "memorychip", label: monitor.gpu.vramTotal > 0 ? "VRAM" : "Memory",
                      value: monitor.gpu.vramTotal > 0 ? formatBytes(monitor.gpu.vramTotal) : formatBytes(monitor.gpu.vramUsed)),
                .init(icon: "chart.bar", label: "Peak", value: "\(Int((monitor.gpu.history.max() ?? 0) * 100))%"),
            ], tint: tint)

            CardDivider()

            VStack(alignment: .leading, spacing: AppTheme.Metrics.rowSpacing) {
                GroupLabel(text: "Graphics usage")

                MetricRow(
                    label: "GPU",
                    value: "\(Int(monitor.gpu.utilization * 100))%",
                    fraction: monitor.gpu.utilization,
                    tint: tint,
                    history: monitor.gpu.history,
                    domain: 0...1
                )
            }

            CardDivider()

            VStack(alignment: .leading, spacing: AppTheme.Metrics.rowSpacing) {
                // macOS exposes no public per-process GPU time, so this is honest about ranking by CPU.
                GroupLabel(text: "Top processes by CPU")
                TopProcessesView(processes: monitor.processes.topByCPU, metric: .cpu, tint: tint)
            }

            CardDivider()

            VStack(spacing: AppTheme.Metrics.rowSpacing) {
                FactRow(label: "Renderer", value: monitor.gpu.rendererName, icon: "display", tint: tint)
                FactRow(
                    label: "Status",
                    value: monitor.gpu.utilization > 0.8 ? "High load" : "Normal",
                    icon: "bolt",
                    tint: monitor.gpu.utilization > 0.8 ? .orange : tint
                )
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: bytes)
    }
}
