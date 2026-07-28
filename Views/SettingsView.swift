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
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        AppSetup.shared.isLaunchAtLoginEnabled = newValue
                    }

                Toggle("Show Dock Icon", isOn: $showInDock)
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
                    ForEach(MetricCategory.allCases) { category in
                        Text(category.title).tag(category)
                    }
                }

                Toggle("Show Temperature", isOn: $showTemperature)

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
            }

            Section {
                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit iActivity", systemImage: "power")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q", modifiers: .command)
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
