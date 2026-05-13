import SwiftUI

struct VibrantDarkCard: ViewModifier {
    var radius: CGFloat
    var padding: CGFloat
    
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                ZStack {
                    AppTheme.Colors.cardBackground
                    
                    // Subtle mesh-like gradient for depth
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.03 : 0.2),
                            Color.clear
                        ],
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
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.15 : 0.4),
                                Color.white.opacity(colorScheme == .dark ? 0.02 : 0.1),
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 12, x: 0, y: 6)
    }
}

extension View {
    func vibrantCard(radius: CGFloat = AppTheme.Radius.card, padding: CGFloat = AppTheme.Spacing.medium) -> some View {
        self.modifier(VibrantDarkCard(radius: radius, padding: padding))
    }
    
    // Alias for compatibility during transition
    func liquidGlass(radius: CGFloat = AppTheme.Radius.card, padding: CGFloat = AppTheme.Spacing.medium) -> some View {
        self.vibrantCard(radius: radius, padding: padding)
    }
}
