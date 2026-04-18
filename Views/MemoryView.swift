import SwiftUI

struct MemoryView: View {
    @Environment(SystemMonitor.self) private var monitor
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            HStack(spacing: AppTheme.Spacing.medium) {
                CircularGauge(
                    value: monitor.memory.usagePercentage,
                    title: "Memory",
                    unit: "Usage",
                    gradient: AppTheme.Colors.memGradient
                )
                .liquidGlass(padding: AppTheme.Spacing.large)
                
                VStack(spacing: AppTheme.Spacing.small) {
                    LiquidDetailCard(
                        icon: "memorychip",
                        label: "Total RAM",
                        value: formatBytes(monitor.memory.total),
                        color: AppTheme.Colors.accentColor(for: .memory)
                    )
                    
                    LiquidDetailCard(
                        icon: "arrow.up.circle",
                        label: "Used",
                        value: formatBytes(monitor.memory.used),
                        color: .red
                    )
                }
            }
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Memory History")
                    .font(.headline)
                
                MiniHistoryChart(
                    data: monitor.memory.usageHistory,
                    gradient: AppTheme.Colors.memGradient
                )
            }
            .liquidGlass()
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Composition")
                    .font(.headline)
                
                HStack(spacing: AppTheme.Spacing.small) {
                    CompositionItem(label: "Wired", value: monitor.memory.wired, total: monitor.memory.total, color: .blue)
                    CompositionItem(label: "Active", value: monitor.memory.active, total: monitor.memory.total, color: .red)
                    CompositionItem(label: "Compressed", value: monitor.memory.compressed, total: monitor.memory.total, color: .orange)
                    CompositionItem(label: "Free", value: monitor.memory.free, total: monitor.memory.total, color: .green)
                }
            }
            .liquidGlass()
            
            TopProcessesView(
                title: "Top Memory Processes",
                processes: monitor.processes.topByMemory,
                metric: .memory,
                color: AppTheme.Colors.accentColor(for: .memory)
            )
        }
    }
    
    private func formatBytes(_ bytes: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct CompositionItem: View {
    let label: String
    let value: Double
    let total: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
            Text("\(Int((value/total)*100))%")
                .font(.headline.weight(.bold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
