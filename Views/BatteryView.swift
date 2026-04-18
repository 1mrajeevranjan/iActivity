import SwiftUI

struct BatteryView: View {
    @Environment(SystemMonitor.self) private var monitor
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            ZStack {
                CircularGauge(
                    value: Double(monitor.battery.level) / 100.0,
                    title: "Battery",
                    unit: "\(monitor.battery.level)%",
                    gradient: AppTheme.Colors.batteryGradient
                )
                
                if monitor.battery.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.title)
                        .foregroundStyle(.yellow)
                        .offset(y: -40)
                }
            }
            .liquidGlass(padding: AppTheme.Spacing.large)
            
            HStack(spacing: AppTheme.Spacing.medium) {
                LiquidDetailCard(
                    icon: "plug.fill",
                    label: "Source",
                    value: monitor.battery.powerSource,
                    color: .orange
                )
                
                LiquidDetailCard(
                    icon: "clock.fill",
                    label: monitor.battery.isCharging ? "Time to Full" : "Time to Empty",
                    value: formatTime(monitor.battery.isCharging ? monitor.battery.timeToFull : monitor.battery.timeToEmpty),
                    color: .blue
                )
            }
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Health & Tech")
                    .font(.headline)
                
                HStack(spacing: AppTheme.Spacing.medium) {
                    DetailRow(label: "Health", value: "98%")
                    Divider()
                    DetailRow(label: "Cycles", value: "42")
                }
            }
            .liquidGlass()
            
            TopProcessesView(
                title: "Top Energy Impact",
                processes: monitor.processes.topByCPU,
                metric: .cpu,
                color: AppTheme.Colors.accentColor(for: .battery)
            )
        }
    }
    
    private func formatTime(_ minutes: Int) -> String {
        if minutes < 0 { return "Calculating..." }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}
