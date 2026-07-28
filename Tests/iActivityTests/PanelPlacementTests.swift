import Testing
import CoreGraphics
@testable import iActivity

struct PanelPlacementTests {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let panelSize = CGSize(width: 440, height: 640)
    let margin: CGFloat = 8

    @Test("Panel centers under an icon with room on both sides")
    func centersUnderIconWithRoom() {
        let icon = CGRect(x: 700, y: 880, width: 60, height: 24)
        let origin = PanelPlacement.origin(iconFrame: icon, panelSize: panelSize, visibleScreenFrame: screen, edgeMargin: margin)
        #expect(origin.x == icon.midX - panelSize.width / 2)
        #expect(origin.y == icon.minY - panelSize.height)
    }

    @Test("Clamps to the left screen edge when the icon is near the left edge")
    func clampsToLeftEdge() {
        let icon = CGRect(x: 10, y: 880, width: 40, height: 24)
        let origin = PanelPlacement.origin(iconFrame: icon, panelSize: panelSize, visibleScreenFrame: screen, edgeMargin: margin)
        #expect(origin.x == screen.minX + margin)
    }

    @Test("Clamps to the right screen edge when the icon is near the right edge")
    func clampsToRightEdge() {
        let icon = CGRect(x: 1400, y: 880, width: 40, height: 24)
        let origin = PanelPlacement.origin(iconFrame: icon, panelSize: panelSize, visibleScreenFrame: screen, edgeMargin: margin)
        #expect(origin.x == screen.maxX - margin - panelSize.width)
    }

    @Test("Falls back to the unclamped ideal position when the panel is wider than the screen")
    func fallsBackWhenPanelWiderThanScreen() {
        let tinyScreen = CGRect(x: 0, y: 0, width: 300, height: 400)
        let icon = CGRect(x: 100, y: 380, width: 40, height: 24)
        let origin = PanelPlacement.origin(iconFrame: icon, panelSize: panelSize, visibleScreenFrame: tinyScreen, edgeMargin: margin)
        // minX (8) > maxX (300 - 8 - 440 = -148): clamping range is inverted, so this must not
        // produce a garbage value — it should fall back to the unclamped ideal.
        #expect(origin.x == icon.midX - panelSize.width / 2)
        #expect(origin.x.isFinite)
    }

    @Test("Beak offset is zero when the icon sits exactly at the panel's center")
    func beakOffsetZeroWhenCentered() {
        let panelOriginX: CGFloat = 700
        let iconMidX = panelOriginX + panelSize.width / 2
        let icon = CGRect(x: iconMidX - 20, y: 880, width: 40, height: 24)
        let offset = PanelPlacement.beakOffset(iconFrame: icon, panelOriginX: panelOriginX, panelWidth: panelSize.width, maxOffset: 100)
        #expect(offset == 0)
    }

    @Test("Beak offset tracks the icon when within the allowed range")
    func beakOffsetTracksIconWithinRange() {
        let panelOriginX: CGFloat = 700
        let panelCenterX = panelOriginX + panelSize.width / 2
        // 30pt left of the panel's own center — comfortably inside the ±100 clamp below, so this
        // exercises the unclamped tracking path rather than the clamp itself.
        let icon = CGRect(x: panelCenterX - 30 - 20, y: 880, width: 40, height: 24)
        let expected = icon.midX - panelCenterX
        let offset = PanelPlacement.beakOffset(iconFrame: icon, panelOriginX: panelOriginX, panelWidth: panelSize.width, maxOffset: 100)
        #expect(offset == expected)
        #expect(abs(offset) < 100)
    }

    @Test("Beak offset clamps once the icon is far enough that the beak would hit a rounded corner")
    func beakOffsetClampsAtLimit() {
        let panelOriginX: CGFloat = 700
        // Panel got clamped to the screen edge while the icon stayed far to the right — the beak
        // must not slide past the corner even though the raw math wants it to.
        let icon = CGRect(x: panelOriginX + 1000, y: 880, width: 40, height: 24)
        let offset = PanelPlacement.beakOffset(iconFrame: icon, panelOriginX: panelOriginX, panelWidth: panelSize.width, maxOffset: 50)
        #expect(offset == 50)
    }

    @Test("Beak offset clamps negative too, when the icon is far to the left")
    func beakOffsetClampsNegativeAtLimit() {
        let panelOriginX: CGFloat = 700
        let icon = CGRect(x: panelOriginX - 1000, y: 880, width: 40, height: 24)
        let offset = PanelPlacement.beakOffset(iconFrame: icon, panelOriginX: panelOriginX, panelWidth: panelSize.width, maxOffset: 50)
        #expect(offset == -50)
    }

    @Test("Beak offset degrades to zero for a non-positive max offset instead of producing a nonsensical value")
    func beakOffsetGuardsNegativeMaxOffset() {
        let icon = CGRect(x: 900, y: 880, width: 40, height: 24)
        let offset = PanelPlacement.beakOffset(iconFrame: icon, panelOriginX: 700, panelWidth: panelSize.width, maxOffset: -10)
        #expect(offset == 0)
    }
}
