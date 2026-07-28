import SwiftUI

struct GlassTile: ViewModifier {
    var radius: CGFloat
    var padding: CGFloat
    var tint: Color

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var isTinted: Bool { tint != .clear }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(reduceTransparency ? AnyShapeStyle(AppTheme.Colors.cardBackground) : AnyShapeStyle(.ultraThinMaterial))

                    if isTinted {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(tint.opacity(colorScheme == .dark ? 0.12 : 0.07))
                    }

                    LinearGradient(
                        colors: [Color.white.opacity(colorScheme == .dark ? 0.05 : 0.25), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isTinted
                                ? [tint.opacity(0.55), tint.opacity(0.08)]
                                : [Color.white.opacity(colorScheme == .dark ? 0.16 : 0.45), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: (isTinted ? tint : .black).opacity(colorScheme == .dark ? (isTinted ? 0.28 : 0.32) : (isTinted ? 0.16 : 0.08)),
                radius: 14, x: 0, y: 8
            )
    }
}

extension View {
    /// Single card shape used across the whole dashboard — frosted glass with an optional category-tinted glow border.
    func glassTile(radius: CGFloat = AppTheme.Radius.card, padding: CGFloat = AppTheme.Spacing.medium, tint: Color = .clear) -> some View {
        modifier(GlassTile(radius: radius, padding: padding, tint: tint))
    }
}
