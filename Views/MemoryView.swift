import SwiftUI

struct MemoryView: View {
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage("temperatureUnit") private var temperatureUnit: TemperatureUnit = .celsius

    private var tint: Color { AppTheme.Colors.accentColor(for: .memory) }

    /// The kernel's pressure level, as Activity Monitor colours its graph — not a threshold on
    /// used memory, which stays high on a healthy Mac because macOS fills spare RAM with cache.
    private var pressure: (label: String, color: Color) {
        switch monitor.memory.pressure {
        case .critical: return ("Critical", .red)
        case .warning: return ("Warning", .orange)
        case .normal: return ("Normal", AppTheme.Colors.batteryGreen)
        }
    }

    var body: some View {
        VStack(spacing: AppTheme.Metrics.groupSpacing) {
            StatTileRow(tiles: [
                .init(icon: "thermometer.medium", label: "Temp", value: temperatureUnit.reading(fromCelsius: monitor.memory.temperature)),
                .init(icon: "memorychip", label: "Total", value: formatBytes(Int64(monitor.memory.total))),
                .init(icon: "tray", label: "Available", value: formatBytes(Int64(max(monitor.memory.total - monitor.memory.used, 0)))),
            ], tint: tint)

            CardDivider()

            VStack(alignment: .leading, spacing: AppTheme.Metrics.rowSpacing) {
                HStack(spacing: 8) {
                    GroupLabel(text: "Memory")
                    StatusPill(text: pressure.label, color: pressure.color)
                    Spacer(minLength: 0)
                    Text("\(formatBytes(Int64(monitor.memory.used))) / \(formatBytes(Int64(monitor.memory.total)))")
                        .font(.callout.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                MetricRow(
                    label: "Used",
                    value: "\(Int(monitor.memory.usagePercentage * 100))%",
                    fraction: monitor.memory.usagePercentage,
                    tint: tint,
                    history: monitor.memory.usageHistory,
                    domain: 0...1
                )
            }

            CardDivider()

            VStack(alignment: .leading, spacing: AppTheme.Metrics.rowSpacing) {
                GroupLabel(text: "Composition")
                // Same breakdown as Activity Monitor: the first three sum to "Used".
                CompositionRow(label: "App", value: formatBytes(Int64(monitor.memory.appMemory)), fraction: share(monitor.memory.appMemory), tint: tint)
                CompositionRow(label: "Wired", value: formatBytes(Int64(monitor.memory.wired)), fraction: share(monitor.memory.wired), tint: .purple)
                CompositionRow(label: "Compressed", value: formatBytes(Int64(monitor.memory.compressed)), fraction: share(monitor.memory.compressed), tint: .orange)
                CompositionRow(label: "Cached", value: formatBytes(Int64(monitor.memory.cached)), fraction: share(monitor.memory.cached), tint: .teal)
                CompositionRow(label: "Swap", value: formatBytes(Int64(monitor.memory.swapUsed)), fraction: share(monitor.memory.swapUsed), tint: .secondary)
            }

            CardDivider()

            VStack(alignment: .leading, spacing: AppTheme.Metrics.rowSpacing) {
                GroupLabel(text: "Top processes")
                TopProcessesView(processes: monitor.processes.topByMemory, metric: .memory, tint: tint)
            }
        }
    }

    private func share(_ bytes: Double) -> Double {
        guard monitor.memory.total > 0 else { return 0 }
        return bytes / monitor.memory.total
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        // Without this a zero reads as "Zero KB" — memory composition hits zero for real.
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: bytes)
    }
}

/// Composition line: a short bar showing the slice's share of total, name, and absolute size.
struct CompositionRow: View {
    let label: String
    let value: String
    let fraction: Double
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.primary)
                .frame(width: 80, alignment: .leading)

            ProgressBar(fraction: fraction, tint: tint, animated: !reduceMotion)

            Text(value)
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(value))
    }
}

/// Small filled pill with a leading dot, for a one-word state.
struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.18), in: Capsule(style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
