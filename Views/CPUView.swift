import SwiftUI

struct CPUView: View {
    @Environment(SystemMonitor.self) private var monitor
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            HStack(spacing: AppTheme.Spacing.medium) {
                CircularGauge(
                    value: monitor.cpu.usage,
                    title: "CPU",
                    unit: "\(Int(monitor.cpu.usage * 100))%",
                    gradient: AppTheme.Colors.cpuGradient
                )
                .vibrantCard(padding: AppTheme.Spacing.large)
                
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    Text("Details")
                        .font(.headline)
                    
                    DetailRow(label: "Cores", value: "\(monitor.cpu.coreUsages.count)")
                    DetailRow(label: "Temp", value: String(format: "%.1f°C", monitor.cpu.temperature))
                    DetailRow(label: "Model", value: monitor.cpu.modelName)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .vibrantCard()
            }
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Usage History")
                    .font(.headline)
                
                MiniHistoryChart(
                    data: monitor.cpu.history,
                    gradient: AppTheme.Colors.cpuGradient
                )
            }
            .vibrantCard()
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Cores Activity")
                    .font(.headline)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.small) {
                    ForEach(0..<monitor.cpu.coreUsages.count, id: \.self) { index in
                        CoreBar(index: index, usage: monitor.cpu.coreUsages[index])
                    }
                }
            }
            .vibrantCard()
            
            TopProcessesView(
                title: "Top CPU Processes",
                processes: monitor.processes.topByCPU,
                metric: .cpu,
                color: AppTheme.Colors.accentColor(for: .cpu)
            )
        }
    }
}


struct CoreBar: View {
    let index: Int
    let usage: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Core \(index)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.1))
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(gradient: AppTheme.Colors.cpuGradient, startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(usage))
                }
            }
            .frame(height: 4)
        }
    }
}

#Preview {
    CPUView()
        .environment(SystemMonitor())
        .padding()
}
