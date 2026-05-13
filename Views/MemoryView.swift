import SwiftUI

struct MemoryView: View {
    @Environment(SystemMonitor.self) private var monitor
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            HStack(spacing: AppTheme.Spacing.medium) {
                CircularGauge(
                    value: monitor.memory.usagePercentage,
                    title: "Memory",
                    unit: "\(Int(monitor.memory.usagePercentage * 100))%",
                    gradient: AppTheme.Colors.memGradient
                )
                .vibrantCard(padding: AppTheme.Spacing.large)
                
                VStack(spacing: AppTheme.Spacing.small) {
                    LiquidDetailCard(
                        icon: "memorychip",
                        label: "Usage",
                        value: "\(Int(monitor.memory.usagePercentage * 100))%",
                        color: AppTheme.Colors.accentColor(for: .memory)
                    )

                    LiquidDetailCard(
                        icon: "thermometer.medium",
                        label: "Temp",
                        value: String(format: "%.1f°C", monitor.memory.temperature),
                        color: .orange
                    )
                }
            }
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Usage History")
                    .font(.headline)
                
                MiniHistoryChart(
                    data: monitor.memory.usageHistory,
                    gradient: AppTheme.Colors.memGradient
                )
            }
            .vibrantCard()
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Composition")
                    .font(.headline)
                
                HStack(spacing: AppTheme.Spacing.small) {
                    CompositionItem(label: "Used", value: monitor.memory.used, total: monitor.memory.total, color: .red)
                    CompositionItem(label: "Active", value: monitor.memory.active, total: monitor.memory.total, color: .orange)
                    CompositionItem(label: "Compressed", value: monitor.memory.compressed, total: monitor.memory.total, color: .blue)
                    CompositionItem(label: "Free", value: monitor.memory.free, total: monitor.memory.total, color: .green)
                }
            }
            .vibrantCard()
            
            TopProcessesView(
                title: "Top Memory Processes",
                processes: monitor.processes.topByMemory,
                metric: .memory,
                color: AppTheme.Colors.accentColor(for: .memory)
            )
        }
    }
}

struct CompositionItem: View {
    let label: String
    let value: Double
    let total: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            Text("\(Int((value/total)*100))%")
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
