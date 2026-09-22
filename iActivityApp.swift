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
    /// `NSApp.delegate as? AppDelegate` returns nil under `@NSApplicationDelegateAdaptor` —
    /// SwiftUI does not leave this instance there, so every call through it is a silent no-op.
    /// Hold an explicit reference instead (design-system § 14).
    private(set) static var shared: AppDelegate?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    var statusItem: NSStatusItem?
    private var menuBarHosting: ClickThroughHostingView<MenuBarLabel>?
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

            // The readout is SwiftUI now, so the button draws no title or image of its own.
            // Hosting it here is what lets the menu bar share one chart renderer with the
            // dashboard instead of reimplementing every ChartStyle in Core Graphics.
            // Sized from its own content, deliberately NOT pinned to the button's edges.
            // Constraining it to fill the button makes `fittingSize` report the button's width,
            // which is itself whatever `statusItem.length` was last set to — a loop that
            // resolves to nothing and leaves an invisible, unclickable item in the menu bar.
            let hosting = ClickThroughHostingView(rootView: MenuBarLabel(monitor: monitor))
            hosting.translatesAutoresizingMaskIntoConstraints = true
            hosting.autoresizingMask = []
            button.addSubview(hosting)
            menuBarHosting = hosting
        }

        // SwiftUI redraws the strip's contents by itself; this only reconciles the status
        // item's width, which is AppKit state nothing updates on its behalf.
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncMenuBarWidth()
            }
        }
        syncMenuBarWidth()

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
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.isReleasedWhenClosed = false
            window.title = "Settings"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            // `sizingOptions = []` keeps the hosting view from re-sizing the window to fit its
            // content: a grouped `Form` wraps itself in a ScrollView with no definite ideal
            // height, so the chrome jumps around as sections change.
            let hosting = NSHostingView(rootView: SettingsView().environment(monitor))
            hosting.sizingOptions = []
            window.contentView = hosting

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
            let contentView = OnboardingView { [weak self] in
                self?.onboardingWindow?.close()
            }
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

    /// Keeps the status item exactly as wide as its hosted content.
    ///
    /// A stale length either clips the strip or leaves dead space beside it, and the width
    /// genuinely moves: network's `↓42.1M ↑1.2M` is several times wider than CPU's `4%`, and
    /// the whole strip grows and shrinks as categories are added in Settings.
    func syncMenuBarWidth() {
        guard let hosting = menuBarHosting, let statusItem, let button = statusItem.button else { return }

        let width = max(hosting.fittingSize.width, 1)
        if abs(statusItem.length - width) > 0.5 {
            statusItem.length = width
        }
        // `bounds` is empty until the button has been laid out at least once, and a zero-height
        // frame renders nothing at all.
        let height = button.bounds.height > 0 ? button.bounds.height : NSStatusBar.system.thickness
        hosting.frame = CGRect(x: 0, y: 0, width: width, height: height)
    }

    @objc func handleStatusClick() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            statusItem?.menu = buildStatusMenu()
            statusItem?.button?.performClick(nil)

            // Match BatterySense pattern: clear menu reference so it doesn't hijack left-click
            DispatchQueue.main.async { [weak self] in
                self?.statusItem?.menu = nil
            }
        } else {
            panelManager?.toggle()
        }
    }

    private func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Settings/Quit carry no custom symbol — macOS decorates rows using these two exact
        // actions with its own icon, and adding one doubles it (design-system § 15's Settings
        // note, same behaviour holds for Quit here).
        menu.addItem(iconMenuItem("Settings…", symbol: nil, action: #selector(openSettings), keyEquivalent: ","))

        let moreItem = NSMenuItem(title: "More", action: nil, keyEquivalent: "")
        moreItem.attributedTitle = styledMenuTitle("More", symbol: "ellipsis.circle", enabled: true)
        moreItem.submenu = buildMoreMenu()
        menu.addItem(moreItem)

        menu.addItem(.separator())
        menu.addItem(iconMenuItem("Quit iActivity", symbol: nil, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    private func buildMoreMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(iconMenuItem("About", symbol: "info.circle", action: #selector(showAbout)))
        menu.addItem(iconMenuItem("Support & Feedback", symbol: "bubble.left", action: #selector(openSupport)))

        menu.addItem(.separator())

        menu.addItem(iconMenuItem("Tips", symbol: "lightbulb", action: #selector(showTips)))
        menu.addItem(iconMenuItem("FAQ", symbol: "questionmark.circle", action: #selector(openFAQ)))
        menu.addItem(iconMenuItem("Website", symbol: "globe", action: #selector(openWebsite)))

        menu.addItem(.separator())

        // ponytail: no Mac App Store listing yet (DMG-only per README) — item stays disabled
        // until a real store link exists. Wire `openRateApp` up once there's a URL/ID to open.
        menu.addItem(iconMenuItem("Rate App", symbol: "star", action: nil))
        menu.addItem(iconMenuItem("Share App", symbol: "square.and.arrow.up", action: #selector(shareApp)))
        menu.addItem(iconMenuItem("More Apps by Me", symbol: "square.stack.3d.up", action: #selector(openMoreApps)))

        return menu
    }

    /// `NSMenuItem.image` silently fails to draw on some SDKs (design-system § 15) — the image
    /// only reliably renders when it rides inside the *title* as a text attachment, since the
    /// menu always draws titles. Every item in this menu goes through here for that reason.
    /// `symbol: nil` renders a plain title — used for the two rows macOS already decorates itself.
    private func iconMenuItem(_ title: String, symbol: String?, action: Selector?, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.isEnabled = action != nil
        item.attributedTitle = styledMenuTitle(title, symbol: symbol, enabled: item.isEnabled)
        return item
    }

    private func styledMenuTitle(_ title: String, symbol: String?, enabled: Bool) -> NSAttributedString {
        let line = NSMutableAttributedString()
        if let symbol, let symbolImage = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)) {
            let attachment = NSTextAttachment()
            attachment.image = symbolImage
            attachment.bounds = CGRect(x: 0, y: -3, width: 15, height: 15)
            line.append(NSAttributedString(attachment: attachment))
            line.append(NSAttributedString(string: "  "))
        }
        // An attributed title opts out of automatic disabled-row greying (§ 15) — apply it by
        // hand so the still-inert "Rate App" row doesn't read as a live, clickable item.
        let textColor: NSColor = enabled ? .labelColor : .disabledControlTextColor
        line.append(NSAttributedString(string: title, attributes: [.font: NSFont.menuFont(ofSize: 13), .foregroundColor: textColor]))
        return line
    }

    @objc func openSettings() {
        showSettings()
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func showTips() {
        let alert = NSAlert()
        alert.messageText = "Tips"
        alert.informativeText = """
        ← / → — switch between tabs
        ⌘1–⌘6 — jump straight to a tab
        Esc — close the dashboard
        Space, outside the panel — also closes it
        """
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func openSupport() {
        NSWorkspace.shared.open(URL(string: "https://github.com/1mrajeevranjan/iActivity/issues/new")!)
    }

    @objc private func openFAQ() {
        NSWorkspace.shared.open(URL(string: "https://github.com/1mrajeevranjan/iActivity#readme")!)
    }

    @objc private func openWebsite() {
        NSWorkspace.shared.open(URL(string: "https://github.com/1mrajeevranjan/iActivity")!)
    }

    @objc private func shareApp() {
        guard let button = statusItem?.button else { return }
        let picker = NSSharingServicePicker(items: [URL(string: "https://github.com/1mrajeevranjan/iActivity")!])
        picker.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    @objc private func openMoreApps() {
        // ponytail: no App Store developer page yet — points at the GitHub profile instead.
        // Swap for the real "see all developer apps" link once one exists.
        NSWorkspace.shared.open(URL(string: "https://github.com/1mrajeevranjan")!)
    }
}

/// Hosts the menu bar strip without ever becoming the click target.
///
/// `NSStatusBarButton` is what opens the panel on a left click and the menu on a right click.
/// A subview that answered hit tests would swallow both, so this one declines them and every
/// click lands on the button underneath.
final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    required init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
