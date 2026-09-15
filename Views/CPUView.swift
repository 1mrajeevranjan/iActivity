import SwiftUI

struct CPUView: View {
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage("temperatureUnit") private var temperatureUnit: TemperatureUnit = .celsius
    @State private var showingCores = false

    private var tint: Color { AppTheme.Colors.accentColor(for: .cpu) }

    /// P-cores keep the CPU tab's blue; E-cores take the cooler teal so the two clusters are
    /// distinguishable at a glance without either reading as an alert colour.
    static let performanceTint = AppTheme.Colors.brandBlue
    static let efficiencyTint = Color.teal

    static func coreTint(_ kind: CPUMonitor.CoreKind, fallback: Color) -> Color {
        switch kind {
        case .performance: return performanceTint
        case .efficiency: return efficiencyTint
        case .undifferentiated: return fallback
        }
    }

    var body: some View {
        VStack(spacing: AppTheme.Metrics.groupSpacing) {
            StatTileRow(tiles: [
                .init(icon: "thermometer.medium", label: "Temp", value: temperatureUnit.string(fromCelsius: monitor.cpu.temperature, decimals: 0)),
                .init(icon: "cpu", label: "Cores", value: "\(monitor.cpu.coreUsages.count)"),
                .init(icon: "chart.bar.fill", label: "Peak", value: "\(Int((monitor.cpu.history.max() ?? 0) * 100))%"),
            ], tint: tint)

            CardDivider()

            VStack(alignment: .leading, spacing: AppTheme.Metrics.rowSpacing) {
                GroupLabel(text: "Processor usage")

                MetricRow(
                    label: "CPU",
                    value: "\(Int(monitor.cpu.usage * 100))%",
                    fraction: monitor.cpu.usage,
                    tint: tint,
                    history: monitor.cpu.history,
                    domain: 0...1
                )

                DisclosureRow(title: "Cores", isExpanded: $showingCores)

                if showingCores {
                    VStack(spacing: 5) {
                        ForEach(Array(monitor.cpu.coreUsages.enumerated()), id: \.offset) { index, usage in
                            let kind = monitor.cpu.coreKind(at: index)
                            CoreBar(kind: kind, usage: usage, tint: Self.coreTint(kind, fallback: tint))
                        }
                    }

                    if monitor.cpu.efficiencyCoreCount > 0 {
                        HStack(spacing: 12) {
                            CoreLegend(text: "Performance", color: Self.performanceTint)
                            CoreLegend(text: "Efficiency", color: Self.efficiencyTint)
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                }
            }

            CardDivider()

            VStack(alignment: .leading, spacing: AppTheme.Metrics.rowSpacing) {
                GroupLabel(text: "Top processes")
                TopProcessesView(processes: monitor.processes.topByCPU, metric: .cpu, tint: tint)
            }

            CardDivider()

            FactRow(label: "Model", value: monitor.cpu.modelName, icon: "cpu.fill", tint: tint)
        }
    }
}

struct CoreBar: View {
    let kind: CPUMonitor.CoreKind
    let usage: Double
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            Text(kind.label)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)

            ProgressBar(fraction: usage, tint: tint, animated: !reduceMotion)

            Text("\(Int(usage * 100))%")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(kind.spokenLabel))
        .accessibilityValue(Text("\(Int(usage * 100)) percent"))
    }
}

/// Dot + name, so the two core colours are decoded rather than guessed — colour alone is never
/// the only carrier of meaning.
struct CoreLegend: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Chevron row that expands a nested group, matching the panel's disclosure idiom.
struct DisclosureRow: View {
    let title: String
    @Binding var isExpanded: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            if reduceMotion {
                isExpanded.toggle()
            } else {
                withAnimation(.easeOut(duration: 0.2)) { isExpanded.toggle() }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerOnHover()
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(isExpanded ? "Expanded" : "Collapsed"))
        .accessibilityAddTraits(.isButton)
    }
}
