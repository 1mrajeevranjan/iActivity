import SwiftUI

/// The panel's workhorse: `label ───filled bar─── value`, with the series' recent history drawn
/// underneath it. Replaces the old circular gauge + separate chart card — same information in a
/// third of the height, and six of them stack without the pane turning into a wall of cards.
struct MetricRow: View {
    let label: String
    /// Right-aligned reading, already formatted ("20%", "5.1 MB/s").
    let value: String
    /// 0…1 bar fill. Pass nil for a series with no meaningful ceiling — the bar is then omitted
    /// and the value gets the space.
    var fraction: Double? = nil
    let tint: Color
    var icon: String? = nil
    /// Recent samples. Nil draws no sparkline.
    var history: [Double]? = nil
    /// Fixed sparkline scale, for percentages.
    var domain: ClosedRange<Double>? = nil
    /// Spoken form when `label` is abbreviated.
    var spokenLabel: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
                    .lineLimit(1)
                    .layoutPriority(1)

                if let fraction {
                    ProgressBar(fraction: fraction, tint: tint, animated: !reduceMotion)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 4)
                } else {
                    Spacer(minLength: 8)
                }

                Text(value)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }

            if let history, history.count > 1 {
                Sparkline(data: history, tint: tint, domain: domain)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spokenLabel ?? label))
        .accessibilityValue(Text(value))
    }
}

/// Thin capsule bar. Its own view so the row stays readable and the fill animation lives in one place.
struct ProgressBar: View {
    let fraction: Double
    let tint: Color
    var animated: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(AppTheme.Colors.track)

                Capsule(style: .continuous)
                    .fill(tint)
                    .frame(width: geo.size.width * CGFloat(min(max(fraction, 0), 1)))
                    .animation(animated ? .easeOut(duration: 0.3) : nil, value: fraction)
            }
        }
        .frame(height: AppTheme.Metrics.barHeight)
        .accessibilityHidden(true)
    }
}
