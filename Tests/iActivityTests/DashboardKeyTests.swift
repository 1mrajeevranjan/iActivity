import AppKit
import Testing
@testable import iActivity

/// The dashboard's own keyboard shortcuts, decoded from the same `NSEvent`s macOS delivers.
@MainActor
struct DashboardKeyTests {
    private func key(_ code: UInt16, _ characters: String, _ flags: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
            context: nil, characters: characters, charactersIgnoringModifiers: characters,
            isARepeat: false, keyCode: code
        )!
    }

    /// A real arrow press always carries `.function` and `.numericPad`.
    private let arrowFlags: NSEvent.ModifierFlags = [.function, .numericPad]

    @Test("→ and ← step through the tabs, wrapping at both ends")
    func arrowsStep() {
        let right = key(124, "\u{F703}", arrowFlags)
        let left = key(123, "\u{F702}", arrowFlags)
        #expect(PanelManager.category(for: right, current: .cpu) == .gpu)
        #expect(PanelManager.category(for: left, current: .gpu) == .cpu)
        #expect(PanelManager.category(for: left, current: .cpu) == .network)
        #expect(PanelManager.category(for: right, current: .network) == .cpu)
    }

    @Test("⌘1–⌘6 jump straight to a tab; ⌘7 and modified arrows are left alone")
    func commandDigitsJump() {
        let digits: [(UInt16, String)] = [(18, "1"), (19, "2"), (20, "3"), (21, "4"), (23, "5"), (22, "6")]
        for (index, (code, char)) in digits.enumerated() {
            #expect(PanelManager.category(for: key(code, char, .command), current: .cpu) == MetricCategory.allCases[index])
        }
        #expect(PanelManager.category(for: key(26, "7", .command), current: .cpu) == nil)
        #expect(PanelManager.category(for: key(124, "\u{F703}", arrowFlags.union(.shift)), current: .cpu) == nil)
        #expect(PanelManager.category(for: key(124, "\u{F703}", arrowFlags.union(.command)), current: .cpu) == nil)
    }
}
