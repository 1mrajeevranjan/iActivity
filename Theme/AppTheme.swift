import SwiftUI

enum AppTheme {
    enum Colors {
        static let background = Color.primary.opacity(0.03)
        
        static let cpuGradient = Gradient(colors: [Color(hex: "5CA4F0"), Color(hex: "8D7CF6")])
        static let gpuGradient = Gradient(colors: [Color(hex: "FF8585"), Color(hex: "FFF08A")])
        static let memGradient = Gradient(colors: [Color(hex: "B7EFD7"), Color(hex: "4CCB85")])
        static let diskGradient = Gradient(colors: [Color(hex: "FFBE62"), Color(hex: "FF9E26")])
        static let batteryGradient = Gradient(colors: [Color(hex: "AEFCAF"), Color(hex: "349E34")])
        static let networkGradient = Gradient(colors: [Color(hex: "95DDF9"), Color(hex: "567DF4")])
        
        static func accentColor(for category: MetricCategory) -> Color {
            switch category {
            case .cpu: return Color(hex: "5CA4F0")
            case .gpu: return Color(hex: "FF8585")
            case .memory: return Color(hex: "4CCB85")
            case .disk: return Color(hex: "FF9E26")
            case .battery: return Color(hex: "349E34")
            case .network: return Color(hex: "567DF4")
            }
        }
    }
    
    enum Spacing {
        static let tiny: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }
    
    enum Radius {
        static let card: CGFloat = 12
        static let inner: CGFloat = 8
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum MetricCategory: String, CaseIterable, Identifiable {
    case cpu, gpu, memory, disk, battery, network
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .gpu: return "square.grid.3x1.below.line.grid.1x2"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .battery: return "battery.100"
        case .network: return "network"
        }
    }
    
    var title: String {
        self.rawValue.uppercased()
    }
    
    var shortTitle: String {
        switch self {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .memory: return "MEM"
        case .disk: return "DISK"
        case .battery: return "BAT"
        case .network: return "NET"
        }
    }
}
