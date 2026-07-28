import SwiftUI

/// The popover silhouette macOS menu extras (Calendar, Control Center) use: a rounded card with a
/// beak fused into its top edge, aimed at the menu bar icon the panel dropped from.
///
/// Card and beak are one continuous path so a translucent material fills them as a single surface —
/// drawing the beak as a separate shape leaves a visible seam, and a solid-colour beak can never
/// match a material-filled card.
struct MenuBarPopoverShape: Shape {
    /// Horizontal shift of the beak from centre, used when the panel is clamped against a screen edge.
    var beakOffsetX: CGFloat = 0
    var cornerRadius: CGFloat = AppTheme.Panel.cornerRadius
    var beakWidth: CGFloat = AppTheme.Panel.beakWidth
    var beakRise: CGFloat = AppTheme.Panel.beakRise

    func path(in rect: CGRect) -> Path {
        let r = cornerRadius
        let top = rect.minY + beakRise
        let half = beakWidth / 2
        let limit = max(0, rect.width / 2 - r - half)
        let beakCenterX = rect.midX + min(max(beakOffsetX, -limit), limit)

        // Straight flanks with a rounded tip — a single curve across the whole base reads as a
        // blunt bump rather than an arrow. `tipFraction` is how far down each flank the rounding starts.
        let tipFraction: CGFloat = 0.3
        let apex = CGPoint(x: beakCenterX, y: rect.minY)
        let leftCut = CGPoint(x: beakCenterX - half * tipFraction, y: rect.minY + beakRise * tipFraction)
        let rightCut = CGPoint(x: beakCenterX + half * tipFraction, y: rect.minY + beakRise * tipFraction)

        var path = Path()
        path.move(to: CGPoint(x: beakCenterX - half, y: top))
        path.addLine(to: leftCut)
        path.addQuadCurve(to: rightCut, control: apex)
        path.addLine(to: CGPoint(x: beakCenterX + half, y: top))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: top),
                    tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: r)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
                    tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: r)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
                    tangent2End: CGPoint(x: rect.minX, y: top), radius: r)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: top),
                    tangent2End: CGPoint(x: rect.maxX, y: top), radius: r)
        path.closeSubpath()
        return path
    }
}
