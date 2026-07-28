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
        } else {
            show()
        }
    }

    func show() {
        let panel = self.panel ?? createPanel()
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
        let visible = screen.visibleFrame

        let idealX = iconFrame.midX - size.width / 2
        let minX = visible.minX + AppTheme.Panel.screenEdgeMargin
        let maxX = visible.maxX - AppTheme.Panel.screenEdgeMargin - size.width
        let originX = maxX >= minX ? min(max(idealX, minX), maxX) : idealX

        // Sit the window's top edge flush with the bottom of the menu bar. AppKit clamps windows to
        // the visible frame anyway, so asking for anything higher is silently overridden — the beak
        // then hangs `topGutter` below the menu bar, which is the gap the user sees.
        let originY = iconFrame.minY - size.height

        panel.setFrameOrigin(NSPoint(x: originX, y: originY))

        let limit = AppTheme.Panel.maxBeakOffset
        anchor.beakOffsetX = min(max(iconFrame.midX - (originX + size.width / 2), -limit), limit)
    }
}
