import SwiftUI

struct ChartCard: View {
    let title: String
    let value: String
    let data: [Double]
    let gradient: Gradient
    let tint: Color
    var domain: ClosedRange<Double>? = nil
    var height: CGFloat = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            MiniHistoryChart(data: data, gradient: gradient, domain: domain)
                .frame(height: height)
        }
        .glassTile(tint: tint)
    }
}
