import SwiftUI

struct MenuBarLabel: View {
    let monitor: SystemMonitor
    @AppStorage("selectedCategory") private var selectedCategory: MetricCategory = .cpu

    var body: some View {
        HStack(spacing: 4) {
            // Temperature shown to the left of the activity indicator
            if let temp = currentTemperature, temp > 0 {
                Text(String(format: "%.0f°", temp))
                    .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundColor(.secondary)
            }

            if selectedCategory == .network {
                networkLabel
                    .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
            } else {
                Text(currentValue)
                    .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
            }

            Image(systemName: iconName)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 4)
    }

    private var iconName: String {
        if selectedCategory == .battery {
            let val = monitor.battery.level
            let charging = monitor.battery.isCharging
            if charging       { return "battery.100.bolt" }
            if val > 80  { return "battery.100" }
            if val > 50  { return "battery.75"  }
            if val > 25  { return "battery.50"  }
            if val > 10  { return "battery.25"  }
            return "battery.0"
        }
        return selectedCategory.icon
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

    // MARK: - Current temperature for the selected category (nil = no sensor)
    private var currentTemperature: Double? {
        switch selectedCategory {
        case .cpu:     return monitor.cpu.temperature
        case .gpu:     return monitor.gpu.temperature
        case .memory:  return monitor.memory.temperature
        case .disk:    return monitor.disk.temperature
        case .battery: return monitor.battery.temperature
        case .network: return nil
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
