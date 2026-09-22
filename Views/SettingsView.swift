import SwiftUI

struct SettingsView: View {
    @Environment(SystemMonitor.self) private var monitor

    @State private var launchAtLogin = AppSetup.shared.isLaunchAtLoginEnabled
    @AppStorage("showInDock") private var showInDock: Bool = false
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .dark
    @AppStorage("temperatureUnit") private var temperatureUnit: TemperatureUnit = .celsius
    @AppStorage("selectedCategory") private var dashboardCategory: MetricCategory = .cpu
    @AppStorage(MenuBarSelection.storageKey) private var storedSelection = MenuBarSelection([])
    @AppStorage("chartStyle") private var chartStyle: ChartStyle = .line
    @AppStorage("showMenuBarGraph") private var showMenuBarGraph: Bool = true
    @AppStorage("updateInterval") private var updateInterval: Double = RefreshInterval.normal.rawValue
    @AppStorage("showTemperature") private var showTemperature: Bool = true

    /// Migration and the empty-selection fallback live in `MenuBarSelection.resolved`, so this
    /// screen and the menu bar cannot disagree about what is selected.
    private var selection: MenuBarSelection {
        MenuBarSelection.resolved(rawValue: storedSelection.rawValue, fallback: dashboardCategory)
    }

    private func isOnlySelection(_ category: MetricCategory) -> Bool {
        selection.categories == [category]
    }

    private func binding(for category: MetricCategory) -> Binding<Bool> {
        Binding(
            get: { selection.categories.contains(category) },
            set: { isOn in
                var next = Set(selection.categories)
                if isOn { next.insert(category) } else { next.remove(category) }
                guard !next.isEmpty else { return }
                storedSelection = MenuBarSelection(Array(next))
                // A newly ticked category would otherwise show a frozen reading until the
                // dashboard was next opened, because its monitor is still paused.
                monitor.menuBarSelectionChanged()
            }
        )
    }

    // The "Settings" title is drawn via an NSTitlebarAccessoryViewController in AppDelegate, not
    // here — it needs to composite inside the actual titlebar band, which SwiftUI content hosted
    // as the window's contentView cannot reliably reach into.
    var body: some View {
        Form {
            Section {
                SubtitleToggle(
                    title: "Launch at Login",
                    subtitle: "Start iActivity automatically after you sign in.",
                    isOn: $launchAtLogin
                )
                .onChange(of: launchAtLogin) { _, newValue in
                    AppSetup.shared.isLaunchAtLoginEnabled = newValue
                }

                SubtitleToggle(
                    title: "Show Dock Icon",
                    subtitle: "iActivity normally lives only in the menu bar.",
                    isOn: $showInDock
                )
                .onChange(of: showInDock) { _, newValue in
                    AppSetup.shared.setDockIconVisibility(newValue)
                }
            } header: {
                Text("General")
            }

            Section {
                Picker("Appearance", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Temperature Unit", selection: $temperatureUnit) {
                    ForEach(TemperatureUnit.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Chart Style", selection: $chartStyle) {
                    ForEach(ChartStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Display")
            } footer: {
                Text("The chart style applies to the dashboard and the menu bar together.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                // `displayName`, not the all-caps `title` — these are prose, and VoiceOver
                // spells "MEMORY" out when it is shouted at it.
                ForEach(MetricCategory.allCases) { category in
                    Toggle(category.displayName, isOn: binding(for: category))
                        // Switching the last one off would collapse the status item to zero
                        // width, leaving nothing to click to turn one back on.
                        .disabled(isOnlySelection(category))
                }

                SubtitleToggle(
                    title: "Show Temperature",
                    subtitle: "Display the sensor reading beside each menu bar value.",
                    isOn: $showTemperature
                )

                SubtitleToggle(
                    title: "Show Graph",
                    subtitle: "Draw each category's recent history beside its reading.",
                    isOn: $showMenuBarGraph
                )
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("Every category shown here keeps its monitor running while the dashboard is closed, so fewer of them use less power.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Update Every", selection: $updateInterval) {
                    ForEach(RefreshInterval.allCases) { rate in
                        Text(rate.title).tag(rate.rawValue)
                    }
                }
                .onChange(of: updateInterval) { _, newValue in
                    monitor.applyInterval(newValue)
                }
            } header: {
                Text("Monitoring")
            } footer: {
                Text("A slower interval uses less power. Categories the menu bar does not show pause entirely while the dashboard is closed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                // Standard bordered button with a destructive role — the previous `.plain` style
                // with a hand-applied red fill matched nothing else in macOS and lost its pressed
                // and disabled states.
                HStack {
                    Spacer()
                    Button("Quit iActivity", role: .destructive) {
                        NSApplication.shared.terminate(nil)
                    }
                    .controlSize(.large)
                    // Kept: an LSUIElement app has no app menu of its own, so this button is the
                    // only place ⌘Q can be bound while the Settings window is key.
                    .keyboardShortcut("q", modifiers: .command)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 540)
        .preferredColorScheme(appearanceMode.colorScheme)
        // Esc-to-close is handled by a local NSEvent monitor in AppDelegate.showSettings() —
        // `.onExitCommand` never fired here, apparently swallowed by Form before it could see Esc.
    }
}

#Preview {
    SettingsView()
        .environment(SystemMonitor())
}
