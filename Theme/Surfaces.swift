import SwiftUI
import AppKit

/// Flat, layered surfaces — no glass, no per-element shadow.
///
/// The panel is the only elevated thing on screen. Everything inside it separates by tone and by
/// hairline rules, which is what makes a dense panel read as calm instead of as a pile of cards.

struct CardSurface: ViewModifier {
    var padding: CGFloat = AppTheme.Metrics.cardPadding

    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: AppTheme.Metrics.cardRadius, style: .continuous)
        return content
            .padding(padding)
            .background(AppTheme.Colors.card, in: shape)
            .overlay {
                // Only drawn when the user asks for more contrast; at rest the tone step is the
                // separation, and an always-on border would fight the flat look.
                if contrast == .increased {
                    shape.strokeBorder(Color.primary.opacity(0.45), lineWidth: 1)
                }
            }
    }
}

struct TileSurface: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: AppTheme.Metrics.tileRadius, style: .continuous)
        return content
            .background(AppTheme.Colors.tile, in: shape)
            .overlay {
                if contrast == .increased {
                    shape.strokeBorder(Color.primary.opacity(0.4), lineWidth: 1)
                }
            }
    }
}

extension View {
    func cardSurface(padding: CGFloat = AppTheme.Metrics.cardPadding) -> some View {
        modifier(CardSurface(padding: padding))
    }

    func tileSurface() -> some View {
        modifier(TileSurface())
    }

    /// Pointing-hand cursor for custom tappable views. SwiftUI does not set it automatically —
    /// not even for `Button` on macOS.
    func pointerOnHover() -> some View {
        onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

/// Sentence-case label introducing a group of rows inside the card, e.g. "Hardware usage".
struct GroupLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Hairline rule between groups inside a card.
struct CardDivider: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Rectangle()
            .fill(AppTheme.Colors.hairline(contrast))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}
