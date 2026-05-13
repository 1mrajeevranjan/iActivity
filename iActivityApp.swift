import SwiftUI
import AppKit

@main
struct iActivityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var monitor = SystemMonitor()
    var panelManager: PanelManager?
    var updateTimer: Timer?
    var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelManager = PanelManager(monitor: monitor)

        // Set to background accessory mode (no Dock icon)
        AppSetup.shared.setDockIconVisibility(false)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.action = #selector(handleStatusClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])

            // Native styling for perfect alignment
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 13.5, weight: .bold)
        }

        // Update the menu bar natively every second
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMenuBarDisplay()
            }
        }
        updateMenuBarDisplay()

        // Show onboarding on first launch
        if !UserDefaults.standard.bool(forKey: "hasFinishedOnboarding") {
            showOnboarding()
        } else {
            // Check for move to applications on subsequent launches too, but quietly
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                AppSetup.shared.moveToApplicationsIfNeeded()
            }
        }
    }

    func showOnboarding() {
        if onboardingWindow == nil {
            let contentView = OnboardingView()
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.isReleasedWhenClosed = false
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.contentView = NSHostingView(rootView: contentView)
            window.backgroundColor = .clear
            window.isMovableByWindowBackground = true
            onboardingWindow = window
        }
        
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }

    func updateMenuBarDisplay() {
        guard let button = statusItem?.button else { return }

        let categoryRaw = UserDefaults.standard.string(forKey: "selectedCategory") ?? MetricCategory.cpu.rawValue
        let category = MetricCategory(rawValue: categoryRaw) ?? .cpu

        let tempStr = temperatureString(for: category)

        var usageStr = ""
        var isCritical = false
        var isWarning = false
        var iconName = category.icon

        switch category {
        case .cpu:
            let val = monitor.cpu.usage
            usageStr = "\(Int(val * 100))%"
            isCritical = val >= 0.90
            isWarning = val >= 0.70
        case .gpu:
            let val = monitor.gpu.utilization
            usageStr = "\(Int(val * 100))%"
            isCritical = val >= 0.90
            isWarning = val >= 0.70
        case .memory:
            let val = monitor.memory.usagePercentage
            usageStr = "\(Int(val * 100))%"
            isCritical = val >= 0.90
            isWarning = val >= 0.75
        case .disk:
            let val = monitor.disk.usagePercentage
            usageStr = "\(Int(val * 100))%"
            isCritical = val >= 0.95
            isWarning = val >= 0.85
        case .battery:
            let val = monitor.battery.level
            let charging = monitor.battery.isCharging
            usageStr = "\(val)%"
            isCritical = (val <= 10 && !charging)
            isWarning = (val <= 20 && !charging)
            
            if charging       { iconName = "battery.100.bolt" }
            else if val > 80  { iconName = "battery.100" }
            else if val > 50  { iconName = "battery.75"  }
            else if val > 25  { iconName = "battery.50"  }
            else if val > 10  { iconName = "battery.25"  }
            else              { iconName = "battery.0" }
            
        case .network:
            let down = formatSpeed(monitor.network.downloadSpeed)
            let up = formatSpeed(monitor.network.uploadSpeed)
            usageStr = "↓\(down) ↑\(up)"
        }

        let color: NSColor = isCritical ? .systemRed : (isWarning ? .systemOrange : .labelColor)
        let text = tempStr.isEmpty ? usageStr : "\(tempStr) \(usageStr)"
        
        button.attributedTitle = NSAttributedString(
            string: text + " ",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
                .foregroundColor: color
            ]
        )

        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            button.image = image.withSymbolConfiguration(config)
            button.imagePosition = .imageRight
        }
    }

    // MARK: - Temperature string per category

    private func temperatureString(for category: MetricCategory) -> String {
        let temp: Double
        switch category {
        case .cpu:
            temp = monitor.cpu.temperature
        case .gpu:
            temp = monitor.gpu.temperature
        case .memory:
            temp = monitor.memory.temperature
        case .disk:
            temp = monitor.disk.temperature
        case .battery:
            temp = monitor.battery.temperature
        case .network:
            return "" // No temperature sensor for network
        }
        guard temp > 0 else { return "" }
        return String(format: "%.0f°", temp)
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000 {
            return String(format: "%.1fM", bytesPerSecond / 1_000_000)
        } else if bytesPerSecond >= 1_000 {
            return String(format: "%.0fK", bytesPerSecond / 1_000)
        } else {
            return String(format: "%.0fB", bytesPerSecond)
        }
    }

    @objc func handleStatusClick() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.autoenablesItems = false

            let dashboardItem = NSMenuItem(title: "Open iActivity Dashboard", action: #selector(openDashboard), keyEquivalent: "o")
            dashboardItem.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)
            dashboardItem.target = self
            menu.addItem(dashboardItem)

            let themeItem = NSMenuItem(title: "Toggle Appearance", action: #selector(toggleTheme), keyEquivalent: "t")
            themeItem.image = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: nil)
            themeItem.target = self
            menu.addItem(themeItem)

            let setupItem = NSMenuItem(title: "Setup & Permissions...", action: #selector(openSetup), keyEquivalent: "s")
            setupItem.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil)
            setupItem.target = self
            menu.addItem(setupItem)

            menu.addItem(NSMenuItem.separator())

            let quitItem = NSMenuItem(title: "Quit iActivity", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
            menu.addItem(quitItem)

            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            
            // Match BatterySense pattern: clear menu reference so it doesn't hijack left-click
            DispatchQueue.main.async { [weak self] in
                self?.statusItem?.menu = nil
            }
        } else {
            panelManager?.toggle()
        }
    }

    @objc func openDashboard() {
        panelManager?.show()
    }

    @objc func toggleTheme() {
        let current = UserDefaults.standard.bool(forKey: "isDarkMode")
        UserDefaults.standard.set(!current, forKey: "isDarkMode")
    }

    @objc func openSetup() {
        showOnboarding()
    }
}
