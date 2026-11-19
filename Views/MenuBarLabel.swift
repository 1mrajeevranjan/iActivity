import SwiftUI

/// The menu bar strip: one segment per selected category, each `[temp] [chart] [badge]`, where the
/// badge is the category's SF Symbol with the reading drawn inside it.
///
/// This file used to be dead code — the menu bar was drawn in `AppDelegate.updateMenuBarDisplay()`
/// as an `attributedTitle` plus an SF Symbol, and nothing referenced this view. It is now the live
/// view, hosted inside the status item. That is what lets the menu bar share one chart renderer
/// with the dashboard: picking "Area" in Settings changes both surfaces, instead of every
/// `ChartStyle` having to be written a second time in Core Graphics.
struct MenuBarLabel: View {
    let monitor: SystemMonitor
    /// Fires whenever the strip's natural width changes, so the status item can be resized
    /// in the same frame instead of clipping or padding until a later sync.
    var onWidthChange: () -> Void = {}

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
        // No outer padding: macOS already adds 8pt either side of a fixed-length status item —
        // the same margin a native image item gets — so any padding here makes ours look loose.
        // Segments sit 16pt apart, the glyph-to-glyph gap between two separate system items.
        HStack(spacing: 16) {
            ForEach(categories) { category in
                segment(for: category)
            }
        }
        .fixedSize()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { _ in onWidthChange() }
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

            if showGraph {
                chart(for: category)
            }

            if let shape = MenuBarBadge.Shape(category) {
                MenuBarBadge(shape: shape, value: "\(percentage(for: category))", status: status(for: category))
                if category == .battery && monitor.battery.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .bold))
                }
            } else {
                networkLabel
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(category.displayName))
        .accessibilityValue(Text(valueText(for: category)))
    }

    // MARK: - Readings

    private func percentage(for category: MetricCategory) -> Int {
        switch category {
        case .cpu: return Int(monitor.cpu.usage * 100)
        case .gpu: return Int(monitor.gpu.utilization * 100)
        case .memory: return Int(monitor.memory.usagePercentage * 100)
        case .disk: return Int(monitor.disk.usagePercentage * 100)
        case .battery: return monitor.battery.level
        case .network: return 0 // No ceiling to be a percentage of.
        }
    }

    private func valueText(for category: MetricCategory) -> String {
        guard category == .network else { return "\(percentage(for: category))%" }
        return "↓\(Self.compactSpeed(monitor.network.downloadSpeed)) ↑\(Self.compactSpeed(monitor.network.uploadSpeed))"
    }

    /// Two readings never fit inside one glyph, so network stacks them beside a solid transfer
    /// glyph: one icon-height slot rather than a single long line. Each line reserves "↓999 Mb" —
    /// `compactSpeed` never goes wider below 10 Gb/s — so the strip does not shift as speeds tick over.
    private var networkLabel: some View {
        HStack(spacing: 3) {
            // `network` has no filled variant; this is the solid glyph that matches the badges.
            Image(systemName: "arrow.up.arrow.down.circle.fill")
                .font(.system(size: 17))
            ZStack(alignment: .leading) {
                Text("↓999 Mb").hidden()
                // Tight leading: digits have no descenders, and two 10pt lines must share 22pt.
                VStack(alignment: .leading, spacing: -3) {
                    Text("↓\(Self.compactSpeed(monitor.network.downloadSpeed))")
                    Text("↑\(Self.compactSpeed(monitor.network.uploadSpeed))")
                }
            }
            .font(.system(size: 10, weight: .semibold).monospacedDigit())
        }
    }

    /// The menu bar's own formatter, always in megabits per second — the unit ISPs quote, so a
    /// 100 Mb plan reads ~100 at full speed. Deliberately not the dashboard's "42.1 MB/s".
    /// One decimal below 10 ("0.0 Mb", "4.2 Mb"), whole numbers above ("42 Mb"), and gigabits
    /// from 1000; thresholds sit at the rounding points so 999.6 Mb/s reads "1.0 Gb", not "1000 Mb".
    static func compactSpeed(_ bytesPerSecond: Double) -> String {
        let megabits = bytesPerSecond * 8 / 1_000_000
        if megabits >= 999.5 { return String(format: "%.1f Gb", megabits / 1_000) }
        if megabits >= 9.95 { return String(format: "%.0f Mb", megabits) }
        return String(format: "%.1f Mb", megabits)
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

/// A reading drawn inside a solid SF Symbol, the way macOS 26 draws battery percentage inside the
/// battery glyph: one icon-sized item instead of a number plus an icon beside it.
///
/// The glyph is filled and the digits are drawn in the inverse colour — black on a white glyph in a
/// dark menu bar, white on black in a light one — which stays legible where outlined glyphs with
/// tinted digits did not. Every badge uses the same 12pt digits; each symbol gets its own point size
/// so the solid bodies come out visually equal (the CPU's pins make its body smallest at any given
/// size). Rects are measured at 17pt from the alpha mask of the glyph as SwiftUI renders it, then
/// scaled — NSImage draws the same symbols up to 1.5pt larger, so measure through ImageRenderer if
/// these ever change.
struct MenuBarBadge: View {
    struct Shape {
        let symbol: String
        let size: CGFloat
        /// Detail inside the glyph (the CPU die, the display's tinted screen, the drive's grille)
        /// painted over in the glyph's own colour so the digits sit on a solid surface.
        let cover: CGRect?
        /// Where the digits go, in points from the top-left of the glyph's frame.
        let digits: CGRect

        /// Nil for network: it has two readings and no symbol that holds both.
        init?(_ category: MetricCategory) {
            let size: CGFloat, cover: CGRect?, digits: CGRect
            switch category {
            case .cpu:
                // 18pt is the largest whose layout frame (22pt) fits the 22pt status button.
                (symbol, size) = ("cpu.fill", 18)
                cover = CGRect(x: 5, y: 4.5, width: 10.5, height: 10.5)
                digits = CGRect(x: 4, y: 3.5, width: 13, height: 12.5)
            case .gpu:
                (symbol, size) = ("display", 17)
                cover = CGRect(x: 3.25, y: 2.75, width: 17.5, height: 11.5)
                digits = CGRect(x: 2.5, y: 2, width: 19, height: 13)
            case .memory:
                (symbol, size) = ("memorychip.fill", 18)
                cover = nil
                digits = CGRect(x: 2.5, y: 3.5, width: 17.5, height: 10.5)
            case .disk:
                (symbol, size) = ("internaldrive.fill", 17.5)
                cover = CGRect(x: 3.5, y: 7.5, width: 16.5, height: 6.5)
                // Centred low, on the drive's wide base: the trapezoid above narrows too fast.
                digits = CGRect(x: 4, y: 4, width: 15.5, height: 11)
            case .battery:
                // 18pt matches the system battery item's 31 × 15.
                (symbol, size) = ("battery.100percent", 18)
                cover = nil
                digits = CGRect(x: 2.5, y: 2, width: 21, height: 10.5)
            case .network:
                return nil
            }
            let scale = CGAffineTransform(scaleX: size / 17, y: size / 17)
            self.size = size
            self.cover = cover?.applying(scale)
            self.digits = digits.applying(scale)
        }
    }

    static let digitSize: CGFloat = 12

    let shape: Shape
    let value: String
    let status: MenuBarStatus

    var body: some View {
        // Warning and critical recolour the whole glyph, like the system's yellow low-power
        // battery, rather than tinting digits too small to carry colour on their own.
        let fill: Color = status == .normal ? .primary : status.color
        let digitColor: Color = status == .normal ? Color(nsColor: .textBackgroundColor) : .black
        let digits = shape.digits

        // The menu bar's `.primary` is translucent, so painting the cover over the glyph in it
        // would double up where they overlap. Instead the glyph and cover form an opaque mask
        // and the colour is laid down once.
        silhouette
            .hidden()
            .overlay { Rectangle().fill(fill).mask { silhouette } }
            .overlay {
                // Condensed bold, like the system battery's digits; compressed only when "100"
                // would not otherwise fit (the CPU die and the drive).
                ViewThatFits(in: .horizontal) {
                    Text(value).font(.system(size: Self.digitSize, weight: .bold).width(.condensed))
                    Text(value)
                        .font(.system(size: Self.digitSize, weight: .bold).width(.compressed))
                        .minimumScaleFactor(0.8)
                }
                .lineLimit(1)
                .foregroundStyle(digitColor)
                .frame(width: digits.width, height: 16)
                .position(x: digits.midX, y: digits.midY)
            }
    }

    private var silhouette: some View {
        Image(systemName: shape.symbol)
            .font(.system(size: shape.size))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(.black)
            .overlay {
                if let cover = shape.cover {
                    RoundedRectangle(cornerRadius: 1)
                        .frame(width: cover.width, height: cover.height)
                        .position(x: cover.midX, y: cover.midY)
                }
            }
    }
}
