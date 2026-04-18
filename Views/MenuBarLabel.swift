import SwiftUI

struct MenuBarLabel: View {
    let monitor: SystemMonitor
    @AppStorage("selectedCategory") private var selectedCategory: MetricCategory = .cpu
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: selectedCategory.icon)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 13, weight: .bold))
            
            if selectedCategory == .network {
                networkLabel
            } else {
                Text(currentValue)
            }
        }
        .font(.system(size: 13.5, weight: .bold))
        .padding(.horizontal, 4)
    }
    
    // MARK: - Network Label (↓ down ↑ up)
    private var networkLabel: some View {
        Text("↓\(formatSpeed(monitor.network.downloadSpeed)) ↑\(formatSpeed(monitor.network.uploadSpeed))")
    }
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000 {
            return String(format: "%.1fM", bytesPerSecond / 1_000_000)
        } else if bytesPerSecond >= 1_000 {
            return String(format: "%.0fK", bytesPerSecond / 1_000)
        } else {
            return String(format: "%.0fB", bytesPerSecond)
        }
    }
    
    private var currentValue: String {
        switch selectedCategory {
        case .cpu:
            return "\(Int(monitor.cpu.usage * 100))%"
        case .gpu:
            return "\(Int(monitor.gpu.utilization * 100))%"
        case .memory:
            return "\(Int(monitor.memory.usagePercentage * 100))%"
        case .disk:
            return "\(Int(monitor.disk.usagePercentage * 100))%"
        case .battery:
            return "\(monitor.battery.level)%"
        case .network:
            return "" // handled by networkLabel
        }
    }
}
