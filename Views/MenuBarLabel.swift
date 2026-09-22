import SwiftUI

/// The menu bar strip: one segment per selected category, each `[temp] [value] [chart] [icon]`.
///
/// This file used to be dead code — the menu bar was drawn in `AppDelegate.updateMenuBarDisplay()`
/// as an `attributedTitle` plus an SF Symbol, and nothing referenced this view. It is now the live
/// view, hosted inside the status item. That is what lets the menu bar share one chart renderer
/// with the dashboard: picking "Area" in Settings changes both surfaces, instead of every
/// `ChartStyle` having to be written a second time in Core Graphics.
struct MenuBarLabel: View {
    let monitor: SystemMonitor

    @AppStorage(MenuBarSelection.storageKey) private var storedSelection = MenuBarSelection([])
    @AppStorage("selectedCategory") private var dashboardCategory: MetricCategory = .cpu
    @AppStorage("showMenuBarGraph") private var showGraph: Bool = true
    @AppStorage("showTemperature") private var showTemperature: Bool = true
    @AppStorage("temperatureUnit") private var temperatureUnit: TemperatureUnit = .celsius

    /// 28×12pt over the last 24 samples. The full 60-sample buffer is illegible at this width,
    /// and the strip has to stay narrow enough to hold several categories at once.
    private static let chartWidth: CGFloat = 28
    private static let chartHeight: CGFloat = 12
    private static let chartSamples = 24

    /// Migration and the empty-selection fallback both live in `resolved`, so this view and
    /// `SystemMonitor` cannot disagree about which categories are active.
    private var categories: [MetricCategory] {
        MenuBarSelection.resolved(rawValue: storedSelection.rawValue, fallback: dashboardCategory).categories
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(categories) { category in
                segment(for: category)
            }
        }
        .padding(.horizontal, 4)
        // System design, not rounded, with monospaced digits so the strip does not jitter as
        // values change — matching the AppKit original this replaces.
        .font(.system(size: 12, weight: .medium).monospacedDigit())
    }

    private func segment(for category: MetricCategory) -> some View {
        HStack(spacing: 4) {
            if let temperature = temperatureText(for: category) {
                // `.primary`, not `.secondary` — the dimmer tone reads as near-invisible against
                // the menu bar's translucent, wallpaper-varying backdrop.
                Text(temperature)
                    .foregroundStyle(.primary)
            }

            Text(valueText(for: category))
                .foregroundStyle(status(for: category).color)

            if showGraph {
                chart(for: category)
            }

            Image(systemName: iconName(for: category))
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 12, weight: .medium))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(category.displayName))
        .accessibilityValue(Text(valueText(for: category)))
    }

    // MARK: - Readings

    private func valueText(for category: MetricCategory) -> String {
        switch category {
        case .cpu: return percent(monitor.cpu.usage)
        case .gpu: return percent(monitor.gpu.utilization)
        case .memory: return percent(monitor.memory.usagePercentage)
        case .disk: return percent(monitor.disk.usagePercentage)
        case .battery: return "\(monitor.battery.level)%"
        case .network:
            return "↓\(Self.compactSpeed(monitor.network.downloadSpeed)) ↑\(Self.compactSpeed(monitor.network.uploadSpeed))"
        }
    }

    private func percent(_ fraction: Double) -> String { "\(Int(fraction * 100))%" }

    /// The menu bar's own compact formatter — deliberately not the dashboard's "42.1 MB/s",
    /// which is far too wide for a strip that may be holding five categories at once.
    static func compactSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000 { return String(format: "%.1fM", bytesPerSecond / 1_000_000) }
        if bytesPerSecond >= 1_000 { return String(format: "%.0fK", bytesPerSecond / 1_000) }
        return String(format: "%.0fB", bytesPerSecond)
    }

    private func status(for category: MetricCategory) -> MenuBarStatus {
        let fraction: Double = switch category {
        case .cpu: monitor.cpu.usage
        case .gpu: monitor.gpu.utilization
        case .memory: monitor.memory.usagePercentage
        case .disk: monitor.disk.usagePercentage
        case .battery: Double(monitor.battery.level) / 100
        case .network: 0
        }
        return MenuBarStatus.level(for: category, value: fraction, isCharging: monitor.battery.isCharging)
    }

    private func temperatureText(for category: MetricCategory) -> String? {
        guard showTemperature else { return nil }
        let celsius: Double = switch category {
        case .cpu: monitor.cpu.temperature
        case .gpu: monitor.gpu.temperature
        case .memory: monitor.memory.temperature
        case .disk: monitor.disk.temperature
        case .battery: monitor.battery.temperature
        case .network: 0 // No temperature sensor for network.
        }
        guard celsius > 0 else { return nil }
        return temperatureUnit.string(fromCelsius: celsius, decimals: 0)
    }

    private func iconName(for category: MetricCategory) -> String {
        guard category == .battery else { return category.icon }
        if monitor.battery.isCharging { return "battery.100.bolt" }
        switch monitor.battery.level {
        case 81...: return "battery.100"
        case 51...80: return "battery.75"
        case 26...50: return "battery.50"
        case 11...25: return "battery.25"
        default: return "battery.0"
        }
    }

    // MARK: - Charts

    @ViewBuilder
    private func chart(for category: MetricCategory) -> some View {
        let tint = AppTheme.Colors.accentColor(for: category)
        switch category {
        case .cpu:
            // The one segment that carries two series: the averaged `usage` beside it describes
            // neither cluster, so the chart is where the P/E split actually shows.
            if monitor.cpu.hasCoreSplit {
                miniChart(
                    monitor.cpu.performanceHistory, tint: CPUView.performanceTint,
                    secondary: monitor.cpu.efficiencyHistory, secondaryTint: CPUView.efficiencyTint,
                    domain: 0...1
                )
            } else {
                miniChart(monitor.cpu.history, tint: tint, domain: 0...1)
            }
        case .gpu:
            miniChart(monitor.gpu.history, tint: tint, domain: 0...1)
        case .memory:
            miniChart(monitor.memory.usageHistory, tint: tint, domain: 0...1)
        case .disk:
            // The number beside this is storage used, which barely moves; charting it would draw
            // a flat line. Read/write activity is the part worth watching, in the dashboard's
            // own two tints.
            miniChart(
                monitor.disk.readHistory, tint: AppTheme.Colors.brandBlue,
                secondary: monitor.disk.writeHistory, secondaryTint: .purple
            )
        case .battery:
            miniChart(monitor.battery.levelHistory, tint: tint, domain: 0...1)
        case .network:
            miniChart(
                monitor.network.downloadHistory, tint: AppTheme.Colors.brandBlue,
                secondary: monitor.network.uploadHistory, secondaryTint: AppTheme.Colors.batteryGreen
            )
        }
    }

    private func miniChart(
        _ data: [Double],
        tint: Color,
        secondary: [Double]? = nil,
        secondaryTint: Color = AppTheme.Colors.brandBlue,
        domain: ClosedRange<Double>? = nil
    ) -> some View {
        Sparkline(
            data: Self.tail(data),
            tint: tint,
            domain: domain,
            secondary: secondary.map(Self.tail),
            secondaryTint: secondaryTint,
            height: Self.chartHeight,
            lineWidth: 1
        )
        .frame(width: Self.chartWidth)
    }

    private static func tail(_ values: [Double]) -> [Double] {
        Array(values.suffix(chartSamples))
    }
}
