import SwiftUI

struct BatteryView: View {
    @Environment(SystemMonitor.self) private var monitor
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            HStack(spacing: AppTheme.Spacing.medium) {
                ZStack {
                    CircularGauge(
                        value: Double(monitor.battery.level) / 100.0,
                        title: "Battery",
                        unit: "\(monitor.battery.level)%",
                        gradient: AppTheme.Colors.batteryGradient
                    )
                    
                    if monitor.battery.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.batteryGreen)
                            .offset(y: -45)
                    }
                }
                .vibrantCard(padding: AppTheme.Spacing.large)
                
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    Text("Health")
                        .font(.headline)
                    
                    DetailRow(label: "Source", value: monitor.battery.powerSource)
                    DetailRow(label: "Health", value: "98%")
                    DetailRow(label: "Cycles", value: "42")
                    DetailRow(label: "Temp", value: String(format: "%.1f°C", monitor.battery.temperature))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .vibrantCard()
            }
            
            HStack(spacing: AppTheme.Spacing.medium) {
                LiquidDetailCard(
                    icon: "clock.fill",
                    label: monitor.battery.isCharging ? "Time to Full" : "Time to Empty",
                    value: formatTime(monitor.battery.isCharging ? monitor.battery.timeToFull : monitor.battery.timeToEmpty),
                    color: .blue
                )

                LiquidDetailCard(
                    icon: "bolt.heart.fill",
                    label: "Energy Impact",
                    value: String(format: "%.1f W", monitor.battery.watts),
                    color: .yellow
                )
            }
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Level History")
                    .font(.headline)
                
                MiniHistoryChart(data: monitor.battery.levelHistory, gradient: AppTheme.Colors.batteryGradient, domain: 0...1)
                    .frame(height: 80)
            }
            .vibrantCard()
            
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
