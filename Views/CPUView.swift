import SwiftUI

struct CPUView: View {
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage("temperatureUnit") private var temperatureUnit: TemperatureUnit = .celsius

    private var tint: Color { AppTheme.Colors.accentColor(for: .cpu) }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
                CircularGauge(
                    value: monitor.cpu.usage,
                    title: "CPU",
                    unit: "\(Int(monitor.cpu.usage * 100))%",
                    gradient: AppTheme.Colors.cpuGradient
                )
                .glassTile(padding: AppTheme.Spacing.large, tint: tint)

                StatTileGrid(tiles: [
                    ("cpu", "Cores", "\(monitor.cpu.coreUsages.count)"),
                    ("thermometer.medium", "Temp", temperatureUnit.string(fromCelsius: monitor.cpu.temperature)),
                    ("gauge.with.needle", "Peak", "\(Int((monitor.cpu.history.max() ?? 0) * 100))%"),
                    ("chart.bar.fill", "Avg", "\(Int(average(monitor.cpu.history) * 100))%"),
                ], tint: tint)
                .frame(maxWidth: .infinity)
            }

            StatTile(icon: "cpu.fill", label: "Model", value: monitor.cpu.modelName, tint: tint)

            ChartCard(
                title: "Usage History",
                value: "\(Int(monitor.cpu.usage * 100))%",
                data: monitor.cpu.history,
                gradient: AppTheme.Colors.cpuGradient,
                tint: tint
            )

            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Cores Activity")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.small) {
                    ForEach(0..<monitor.cpu.coreUsages.count, id: \.self) { index in
                        CoreBar(index: index, usage: monitor.cpu.coreUsages[index])
                    }
                }
            }
            .glassTile(tint: tint)

            TopProcessesView(
                title: "Top CPU Processes",
                processes: monitor.processes.topByCPU,
                metric: .cpu,
                color: tint
            )
        }
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
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
