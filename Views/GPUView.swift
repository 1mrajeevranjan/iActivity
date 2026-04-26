import SwiftUI

struct GPUView: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            HStack(spacing: AppTheme.Spacing.medium) {
                CircularGauge(
                    value: monitor.gpu.utilization,
                    title: "GPU",
                    unit: "Utilization",
                    gradient: AppTheme.Colors.gpuGradient
                )
                .liquidGlass(padding: AppTheme.Spacing.large)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    Text("GPU Details")
                        .font(.headline)

                    DetailRow(label: "Model", value: "Apple M4")
                    DetailRow(label: "VRAM Total", value: formatBytes(monitor.gpu.vramTotal))
                    DetailRow(label: "Temp", value: String(format: "%.1f°C", monitor.gpu.temperature))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlass()
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Utilization History")
                    .font(.headline)

                MiniHistoryChart(
                    data: monitor.gpu.history,
                    gradient: AppTheme.Colors.gpuGradient
                )
            }
            .liquidGlass()

            TopProcessesView(
                title: "Top GPU Processes",
                processes: monitor.processes.topByCPU,
                metric: .cpu,
                color: AppTheme.Colors.accentColor(for: .gpu)
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
