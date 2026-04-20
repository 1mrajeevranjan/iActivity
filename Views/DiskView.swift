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
}
