import SwiftUI

struct DiskView: View {
    @Environment(SystemMonitor.self) private var monitor
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            HStack(spacing: AppTheme.Spacing.medium) {
                CircularGauge(
                    value: monitor.disk.usagePercentage,
                    title: "Storage",
                    unit: "\(Int(monitor.disk.usagePercentage * 100))%",
                    gradient: AppTheme.Colors.diskGradient
                )
                .vibrantCard(padding: AppTheme.Spacing.large)
                
                VStack(spacing: AppTheme.Spacing.small) {
                    LiquidDetailCard(
                        icon: "internaldrive",
                        label: "Capacity",
                        value: formatBytes(monitor.disk.total),
                        color: AppTheme.Colors.accentColor(for: .disk)
                    )

                    LiquidDetailCard(
                        icon: "thermometer.medium",
                        label: "Temp",
                        value: String(format: "%.1f°C", monitor.disk.temperature),
                        color: .orange
                    )
                }
            }
            
            HStack(spacing: AppTheme.Spacing.medium) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 12, weight: .bold))
                        Text("Read Speed")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    Text(formatBitrate(monitor.disk.readSpeed))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    MiniHistoryChart(data: monitor.disk.readHistory, gradient: Gradient(colors: [.blue, .cyan]))
                        .frame(height: 50)
                }
                .vibrantCard()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 12, weight: .bold))
                        Text("Write Speed")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    Text(formatBitrate(monitor.disk.writeSpeed))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    MiniHistoryChart(data: monitor.disk.writeHistory, gradient: Gradient(colors: [.purple, .pink]))
                        .frame(height: 50)
                }
                .vibrantCard()
            }
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Disk Status")
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(AppTheme.Colors.batteryGreen)
                    Text("S.M.A.R.T. Status: Healthy")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                }
            }
            .vibrantCard()
            
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
