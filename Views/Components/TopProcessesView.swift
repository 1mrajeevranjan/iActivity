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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle.portrait.fill")
                    .foregroundColor(color)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }
            .padding(.bottom, 2)
            
            if processes.isEmpty {
                HStack {
                    Spacer()
                    ProgressView().scaleEffect(0.8)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(processes.enumerated().prefix(5)), id: \.element.id) { index, process in
                        VStack(spacing: 0) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(color.opacity(0.1))
                                        .frame(width: 18, height: 18)
                                    Text("\(index + 1)")
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                        .foregroundColor(color)
                                }
                                
                                Text(process.name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(metric == .cpu ? formatCPU(process.cpuPercent) : formatMemory(process.memoryMB))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(color)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                        }
                        .background {
                            // Relative bar background
                            GeometryReader { geo in
                                let maxVal = processes.first?.cpuPercent ?? 100.0
                                let currentVal = metric == .cpu ? process.cpuPercent : (process.memoryMB / 1024.0) // simplified relative scale
                                let relativeWidth = maxVal > 0 ? (currentVal / maxVal) : 0
                                
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(color.opacity(0.05))
                                    .frame(width: geo.size.width * CGFloat(relativeWidth))
                                    .animation(.spring(), value: relativeWidth)
                            }
                        }
                    }
                }
            }
        }
        .vibrantCard(padding: 12)
    }
    
    private func formatCPU(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
    
    private func formatMemory(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }
}
