import SwiftUI

struct CircularGauge: View {
    let value: Double
    let title: String
    let unit: String
    let gradient: Gradient
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 10)
            
            Circle()
                .trim(from: 0, to: CGFloat(value))
                .stroke(
                    AngularGradient(gradient: gradient, center: .center, startAngle: .degrees(-90), endAngle: .degrees(270)),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: value)
            
            VStack(spacing: 0) {
                Text("\(Int(value * 100))")
                    .font(.title2.weight(.bold).monospacedDigit())
                Text(unit)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 120, height: 120)
    }
}
