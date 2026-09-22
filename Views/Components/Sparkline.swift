import SwiftUI

/// A bare trend line — no axes, no gridlines, no legend, no library.
///
/// `Charts` would work, but a sparkline is one polyline: a hand-drawn `Path` avoids a full chart
/// layout pass every refresh tick and gives the thin, unsmoothed line this design wants.
///
/// The shape comes from the user's `ChartStyle`, read here rather than threaded through every
/// call site, so none of the category views need to know the setting exists.
struct Sparkline: View {
    let data: [Double]
    let tint: Color
    /// Fixed scale, for series with a real ceiling (a percentage). Nil auto-scales to the window,
    /// which is what throughput needs.
    var domain: ClosedRange<Double>? = nil

    /// A second series drawn beneath the first on the same scale — the CPU tab's P/E split, and
    /// the menu bar's read/write and down/up pairs.
    var secondary: [Double]? = nil
    var secondaryTint: Color = AppTheme.Colors.brandBlue

    /// Overrides the stored style. The menu bar passes its own *geometry*, not its own style —
    /// picking "Area" is expected to change both surfaces at once.
    var styleOverride: ChartStyle? = nil
    var height: CGFloat = AppTheme.Metrics.sparklineHeight
    var lineWidth: CGFloat = 1.5

    @AppStorage("chartStyle") private var storedStyle: ChartStyle = .line
    @Environment(\.colorSchemeContrast) private var contrast

    private var style: ChartStyle { styleOverride ?? storedStyle }

    /// Bounds span BOTH series, so a pair is read against one scale. Scaling each independently
    /// would draw an idle efficiency cluster as busy as a pinned performance one.
    private var bounds: (low: Double, high: Double) {
        if let domain { return (domain.lowerBound, domain.upperBound) }
        let peak = max(data.max() ?? 1, secondary?.max() ?? 0)
        // A flat-zero series would otherwise divide by zero and collapse the line onto the baseline.
        return (0, peak > 0 ? peak * 1.15 : 1)
    }

    var body: some View {
        GeometryReader { geo in
            let (low, high) = bounds
            ZStack {
                if let secondary, secondary.count > 1 {
                    series(secondary, tint: secondaryTint, in: geo.size, low: low, high: high)
                }
                if data.count > 1 {
                    series(data, tint: tint, in: geo.size, low: low, high: high)
                }
            }
        }
        .frame(height: height)
        // Decorative: the row above it already states the current value in accessible form (§ 12).
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func series(_ values: [Double], tint: Color, in size: CGSize, low: Double, high: Double) -> some View {
        let points = Self.points(values, in: size, low: low, high: high)
        switch style {
        case .bars:
            // Slightly transparent so an overlapping pair still reads as two series.
            Self.barsPath(points, in: size)
                .fill(tint.opacity(contrast == .increased ? 0.95 : 0.78))
        case .line, .area, .stepped:
            let polyline = Self.polyline(points, stepped: style == .stepped)
            ZStack {
                Self.fillPath(polyline, height: size.height)
                    .fill(wash(tint))
                Self.strokePath(polyline)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
    }

    /// `area` is the same line with the wash turned up until it reads as a filled region rather
    /// than a hint of one — the only difference between the two styles.
    private func wash(_ tint: Color) -> LinearGradient {
        let top: Double = switch style {
        case .area: contrast == .increased ? 0.55 : 0.42
        default: contrast == .increased ? 0.30 : 0.18
        }
        return LinearGradient(
            colors: [tint.opacity(top), tint.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Geometry

    private static func points(_ values: [Double], in size: CGSize, low: Double, high: Double) -> [CGPoint] {
        let span = max(high - low, .leastNonzeroMagnitude)
        return values.enumerated().map { index, value in
            let x = values.count > 1 ? size.width * CGFloat(index) / CGFloat(values.count - 1) : 0
            let normalized = (value - low) / span
            return CGPoint(x: x, y: size.height * (1 - CGFloat(min(max(normalized, 0), 1))))
        }
    }

    /// A staircase repeats the previous y at each new x, so each reading is held until it changes
    /// instead of being interpolated towards the next one.
    private static func polyline(_ points: [CGPoint], stepped: Bool) -> [CGPoint] {
        guard stepped else { return points }
        var stepping: [CGPoint] = []
        stepping.reserveCapacity(points.count * 2)
        for (index, point) in points.enumerated() {
            if index > 0 { stepping.append(CGPoint(x: point.x, y: points[index - 1].y)) }
            stepping.append(point)
        }
        return stepping
    }

    private static func strokePath(_ points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
        }
    }

    /// The line closed down to the baseline, which is what the wash fills.
    private static func fillPath(_ points: [CGPoint], height: CGFloat) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: height))
            points.forEach { path.addLine(to: $0) }
            path.addLine(to: CGPoint(x: last.x, y: height))
            path.closeSubpath()
        }
    }

    /// One column per sample, centred on its point and grown down to the baseline. Columns are
    /// clamped inside the box so the first and last are not sliced in half by the edge.
    private static func barsPath(_ points: [CGPoint], in size: CGSize) -> Path {
        Path { path in
            guard points.count > 1, size.width > 0 else { return }
            let slot = size.width / CGFloat(points.count)
            let width = max(slot * 0.62, 0.5)
            for point in points {
                let x = min(max(point.x - width / 2, 0), max(size.width - width, 0))
                path.addRect(CGRect(x: x, y: point.y, width: width, height: max(size.height - point.y, 0)))
            }
        }
    }
}
