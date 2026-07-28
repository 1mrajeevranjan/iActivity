import SwiftUI

struct BatteryView: View {
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage("temperatureUnit") private var temperatureUnit: TemperatureUnit = .celsius

    private var tint: Color { AppTheme.Colors.accentColor(for: .battery) }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
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
                .glassTile(padding: AppTheme.Spacing.large, tint: tint)

                StatTileGrid(tiles: [
                    ("powerplug.fill", "Source", shortPowerSource(monitor.battery.powerSource)),
                    ("heart.fill", "Health", monitor.battery.healthPercentage > 0 ? String(format: "%.0f%%", monitor.battery.healthPercentage) : "—"),
                    ("arrow.triangle.2.circlepath", "Cycles", monitor.battery.cycleCount > 0 ? String(monitor.battery.cycleCount) : "—"),
                    ("thermometer.medium", "Temp", temperatureUnit.string(fromCelsius: monitor.battery.temperature)),
                ], tint: tint)
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: AppTheme.Spacing.medium) {
                StatTile(
                    icon: "clock.fill",
                    label: monitor.battery.isCharging ? "Time to Full" : "Time to Empty",
                    value: formatTime(monitor.battery.isCharging ? monitor.battery.timeToFull : monitor.battery.timeToEmpty),
                    tint: tint
                )
                StatTile(icon: "bolt.heart.fill", label: "Energy Impact", value: String(format: "%.1f W", monitor.battery.watts), tint: .yellow)
            }

            ChartCard(
                title: "Level History",
                value: "\(monitor.battery.level)%",
                data: monitor.battery.levelHistory,
                gradient: AppTheme.Colors.batteryGradient,
                tint: tint,
                domain: 0...1,
                height: 80
            )

            TopProcessesView(
                title: "Top Energy Impact",
                processes: monitor.processes.topByCPU,
                metric: .cpu,
                color: tint
            )
        }
    }

    private func shortPowerSource(_ raw: String) -> String {
        if raw.contains("AC") { return "AC Power" }
        if raw.contains("Battery") { return "Battery" }
        return raw
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
