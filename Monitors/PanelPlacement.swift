import CoreGraphics

/// Pure geometry for anchoring the dashboard panel under its menu bar icon — split out from
/// `PanelManager` so it's testable without a live `NSStatusItem`/`NSScreen`.
enum PanelPlacement {
    /// Where the panel's origin should land: horizontally clamped to the visible screen, vertically
    /// flush with the bottom of the menu bar icon.
    static func origin(iconFrame: CGRect, panelSize: CGSize, visibleScreenFrame: CGRect, edgeMargin: CGFloat) -> CGPoint {
        let idealX = iconFrame.midX - panelSize.width / 2
        let minX = visibleScreenFrame.minX + edgeMargin
        let maxX = visibleScreenFrame.maxX - edgeMargin - panelSize.width
        // If the panel is wider than the available space, minX > maxX — clamping would then
        // invert the range and force the panel to one edge nonsensically, so fall back to the
        // unclamped ideal position instead.
        let originX = maxX >= minX ? min(max(idealX, minX), maxX) : idealX
        let originY = iconFrame.minY - panelSize.height
        return CGPoint(x: originX, y: originY)
    }

    /// How far the beak must slide from the panel's horizontal center to keep pointing at the
    /// icon, clamped so it never slides past the panel's rounded corners.
    static func beakOffset(iconFrame: CGRect, panelOriginX: CGFloat, panelWidth: CGFloat, maxOffset: CGFloat) -> CGFloat {
        guard maxOffset >= 0 else { return 0 }
        let raw = iconFrame.midX - (panelOriginX + panelWidth / 2)
        return min(max(raw, -maxOffset), maxOffset)
    }
}
