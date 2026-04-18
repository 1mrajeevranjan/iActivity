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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        panelManager = PanelManager(monitor: monitor)
        
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
    }
    
    func updateMenuBarDisplay() {
        guard let button = statusItem?.button else { return }
        
        let categoryRaw = UserDefaults.standard.string(forKey: "selectedCategory") ?? MetricCategory.cpu.rawValue
        let category = MetricCategory(rawValue: categoryRaw) ?? .cpu
        
        // Setup Icon
        let config = NSImage.SymbolConfiguration(pointSize: 13.5, weight: .bold)
        if let image = NSImage(systemSymbolName: category.icon, accessibilityDescription: nil) {
            button.image = image.withSymbolConfiguration(config)
            button.imagePosition = .imageLeft
        }
        
        // Setup Text
        var text = ""
        switch category {
        case .cpu:
            text = "\(Int(monitor.cpu.usage * 100))%"
        case .gpu:
            text = "\(Int(monitor.gpu.utilization * 100))%"
        case .memory:
            text = "\(Int(monitor.memory.usagePercentage * 100))%"
        case .disk:
            text = "\(Int(monitor.disk.usagePercentage * 100))%"
        case .battery:
            text = "\(monitor.battery.level)%"
        case .network:
            let down = formatSpeed(monitor.network.downloadSpeed)
            let up = formatSpeed(monitor.network.uploadSpeed)
            text = "↓\(down) ↑\(up)"
        }
        
        button.title = text
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
            
            let themeItem = NSMenuItem(title: "Toggle Appearance", action: #selector(toggleTheme), keyEquivalent: "t")
            menu.addItem(themeItem)
            
            menu.addItem(NSMenuItem.separator())
            
            menu.addItem(NSMenuItem(title: "Quit iActivity", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            panelManager?.toggle()
        }
    }
    
    @objc func toggleTheme() {
        let current = UserDefaults.standard.bool(forKey: "isDarkMode")
        UserDefaults.standard.set(!current, forKey: "isDarkMode")
    }
}
