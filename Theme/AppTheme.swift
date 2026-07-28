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

    /// Geometry shared between the SwiftUI dashboard and the AppKit panel that hosts it.
    /// The window is deliberately larger than the visible card so the card's shadow can fade
    /// out inside the window — a shadow that reaches the window edge gets clipped there and
    /// reads as a hard rectangular outline around the popover.
    enum Panel {
        static let cardWidth: CGFloat = 440
        static let cardHeight: CGFloat = 620
        static let cornerRadius: CGFloat = 18

        /// Transparent gutter on the sides and bottom that gives the shadow room to fade.
        static let shadowMargin: CGFloat = 20

        /// Gutter above the beak's tip. AppKit clamps a window's top to the menu bar, so the window
        /// top ends up flush with it and this doubles as the gap between the menu bar and the beak.
        /// Kept tiny so the beak reads as touching the menu bar; the card's shadow is offset
        /// downward by a matching amount so it still fades out inside this margin.
        static let topGutter: CGFloat = 2

        /// Width of the beak's base where it meets the card.
        static let beakWidth: CGFloat = 24
        /// How far the beak rises above the card's top edge.
        static let beakRise: CGFloat = 11

        static var topInset: CGFloat { topGutter + beakRise }
        static var windowWidth: CGFloat { cardWidth + shadowMargin * 2 }
        static var windowHeight: CGFloat { cardHeight + topInset + shadowMargin }

        static let screenEdgeMargin: CGFloat = 8

        /// Furthest the beak may slide from centre before it would collide with a rounded corner.
        static var maxBeakOffset: CGFloat { cardWidth / 2 - cornerRadius - beakWidth / 2 }
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

enum AppearanceMode: String, CaseIterable, Identifiable {
    case light, dark, auto
    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "Auto"
        }
    }

    /// nil means "follow the system appearance."
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .auto: return nil
        }
    }
}

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius, fahrenheit
    var id: String { rawValue }

    var title: String {
        switch self {
        case .celsius: return "Celsius"
        case .fahrenheit: return "Fahrenheit"
        }
    }

    var shortTitle: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }

    func string(fromCelsius celsius: Double, decimals: Int = 1) -> String {
        let value = self == .celsius ? celsius : celsius * 9 / 5 + 32
        return String(format: "%.\(decimals)f%@", value, shortTitle)
    }
}

enum RefreshInterval: Double, CaseIterable, Identifiable {
    case fast = 1.0
    case normal = 2.0
    case slow = 5.0
    var id: Double { rawValue }

    var title: String {
        switch self {
        case .fast: return "1s"
        case .normal: return "2s"
        case .slow: return "5s"
        }
    }
}
