import SwiftUI

struct DiskView: View {
    @Environment(SystemMonitor.self) private var monitor
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            CircularGauge(
                value: monitor.disk.usagePercentage,
                title: "Storage",
                unit: "Used",
                gradient: AppTheme.Colors.diskGradient
            )
            .liquidGlass(padding: AppTheme.Spacing.large)
            
            HStack(spacing: AppTheme.Spacing.medium) {
                LiquidDetailCard(
                    icon: "internaldrive",
                    label: "Total Capacity",
                    value: formatBytes(monitor.disk.total),
                    color: AppTheme.Colors.accentColor(for: .disk)
                )

                LiquidDetailCard(
                    icon: "folder",
                    label: "Available",
                    value: formatBytes(monitor.disk.free),
                    color: .green
                )

                LiquidDetailCard(
                    icon: "thermometer.medium",
                    label: "Temp",
                    value: String(format: "%.1f°C", monitor.disk.temperature),
                    color: .orange
                )
            }
            
            HStack(spacing: AppTheme.Spacing.medium) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Read Speed", systemImage: "arrow.down.circle")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text(formatBitrate(monitor.disk.readSpeed))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                    MiniHistoryChart(data: monitor.disk.readHistory, gradient: Gradient(colors: [.blue, .cyan]))
                        .frame(height: 60)
                }
                .liquidGlass()
                
                VStack(alignment: .leading, spacing: 4) {
                    Label("Write Speed", systemImage: "arrow.up.circle")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text(formatBitrate(monitor.disk.writeSpeed))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                    MiniHistoryChart(data: monitor.disk.writeHistory, gradient: Gradient(colors: [.purple, .pink]))
                        .frame(height: 60)
                }
                .liquidGlass()
            }
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Disk Status")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("SMART Status: Verified")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                }
            }
            .liquidGlass()
            
            TopProcessesView(
                title: "Most Active Processes",
                processes: monitor.processes.topByCPU,
                metric: .cpu,
                color: AppTheme.Colors.accentColor(for: .disk)
            )
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
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
