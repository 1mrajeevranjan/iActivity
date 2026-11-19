import AppKit
import Testing
@testable import iActivity

/// Every row in the right-click menu must reach an object that actually implements its action.
/// A row whose target cannot handle its selector looks enabled and highlights on hover, but the
/// click goes nowhere — which is exactly how "Quit iActivity" silently did nothing.
@MainActor
struct StatusMenuTests {
    private static func flatten(_ menu: NSMenu) -> [NSMenuItem] {
        menu.items.flatMap { [$0] + ($0.submenu.map(flatten) ?? []) }
    }

    @Test("Every status menu row is enabled and dispatches to an object that handles its action")
    func everyRowDispatches() {
        let delegate = AppDelegate()
        defer { delegate.monitor.stop() }
        let rows = Self.flatten(delegate.buildStatusMenu()).filter { !$0.isSeparatorItem && $0.submenu == nil }

        // An attributed title replaces `title` with its text, attachment glyph included.
        #expect(rows.map { $0.title.trimmingCharacters(in: CharacterSet(charactersIn: "\u{FFFC} ")) } == [
            "Settings…", "About", "Support & Feedback", "Tips", "FAQ", "Website",
            "Rate App", "Share App", "More Apps by Me", "Quit iActivity",
        ])
        for row in rows {
            let action = try! #require(row.action, "\(row.title) has no action")
            #expect(row.isEnabled, "\(row.title) is disabled")
            // `target(forAction:)` hands back an explicit target even when it can't handle the
            // selector, so ask the resolved object itself.
            let handler = NSApplication.shared.target(forAction: action, to: row.target, from: row) as AnyObject?
            #expect(handler?.responds(to: action) == true,
                    "\(row.title) → \(action) is sent to \(String(describing: handler)), which cannot handle it")
        }
    }
}
