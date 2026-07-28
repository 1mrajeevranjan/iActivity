import SwiftUI

struct StatTile: View {
    let icon: String
    let label: String
    let value: String
    var tint: Color = AppTheme.Colors.brandBlue

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassTile(radius: AppTheme.Radius.inner, padding: 12, tint: tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(value))
    }
}

/// Two-column grid of `StatTile`s — the consistent secondary-data layout reused by every category view.
struct StatTileGrid: View {
    let tiles: [(icon: String, label: String, value: String)]
    var tint: Color = AppTheme.Colors.brandBlue

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: AppTheme.Spacing.small), GridItem(.flexible())], spacing: AppTheme.Spacing.small) {
            ForEach(tiles, id: \.label) { tile in
                StatTile(icon: tile.icon, label: tile.label, value: tile.value, tint: tint)
            }
        }
    }
}
