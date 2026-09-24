import SwiftUI
import AppKit

/// Horizontal distance from the card's centre to the menu bar icon it dropped from.
/// Non-zero only when the panel had to be clamped against a screen edge — the beak
/// slides across so it keeps pointing at the icon.
@MainActor
@Observable
final class PanelAnchor {
    var beakOffsetX: CGFloat = 0

    /// Screen-derived ceiling for the popover's total height, set by `PanelManager` on every
    /// open. Content taller than this scrolls instead of running off the display.
    var maxCardHeight: CGFloat = 0

    /// Reported by `MainDashboardView` once its content lays out, so the panel can grow or
    /// shrink to fit whatever the current tab actually has to show. Same bridge role as
    /// `beakOffsetX` — this object is the one thing both SwiftUI and `PanelManager` hold.
    var onContentHeightChange: ((CGFloat) -> Void)?
}

@MainActor
class PanelManager: ObservableObject {
    private var panel: NSPanel?
    private let monitor: SystemMonitor
    private let anchor = PanelAnchor()
    private weak var statusItem: NSStatusItem?
    private var outsideClickMonitor: Any?
    private var escKeyMonitor: Any?

    init(monitor: SystemMonitor, statusItem: NSStatusItem?) {
        self.monitor = monitor
        self.statusItem = statusItem
    }

    func toggle() {
        if let panel, panel.isVisible {
            close()
        } else {
            show()
        }
    }

    func close() {
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        // Closed: only the menu bar's own category still needs live data. The other five
        // monitors and the full-system process scan have nothing left to feed.
        monitor.pauseBackground()
        removeDismissMonitors()
    }

    func show() {
        let panel = self.panel ?? createPanel()
        // Every tab (and its process list) is reachable once the panel is open.
        monitor.resumeAll()
        // Re-anchor on every open: the icon moves as neighbouring menu extras come and go.
        positionUnderStatusItem(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installDismissMonitors()
    }

    /// Matches native menu extras (Calendar, Control Center): the panel closes on Esc or on
    /// any click outside it. Neither comes for free on a borderless NSPanel — only genuine
    /// NSPopovers get that automatically — so both are wired up manually here, and torn down
    /// on close since a leaked global monitor would keep firing (and leak) after the panel
    /// stops existing.
    private func installDismissMonitors() {
        removeDismissMonitors()

        escKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let panel = self.panel, panel.isVisible else { return event }

            if event.keyCode == 53 {  // Esc
                self.close()
                return nil
            }

            if let category = Self.categoryForKey(event) {
                NotificationCenter.default.post(name: .selectMetricCategory, object: category.rawValue)
                return nil
            }

            return event
        }

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.panel, panel.isVisible else { return }
            // A click on the status item button itself is already handled by its own
            // action — closing here first would make that click immediately reopen the
            // panel instead of just toggling it shut.
            if let buttonWindow = self.statusItem?.button?.window, buttonWindow.frame.contains(NSEvent.mouseLocation) {
                return
            }
            self.close()
        }
    }

    /// ← / → step through the categories, ⌘1–⌘6 jump straight to one. Up/Down are deliberately
    /// left alone so they still scroll the pane (HIG § 5.7). This has to be decoded by hand:
    /// SwiftUI's `.keyboardShortcut` needs the key window's command chain, which a borderless
    /// panel hosting an `NSHostingView` never gets.
    private static func categoryForKey(_ event: NSEvent) -> MetricCategory? {
        let currentRaw = UserDefaults.standard.string(forKey: "selectedCategory") ?? MetricCategory.cpu.rawValue
        let current = MetricCategory(rawValue: currentRaw) ?? .cpu

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags == .command {
            guard let digit = Int(event.charactersIgnoringModifiers ?? "") else { return nil }
            return MetricCategory.at(oneBasedIndex: digit)
        }

        guard flags.isEmpty else { return nil }
        switch event.keyCode {
        case 123: return .stepping(from: current, by: -1)  // left arrow
        case 124: return .stepping(from: current, by: 1)   // right arrow
        default: return nil
        }
    }

    private func removeDismissMonitors() {
        if let escKeyMonitor { NSEvent.removeMonitor(escKeyMonitor) }
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        escKeyMonitor = nil
        outsideClickMonitor = nil
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

        anchor.onContentHeightChange = { [weak self, weak newPanel] height in
            guard let self, let panel = newPanel else { return }
            self.resizeToFitContent(panel, contentHeight: height)
        }

        return newPanel
    }

    /// Grows or shrinks the panel to the current tab's actual content height, keeping the top
    /// edge (and the beak) fixed under the menu bar icon — only the bottom moves.
    /// `MainDashboardView` already clamps what it reports to `anchor.maxCardHeight`, so this
    /// never has to fit anything taller than the screen.
    private func resizeToFitContent(_ panel: NSPanel, contentHeight: CGFloat) {
        let newHeight = contentHeight + AppTheme.Panel.topGutter + AppTheme.Panel.shadowMargin
        var frame = panel.frame
        guard abs(frame.height - newHeight) > 0.5 else { return }

        frame.origin.y += frame.height - newHeight
        frame.size.height = newHeight
        let animate = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.setFrame(frame, display: true, animate: animate)
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

        anchor.maxCardHeight = screen.visibleFrame.height
            - AppTheme.Panel.topGutter - AppTheme.Panel.shadowMargin - AppTheme.Panel.screenEdgeMargin * 2

        anchor.beakOffsetX = PanelPlacement.beakOffset(
            iconFrame: iconFrame,
            panelOriginX: origin.x,
            panelWidth: size.width,
            maxOffset: AppTheme.Panel.maxBeakOffset
        )
    }
}
