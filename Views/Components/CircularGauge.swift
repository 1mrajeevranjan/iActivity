import SwiftUI

struct CircularGauge: View {
    let value: Double
    let title: String
    let unit: String
    let gradient: Gradient
    
    var body: some View {
        ZStack {
            // Background track with subtle depth
            Circle()
                .stroke(Color.primary.opacity(0.06), lineWidth: 10)
            
            // Subtle glow for the progress ring
            Circle()
                .trim(from: 0, to: CGFloat(value))
                .stroke(
                    LinearGradient(gradient: gradient, startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .blur(radius: 4)
                .opacity(0.3)
                .animation(.spring(response: 1.0, dampingFraction: 0.8), value: value)

            // Main progress ring
            Circle()
                .trim(from: 0, to: CGFloat(value))
                .stroke(
                    LinearGradient(gradient: gradient, startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.0, dampingFraction: 0.8), value: value)
            
            VStack(spacing: 0) {
                Text(unit)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)
            }
        }
        .frame(width: 130, height: 130)
    }
}
