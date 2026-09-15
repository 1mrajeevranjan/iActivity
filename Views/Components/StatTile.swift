import SwiftUI

/// Small centred readout — icon and label on top, value beneath. Used in rows of two or three for
/// the standing facts of a category (temperature, capacity, model).
struct StatTile: View {
    let icon: String
    let label: String
    let value: String
    var tint: Color = AppTheme.Colors.brandBlue
    /// Spoken form, when the visible label had to be abbreviated to fit a narrow tile.
    var spokenLabel: String? = nil

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(tint)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .frame(height: AppTheme.Metrics.tileHeight)
        .tileSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spokenLabel ?? label))
        .accessibilityValue(Text(value))
    }
}

/// Row of equal-width `StatTile`s. Two or three read well at panel width; more than that and the
/// values start scaling down.
struct StatTileRow: View {
    struct Tile {
        let icon: String
        let label: String
        let value: String
        var spokenLabel: String? = nil
    }

    let tiles: [Tile]
    var tint: Color = AppTheme.Colors.brandBlue

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            ForEach(tiles, id: \.label) { tile in
                StatTile(icon: tile.icon, label: tile.label, value: tile.value, tint: tint, spokenLabel: tile.spokenLabel)
            }
        }
    }
}

/// One line of `Label ............ value`, for facts that need no bar or trend.
struct FactRow: View {
    let label: String
    let value: String
    var icon: String? = nil
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(tint)
                    .frame(width: AppTheme.Metrics.iconColumn, alignment: .leading)
            }
            Text(label)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Text(value)
                .font(.body.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(value))
    }
}
