import SwiftUI

struct CPUView: View {
    @Environment(SystemMonitor.self) private var monitor
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            HStack(spacing: AppTheme.Spacing.medium) {
                CircularGauge(
                    value: monitor.cpu.usage,
                    title: "Total CPU",
                    unit: "Usage",
                    gradient: AppTheme.Colors.cpuGradient
                )
                .liquidGlass(padding: AppTheme.Spacing.large)
                
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    Text("Details")
                        .font(.headline)
                    
                    DetailRow(label: "Model", value: monitor.cpu.modelName)
                    DetailRow(label: "Cores", value: "\(monitor.cpu.coreUsages.count)")
                    DetailRow(label: "Temp", value: String(format: "%.1f°C", monitor.cpu.temperature))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlass()
            }
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Usage History")
                    .font(.headline)
                
                MiniHistoryChart(
                    data: monitor.cpu.history,
                    gradient: AppTheme.Colors.cpuGradient
                )
            }
            .liquidGlass()
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Cores Activity")
                    .font(.headline)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.small) {
                    ForEach(0..<monitor.cpu.coreUsages.count, id: \.self) { index in
                        CoreBar(index: index, usage: monitor.cpu.coreUsages[index])
                    }
                }
            }
            .liquidGlass()
            
            TopProcessesView(
                title: "Top CPU Processes",
                processes: monitor.processes.topByCPU,
                metric: .cpu,
                color: AppTheme.Colors.accentColor(for: .cpu)
            )
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
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
