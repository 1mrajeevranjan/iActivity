import SwiftUI
import AppKit

/// Horizontal distance from the card's centre to the menu bar icon it dropped from.
/// Non-zero only when the panel had to be clamped against a screen edge — the beak
/// slides across so it keeps pointing at the icon.
@MainActor
@Observable
final class PanelAnchor {
    var beakOffsetX: CGFloat = 0
}

@MainActor
class PanelManager: ObservableObject {
    private var panel: NSPanel?
    private let monitor: SystemMonitor
    private let anchor = PanelAnchor()
    private weak var statusItem: NSStatusItem?

    init(monitor: SystemMonitor, statusItem: NSStatusItem?) {
        self.monitor = monitor
        self.statusItem = statusItem
    }

    func toggle() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            // Closed: only the menu bar's own category still needs live data. The other five
            // monitors and the full-system process scan have nothing left to feed.
            monitor.pauseBackground()
        } else {
            show()
        }
    }

    func show() {
        let panel = self.panel ?? createPanel()
        // Every tab (and its process list) is reachable once the panel is open.
        monitor.resumeAll()
        // Re-anchor on every open: the icon moves as neighbouring menu extras come and go.
        positionUnderStatusItem(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @discardableResult
    private func createPanel() -> NSPanel {
        let contentView = MainDashboardView()
            .environment(monitor)
            .environment(anchor)

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: AppTheme.Panel.windowWidth, height: AppTheme.Panel.windowHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        newPanel.level = .floating
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        // The card draws its own shadow inside the window; the system shadow would trace the
        // full rectangular frame instead of the rounded card.
        newPanel.hasShadow = false
        newPanel.hidesOnDeactivate = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Anchored to the menu bar icon like a native menu extra — dragging it away would
        // leave the beak pointing at nothing.
        newPanel.isMovableByWindowBackground = false
        newPanel.contentView = NSHostingView(rootView: contentView)

        self.panel = newPanel
        return newPanel
    }

    /// Centres the card under the menu bar icon, clamped to the screen, and reports how far
    /// the beak must slide to stay aimed at the icon.
    private func positionUnderStatusItem(_ panel: NSPanel) {
        guard let iconFrame = statusItem?.button?.window?.frame,
              let screen = statusItem?.button?.window?.screen ?? NSScreen.main else {
            panel.center()
            anchor.beakOffsetX = 0
            return
        }

        let size = panel.frame.size
        let origin = PanelPlacement.origin(
            iconFrame: iconFrame,
            panelSize: size,
            visibleScreenFrame: screen.visibleFrame,
            edgeMargin: AppTheme.Panel.screenEdgeMargin
        )
        panel.setFrameOrigin(origin)

        anchor.beakOffsetX = PanelPlacement.beakOffset(
            iconFrame: iconFrame,
            panelOriginX: origin.x,
            panelWidth: size.width,
            maxOffset: AppTheme.Panel.maxBeakOffset
        )
    }
}
