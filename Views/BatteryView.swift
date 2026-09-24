import SwiftUI
import IOKit.ps

struct BatteryView: View {
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage("temperatureUnit") private var temperatureUnit: TemperatureUnit = .celsius

    private var tint: Color {
        if monitor.battery.isCharging { return AppTheme.Colors.batteryGreen }
        if monitor.battery.level <= 10 { return .red }
        if monitor.battery.level <= 20 { return .orange }
        return AppTheme.Colors.batteryGreen
    }

    var body: some View {
        VStack(spacing: AppTheme.Metrics.groupSpacing) {
            StatTileRow(tiles: [
                .init(icon: "thermometer.medium", label: "Temp", value: temperatureUnit.reading(fromCelsius: monitor.battery.temperature)),
                .init(icon: "heart", label: "Health", value: monitor.battery.healthPercentage > 0 ? String(format: "%.0f%%", monitor.battery.healthPercentage) : "—"),
                .init(icon: "arrow.triangle.2.circlepath", label: "Cycles", value: monitor.battery.cycleCount > 0 ? String(monitor.battery.cycleCount) : "—"),
            ], tint: tint)

            CardDivider()

            VStack(alignment: .leading, spacing: AppTheme.Metrics.rowSpacing) {
                HStack(spacing: 8) {
                    GroupLabel(text: "Charge")
                    StatusPill(
                        text: monitor.battery.isCharging ? "Charging" : shortPowerSource(monitor.battery.powerSource),
                        color: monitor.battery.isCharging ? AppTheme.Colors.batteryGreen : .secondary
                    )
                    Spacer(minLength: 0)
                }

                MetricRow(
                    label: "Level",
                    value: "\(monitor.battery.level)%",
                    fraction: Double(monitor.battery.level) / 100,
                    tint: tint,
                    history: monitor.battery.levelHistory,
                    domain: 0...1
                )
            }

            CardDivider()

            VStack(alignment: .leading, spacing: AppTheme.Metrics.rowSpacing) {
                GroupLabel(text: "Power")
                FactRow(
                    label: monitor.battery.isCharging ? "Time to full" : "Time to empty",
                    value: timeRemaining,
                    icon: "clock",
                    tint: tint
                )
                FactRow(label: "Draw", value: String(format: "%.1f W", monitor.battery.watts), icon: "bolt", tint: .yellow)
            }

            CardDivider()

            VStack(alignment: .leading, spacing: AppTheme.Metrics.rowSpacing) {
                GroupLabel(text: "Apps using significant energy")
                TopProcessesView(processes: monitor.processes.topByCPU, metric: .cpu, tint: tint)
            }
        }
    }

    /// On AC without charging (full, or held by Optimized Charging) the battery isn't emptying,
    /// so there is no time to show — IOKit reports -1 there, which used to read "Calculating…"
    /// forever.
    private var timeRemaining: String {
        let battery = monitor.battery
        if battery.isCharging { return formatTime(battery.timeToFull) }
        if battery.powerSource == kIOPSACPowerValue { return "Not charging" }
        return formatTime(battery.timeToEmpty)
    }

    private func shortPowerSource(_ raw: String) -> String {
        if raw.contains("AC") { return "AC Power" }
        if raw.contains("Battery") { return "On Battery" }
        return raw
    }

    private func formatTime(_ minutes: Int) -> String {
        if minutes < 0 { return "Calculating…" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}
