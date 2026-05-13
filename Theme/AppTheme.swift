import SwiftUI

enum AppTheme {
    enum Colors {
        // BatterySense "Vibrant Dark" Palette
        static let background = Color(NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1.0)
            } else {
                return NSColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0)
            }
        })
        
        static let cardBackground = Color(NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
            } else {
                return NSColor.white
            }
        })
        
        static let batteryGreen = Color(red: 0.18, green: 0.8, blue: 0.44) // Vibrant Emerald
        static let brandBlue = Color(red: 0.2, green: 0.6, blue: 1.0)
        
        static let cpuGradient = Gradient(colors: [brandBlue, brandBlue.opacity(0.7)])
        static let gpuGradient = Gradient(colors: [Color.purple, Color.purple.opacity(0.7)])
        static let memGradient = Gradient(colors: [batteryGreen, batteryGreen.opacity(0.7)])
        static let diskGradient = Gradient(colors: [Color.orange, Color.orange.opacity(0.7)])
        static let batteryGradient = Gradient(colors: [batteryGreen, batteryGreen.opacity(0.8)])
        static let networkGradient = Gradient(colors: [Color.cyan, Color.cyan.opacity(0.7)])
        
        static func accentColor(for category: MetricCategory) -> Color {
            switch category {
            case .cpu: return brandBlue
            case .gpu: return .purple
            case .memory: return batteryGreen
            case .disk: return .orange
            case .battery: return batteryGreen
            case .network: return .cyan
            }
        }
    }
    
    enum Spacing {
        static let tiny: CGFloat = 6
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }
    
    enum Radius {
        static let card: CGFloat = 14
        static let inner: CGFloat = 10
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
