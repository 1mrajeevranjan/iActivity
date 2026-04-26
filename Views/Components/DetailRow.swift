import SwiftUI

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
        }
    }
}
