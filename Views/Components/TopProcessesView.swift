import SwiftUI

struct TopProcessesView: View {
    let title: String
    let processes: [ProcessMonitor.ProcessEntry]
    let metric: Metric
    let color: Color
    
    enum Metric {
        case cpu
        case memory
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section title
            HStack(spacing: 6) {
                Image(systemName: "list.number")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline.weight(.bold))
            }
            
            if processes.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Collecting data…")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    Spacer()
                }
            } else {
                // Column headers
                HStack(spacing: 0) {
                    Text("#")
                        .frame(width: 20, alignment: .center)
                    Text("Process")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("CPU")
                        .frame(width: 55, alignment: .trailing)
                    Text("MEM")
                        .frame(width: 55, alignment: .trailing)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                
                // Process rows
                ForEach(Array(processes.enumerated()), id: \.element.id) { index, process in
                    HStack(spacing: 0) {
                        // Rank badge
                        ZStack {
                            Circle()
                                .fill(color.opacity(Double(5 - index) / 6.0))
                                .frame(width: 16, height: 16)
                            Text("\(index + 1)")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 20)
                        
                        // Process name
                        Text(process.name)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)
                        
                        // CPU value
                        Text(formatCPU(process.cpuPercent))
                            .font(.caption.weight(metric == .cpu ? .bold : .regular).monospacedDigit())
                            .foregroundStyle(metric == .cpu ? color : .secondary)
                            .frame(width: 55, alignment: .trailing)
                        
                        // Memory value
                        Text(formatMemory(process.memoryMB))
                            .font(.caption.weight(metric == .memory ? .bold : .regular).monospacedDigit())
                            .foregroundStyle(metric == .memory ? color : .secondary)
                            .frame(width: 55, alignment: .trailing)
                    }
                    .padding(.vertical, 3)
                    
                    if index < processes.count - 1 {
                        Divider().opacity(0.2)
                    }
                }
            }
        }
        .liquidGlass()
    }
    
    // MARK: - Formatters
    
    private func formatCPU(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f%%", value)
        }
        return String(format: "%.1f%%", value)
    }
    
    private func formatMemory(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1fG", mb / 1024)
        }
        return String(format: "%.0fM", mb)
    }
}
