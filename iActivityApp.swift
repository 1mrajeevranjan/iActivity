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
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set to background accessory mode (no Dock icon)
        AppSetup.shared.setDockIconVisibility(false)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        panelManager = PanelManager(monitor: monitor, statusItem: statusItem)

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

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 540),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.isReleasedWhenClosed = false
            window.title = "Settings"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.contentView = NSHostingView(rootView: SettingsView().environment(monitor))

            // NSTitlebarAccessoryViewController is the Apple-supported way to place custom content
            // inside the titlebar band. Everything else tried here (NSToolbarItem flexible-space,
            // a SwiftUI row with ignoresSafeArea, an NSHostingView with Auto Layout constraints)
            // either landed off-center, got silently occluded, or collapsed to zero width from
            // SwiftUI's internal sizing conflicting with an externally imposed constraint.
            //
            // `.leading` docks the accessory's leading edge right after the traffic lights, not at
            // the window's true left edge — so centering *within the accessory's own box* always
            // lands right of the window's true center by roughly half the traffic-light zone's
            // width. AppKit only reports that zone's width once the accessory is actually inserted
            // (attempts to read window.contentLayoutGuide etc. beforehand were unreliable), so this
            // measures it after insertion and repositions the label to compensate.
            let titleAccessory = NSTitlebarAccessoryViewController()
            let titleLabel = NSTextField(labelWithString: "Settings")
            titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
            titleLabel.sizeToFit()
            // Must have an explicit non-zero frame *before* insertion — AppKit sizes/positions the
            // accessory from the view's own frame at that point, and a bare NSView() defaults to
            // .zero with no intrinsic size to fall back on, which is why the first attempt at this
            // container produced a permanently zero-width, zero-origin box.
            let containerView = NSView(frame: NSRect(x: 0, y: 0, width: window.frame.width, height: 22))
            containerView.addSubview(titleLabel)
            titleAccessory.view = containerView
            titleAccessory.layoutAttribute = .leading
            window.addTitlebarAccessoryViewController(titleAccessory)

            // AppKit lays out the newly inserted accessory asynchronously, under an internal
            // wrapper view whose coordinate space always starts at local (0,0) regardless of where
            // that wrapper actually sits in the titlebar — `containerView.frame.origin` reports
            // position relative to that immediate superview, not the window, so it always read 0.
            // Converting through the view hierarchy to window coordinates gives the real offset.
            DispatchQueue.main.async {
                let originInWindow = containerView.convert(NSPoint.zero, to: nil)
                let leadingInset = originInWindow.x
                containerView.frame = NSRect(x: containerView.frame.origin.x, y: containerView.frame.origin.y, width: window.frame.width - leadingInset, height: 22)
                let windowCenterInAccessorySpace = window.frame.width / 2 - leadingInset
                titleLabel.frame.origin = NSPoint(x: windowCenterInAccessorySpace - titleLabel.frame.width / 2, y: 3)
            }

            // SwiftUI's `.onExitCommand` never fired inside the Form — it appears to consume Esc
            // itself before the exit-command handler sees it. A local monitor on the window
            // reliably closes it on Esc regardless of what SwiftUI does with the key event.
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak window] event in
                guard let window, window.isKeyWindow, event.keyCode == 53 else { return event }
                window.close()
                return nil
            }

            settingsWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
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
        
        let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let finalString = NSMutableAttributedString()
        
        if !tempStr.isEmpty {
            let tempAttr = NSAttributedString(
                string: tempStr + " ",
                attributes: [
                    .font: numberFont,
                    // labelColor, not secondaryLabelColor — the dimmer secondary tone reads as
                    // near-invisible against the menu bar's translucent, wallpaper-varying backdrop.
                    .foregroundColor: NSColor.labelColor
                ]
            )
            finalString.append(tempAttr)
        }
        
        let usageAttr = NSAttributedString(
            string: usageStr + " ",
            attributes: [
                .font: numberFont,
                .foregroundColor: color
            ]
        )
        finalString.append(usageAttr)
        
        button.attributedTitle = finalString

        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            button.image = image.withSymbolConfiguration(config)
            button.imagePosition = .imageRight
        }
    }

    // MARK: - Temperature string per category

    private func temperatureString(for category: MetricCategory) -> String {
        guard UserDefaults.standard.object(forKey: "showTemperature") as? Bool ?? true else { return "" }

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
        let unit = TemperatureUnit(rawValue: UserDefaults.standard.string(forKey: "temperatureUnit") ?? "") ?? .celsius
        return unit.string(fromCelsius: temp, decimals: 0)
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

            let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
            settingsItem.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil)
            settingsItem.target = self
            menu.addItem(settingsItem)

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

    @objc func openSettings() {
        showSettings()
    }
}
