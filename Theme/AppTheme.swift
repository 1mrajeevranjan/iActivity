import SwiftUI

enum AppTheme {
    /// Layered surfaces. The panel is the ground, a card sits on it, a tile sits inside a card.
    /// Each step is expressed as alpha over the appearance's own base rather than a fixed colour,
    /// so all three layers stay correctly ordered in Light, Dark and System.
    enum Colors {
        static let background = Color(nsColor: .windowBackgroundColor)

        /// Card on the panel: a white card on the light grey ground (System Settings convention),
        /// a lifted plane on the dark ground.
        static let card = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.055)
                : NSColor.white
        })

        /// Tile inside a card — one more step in the same direction.
        static let tile = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.06)
                : NSColor.black.withAlphaComponent(0.04)
        })

        /// Unfilled part of a progress bar.
        static let track = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.11)
                : NSColor.black.withAlphaComponent(0.09)
        })

        /// Hairline that survives Increase Contrast — `separatorColor` is deliberately faint and
        /// all but disappears once the user asks for more contrast.
        static func hairline(_ contrast: ColorSchemeContrast) -> Color {
            contrast == .increased ? Color.primary.opacity(0.45) : Color(nsColor: .separatorColor)
        }

        // Category hues. System colours, not literals: each is a distinct identity for a data
        // series (legitimate semantic use, not decoration) and the system variants shift correctly
        // in Dark Mode and under Increase Contrast.
        static let batteryGreen = Color.green
        static let brandBlue = Color.blue

        static func accentColor(for category: MetricCategory) -> Color {
            switch category {
            case .cpu: return brandBlue
            case .gpu: return .cyan
            case .memory: return batteryGreen
            case .disk: return .orange
            case .battery: return batteryGreen
            case .network: return .teal
            }
        }
    }

    /// Compact metrics. Everything here is sized for a menu-bar panel read at arm's length —
    /// dense enough to show a whole category without scrolling, never so small it strains.
    enum Metrics {
        static let cardRadius: CGFloat = 12
        static let tileRadius: CGFloat = 8
        static let chipRadius: CGFloat = 8

        static let cardPadding: CGFloat = 12
        /// Gap between the card's stacked groups (tiles → usage → processes).
        static let groupSpacing: CGFloat = 12
        /// Gap between rows inside one group.
        static let rowSpacing: CGFloat = 8

        static let barHeight: CGFloat = 6
        static let sparklineHeight: CGFloat = 34
        static let tileHeight: CGFloat = 46
        static let tabHeight: CGFloat = 38
        static let footerHeight: CGFloat = 30
        static let iconColumn: CGFloat = 16
    }

    enum Spacing {
        static let tiny: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }

    /// Geometry shared between the SwiftUI dashboard and the AppKit panel that hosts it.
    /// The window is deliberately larger than the visible card so the card's shadow can fade
    /// out inside the window — a shadow that reaches the window edge gets clipped there and
    /// reads as a hard rectangular outline around the popover.
    enum Panel {
        static let cardWidth: CGFloat = 340
        static let cardHeight: CGFloat = 640
        static let cornerRadius: CGFloat = 18

        /// Transparent gutter on the sides and bottom that gives the shadow room to fade.
        static let shadowMargin: CGFloat = 20

        /// Gutter above the beak's tip. AppKit clamps a window's top to the menu bar, so the window
        /// top ends up flush with it and this doubles as the gap between the menu bar and the beak.
        static let topGutter: CGFloat = 2

        /// Width of the beak's base where it meets the card.
        static let beakWidth: CGFloat = 22
        /// How far the beak rises above the card's top edge.
        static let beakRise: CGFloat = 10

        static var topInset: CGFloat { topGutter + beakRise }
        static var windowWidth: CGFloat { cardWidth + shadowMargin * 2 }
        static var windowHeight: CGFloat { cardHeight + topInset + shadowMargin }

        static let screenEdgeMargin: CGFloat = 8

        /// Furthest the beak may slide from centre before it would collide with a rounded corner.
        static var maxBeakOffset: CGFloat { cardWidth / 2 - cornerRadius - beakWidth / 2 }
    }
}

enum MetricCategory: String, CaseIterable, Identifiable {
    case cpu, gpu, memory, disk, battery, network
    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .gpu: return "square.grid.3x3.fill"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .battery: return "bolt.fill"
        case .network: return "globe"
        }
    }

    /// All-caps form, for the eyebrow label above the card.
    var title: String {
        self.rawValue.uppercased()
    }

    /// Sentence-case name for anything a person reads as prose: VoiceOver, menus, Settings.
    /// Never expose `title` or `shortTitle` to VoiceOver — it spells "MEM" and "BAT" out letter
    /// by letter.
    var displayName: String {
        switch self {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .memory: return "Memory"
        case .disk: return "Disk"
        case .battery: return "Battery"
        case .network: return "Network"
        }
    }

    var shortTitle: String {
        switch self {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .memory: return "MEM"
        case .disk: return "DISK"
        case .battery: return "BAT"
        case .network: return "NET"
        }
    }
}

extension MetricCategory {
    /// Tab order arithmetic for the dashboard's keyboard navigation, kept out of the event
    /// handler so it can be tested without fabricating an `NSEvent`.

    /// Steps `delta` places along `allCases`, wrapping at both ends — ← from the first tab lands
    /// on the last, → from the last lands on the first.
    static func stepping(from current: MetricCategory, by delta: Int) -> MetricCategory {
        let all = allCases
        guard let index = all.firstIndex(of: current) else { return current }
        let count = all.count
        let next = ((index + delta) % count + count) % count
        return all[next]
    }

    /// The category ⌘N selects, or nil if there is no Nth tab.
    static func at(oneBasedIndex index: Int) -> MetricCategory? {
        guard allCases.indices.contains(index - 1) else { return nil }
        return allCases[index - 1]
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    // `auto` keeps its raw value so existing preferences survive; only the label reads "System".
    case light, dark, auto
    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "System"
        }
    }

    /// nil means "follow the system appearance."
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .auto: return nil
        }
    }
}

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius, fahrenheit
    var id: String { rawValue }

    var title: String {
        switch self {
        case .celsius: return "Celsius"
        case .fahrenheit: return "Fahrenheit"
        }
    }

    var shortTitle: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }

    func string(fromCelsius celsius: Double, decimals: Int = 1) -> String {
        let value = self == .celsius ? celsius : celsius * 9 / 5 + 32
        return String(format: "%.\(decimals)f%@", value, shortTitle)
    }
}

enum RefreshInterval: Double, CaseIterable, Identifiable {
    case fast = 1.0
    case normal = 2.0
    case slow = 5.0
    var id: Double { rawValue }

    var title: String {
        switch self {
        case .fast: return "1s"
        case .normal: return "2s"
        case .slow: return "5s"
        }
    }
}

/// Shape of the history charts. `line` is the default and reproduces the original sparkline
/// exactly, so an existing install's dashboard is unchanged until the user opts into another.
enum ChartStyle: String, CaseIterable, Identifiable {
    case line, area, bars, stepped
    var id: String { rawValue }

    var title: String {
        switch self {
        case .line: return "Line"
        case .area: return "Area"
        case .bars: return "Bars"
        case .stepped: return "Stepped"
        }
    }
}

/// The categories the menu bar shows, in canonical tab order.
///
/// `@AppStorage` cannot persist a `Set`, so this is a `RawRepresentable` over a comma-joined
/// list of `MetricCategory` raw values. The order is normalised to `allCases` rather than kept
/// in the order the user ticked them, so the strip never reshuffles itself between launches.
struct MenuBarSelection: RawRepresentable, Equatable, Sendable {
    let categories: [MetricCategory]

    /// Normalising through `allCases` de-duplicates and fixes the order in one pass.
    init(_ categories: [MetricCategory]) {
        self.categories = MetricCategory.allCases.filter(categories.contains)
    }

    /// Never fails: an unrecognised token is dropped rather than discarding the whole
    /// selection, so a raw value written by a future version degrades instead of resetting.
    init?(rawValue: String) {
        self.init(rawValue.split(separator: ",").compactMap { MetricCategory(rawValue: String($0)) })
    }

    var rawValue: String { categories.map(\.rawValue).joined(separator: ",") }

    static let storageKey = "menuBarCategories"

    /// The single place the migration and the empty-set fallback live. `SystemMonitor` reads
    /// `UserDefaults` directly while the views use `@AppStorage`; if each applied these rules
    /// separately they would drift, and the menu bar would disagree with which monitors run.
    ///
    /// A missing key seeds from the dashboard category, so an install that predates this
    /// setting looks identical after upgrade. An empty selection falls back for the same
    /// reason a zero-width status item is unacceptable: it cannot be clicked to get it back.
    static func resolved(rawValue: String?, fallback: MetricCategory) -> MenuBarSelection {
        if let rawValue, let stored = MenuBarSelection(rawValue: rawValue), !stored.categories.isEmpty {
            return stored
        }
        return MenuBarSelection([fallback])
    }

    static var current: MenuBarSelection {
        let defaults = UserDefaults.standard
        let dashboardRaw = defaults.string(forKey: "selectedCategory") ?? MetricCategory.cpu.rawValue
        let dashboard = MetricCategory(rawValue: dashboardRaw) ?? .cpu
        return resolved(rawValue: defaults.string(forKey: storageKey), fallback: dashboard)
    }
}

/// How a menu bar reading should be coloured. Extracted from the old `updateMenuBarDisplay`
/// so the per-category thresholds can be tested without standing up a status bar.
enum MenuBarStatus {
    case normal, warning, critical

    /// `value` is a 0...1 fraction for every category — battery included, as `level / 100`.
    static func level(for category: MetricCategory, value: Double, isCharging: Bool) -> MenuBarStatus {
        switch category {
        case .cpu, .gpu:
            if value >= 0.90 { return .critical }
            if value >= 0.70 { return .warning }
        case .memory:
            if value >= 0.90 { return .critical }
            if value >= 0.75 { return .warning }
        case .disk:
            if value >= 0.95 { return .critical }
            if value >= 0.85 { return .warning }
        case .battery:
            // Inverted — low is bad — and a machine on the charger is not in trouble.
            guard !isCharging else { return .normal }
            if value <= 0.10 { return .critical }
            if value <= 0.20 { return .warning }
        case .network:
            // Throughput has no ceiling to be a percentage of, so there is nothing to alarm on.
            return .normal
        }
        return .normal
    }

    /// `.primary` rather than `.secondary`: the dimmer tone reads as near-invisible against the
    /// menu bar's translucent, wallpaper-varying backdrop.
    var color: Color {
        switch self {
        case .normal: return .primary
        case .warning: return Color(nsColor: .systemOrange)
        case .critical: return Color(nsColor: .systemRed)
        }
    }
}
