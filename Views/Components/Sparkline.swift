import SwiftUI

/// A bare trend line — no axes, no gridlines, no legend, no library.
///
/// `Charts` would work, but a sparkline is one polyline: a hand-drawn `Path` avoids a full chart
/// layout pass every refresh tick and gives the thin, unsmoothed line this design wants.
struct Sparkline: View {
    let data: [Double]
    let tint: Color
    /// Fixed scale, for series with a real ceiling (a percentage). Nil auto-scales to the window,
    /// which is what throughput needs.
    var domain: ClosedRange<Double>? = nil

    @Environment(\.colorSchemeContrast) private var contrast

    private var bounds: (low: Double, high: Double) {
        if let domain { return (domain.lowerBound, domain.upperBound) }
        let high = data.max() ?? 1
        // A flat-zero series would otherwise divide by zero and collapse the line onto the baseline.
        return (0, high > 0 ? high * 1.15 : 1)
    }

    var body: some View {
        GeometryReader { geo in
            let (low, high) = bounds
            let span = max(high - low, .leastNonzeroMagnitude)
            let points = data.enumerated().map { index, value -> CGPoint in
                let x = data.count > 1 ? geo.size.width * CGFloat(index) / CGFloat(data.count - 1) : 0
                let normalized = (value - low) / span
                let y = geo.size.height * (1 - CGFloat(min(max(normalized, 0), 1)))
                return CGPoint(x: x, y: y)
            }

            ZStack {
                if points.count > 1 {
                    // Very light wash under the line, enough to give the band a floor without
                    // becoming an area chart.
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: geo.size.height))
                        points.forEach { path.addLine(to: $0) }
                        path.addLine(to: CGPoint(x: points[points.count - 1].x, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(contrast == .increased ? 0.30 : 0.18), tint.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    Path { path in
                        path.move(to: points[0])
                        points.dropFirst().forEach { path.addLine(to: $0) }
                    }
                    .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(height: AppTheme.Metrics.sparklineHeight)
        // Decorative: the row above it already states the current value in accessible form (§ 12).
        .accessibilityHidden(true)
    }
}
