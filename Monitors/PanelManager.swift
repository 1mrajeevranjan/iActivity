import SwiftUI
import AppKit

@MainActor
class PanelManager: ObservableObject {
    private var panel: NSPanel?
    private let monitor: SystemMonitor
    
    init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    func toggle() {
        if let panel = panel {
            if panel.isVisible {
                panel.orderOut(nil)
            } else {
                show()
            }
        } else {
            createPanel()
        }
    }

    func show() {
        if let panel = panel {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            createPanel()
        }
    }
    
    private func createPanel() {
        let contentView = MainDashboardView()
            .environment(monitor)
        
        let hostingView = NSHostingView(rootView: contentView)
        
        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 580),
            styleMask: [.nonactivatingPanel, .resizable, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        
        newPanel.isMovableByWindowBackground = true
        newPanel.level = .floating
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = true // Let macOS handle perfect corner-hugging shadows
        newPanel.hidesOnDeactivate = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        newPanel.contentView = hostingView
        newPanel.center() // Initial position
        
        self.panel = newPanel
        newPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
