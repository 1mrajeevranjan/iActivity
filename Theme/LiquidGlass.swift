import SwiftUI

struct PhotorealisticGlass: ViewModifier {
    var radius: CGFloat
    var padding: CGFloat
    
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                // Base frosted reflection
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .background {
                // Ambient lighting layer
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.4),
                                Color.white.opacity(0.0),
                                Color.white.opacity(colorScheme == .dark ? 0.0 : 0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            // Glass Rim Refraction Edge
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.3 : 0.8),
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1),
                                Color.white.opacity(colorScheme == .dark ? 0.0 : 0.0),
                                Color.white.opacity(colorScheme == .dark ? 0.1 : 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.screen)
            }
            // Inner convex shadow
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.05), lineWidth: 1)
                    .blur(radius: 1)
                    .offset(x: 1, y: 1)
                    .mask(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
            // Deep drop shadow
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.15), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func liquidGlass(radius: CGFloat = AppTheme.Radius.card, padding: CGFloat = AppTheme.Spacing.medium) -> some View {
        self.modifier(PhotorealisticGlass(radius: radius, padding: padding))
    }
    
    func liquidGlassInteractive(radius: CGFloat = AppTheme.Radius.card, padding: CGFloat = AppTheme.Spacing.medium) -> some View {
        self
            .modifier(PhotorealisticGlass(radius: radius, padding: padding))
            // Interactive scaling for buttons handled externally or by using standard Button styles
            .scaleEffect(1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: 1.0)
    }
}
