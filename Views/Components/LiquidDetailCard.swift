import SwiftUI

struct LiquidDetailCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.headline.weight(.bold))
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.8))
                Spacer()
            }
            
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
        }
        .liquidGlass()
    }
}
