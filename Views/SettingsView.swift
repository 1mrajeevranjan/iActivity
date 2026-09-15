import SwiftUI

struct SettingsView: View {
    @Environment(SystemMonitor.self) private var monitor

    @State private var launchAtLogin = AppSetup.shared.isLaunchAtLoginEnabled
    @AppStorage("showInDock") private var showInDock: Bool = false
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .dark
    @AppStorage("temperatureUnit") private var temperatureUnit: TemperatureUnit = .celsius
    @AppStorage("selectedCategory") private var menuBarCategory: MetricCategory = .cpu
    @AppStorage("updateInterval") private var updateInterval: Double = RefreshInterval.normal.rawValue
    @AppStorage("showTemperature") private var showTemperature: Bool = true

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
            } header: {
                Text("Display")
            }

            Section {
                Picker("Menu Bar Shows", selection: $menuBarCategory) {
                    // `displayName`, not the all-caps `title` — a menu is prose, and VoiceOver
                    // spells "MEMORY" out when it is shouted at it.
                    ForEach(MetricCategory.allCases) { category in
                        Text(category.displayName).tag(category)
                    }
                }

                SubtitleToggle(
                    title: "Show Temperature",
                    subtitle: "Display the sensor reading beside the menu bar value.",
                    isOn: $showTemperature
                )

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
                Text("A slower interval uses less power. The dashboard's other categories pause entirely while it is closed.")
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
