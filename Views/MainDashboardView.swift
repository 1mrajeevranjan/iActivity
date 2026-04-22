import SwiftUI

struct MainDashboardView: View {
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage("selectedCategory") private var selectedCategory: MetricCategory = .cpu
    @AppStorage("isDarkMode") private var isDarkMode: Bool = true
    @State private var animateBackground = false
    
    var body: some View {
        VStack(spacing: 0) {
            categoryPicker
            
            Divider()
                .padding(.horizontal, AppTheme.Spacing.medium)
            
            ScrollView {
                VStack(spacing: AppTheme.Spacing.medium) {
                    switch selectedCategory {
                    case .cpu:
                        CPUView()
                    case .gpu:
                        GPUView()
                    case .memory:
                        MemoryView()
                    case .disk:
                        DiskView()
                    case .battery:
                        BatteryView()
                    case .network:
                        NetworkView()
                    }
                }
                .padding(AppTheme.Spacing.medium)
            }
        }
        .frame(width: 420, height: 580)
        .background {
            ZStack {
                Color(isDarkMode ? .black : .white)
                
                GeometryReader { geo in
                    Circle()
                        .fill(AppTheme.Colors.cpuGradient)
                        .frame(width: 350, height: 350)
                        .blur(radius: 80)
                        .offset(x: animateBackground ? geo.size.width - 200 : -100,
                                y: animateBackground ? -100 : geo.size.height - 200)
                        
                    Circle()
                        .fill(AppTheme.Colors.memGradient)
                        .frame(width: 300, height: 300)
                        .blur(radius: 100)
                        .offset(x: animateBackground ? -50 : geo.size.width - 150,
                                y: animateBackground ? geo.size.height - 150 : 50)
                }
            }
            .ignoresSafeArea()
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(isDarkMode ? 0.1 : 0.4), lineWidth: 1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                animateBackground.toggle()
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
    
    // MARK: - Category Picker
    private var categoryPicker: some View {
        HStack(spacing: 8) {
            ForEach(MetricCategory.allCases) { category in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedCategory = category
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .font(.system(size: 18, weight: selectedCategory == category ? .bold : .medium))
                        
                        Text(category.shortTitle)
                            .font(.system(size: 10, weight: .bold))
                        
                        Text(liveValue(for: category))
                            .font(.system(size: 11, weight: .heavy).monospacedDigit())
                            .foregroundStyle(
                                selectedCategory == category
                                ? AppTheme.Colors.accentColor(for: category)
                                : .secondary
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .background(
                        ZStack {
                            if selectedCategory == category {
                                AppTheme.Colors.accentColor(for: category).opacity(0.15)
                            } else {
                                Color.white.opacity(0.06)
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                selectedCategory == category
                                ? AppTheme.Colors.accentColor(for: category).opacity(0.4)
                                : Color.white.opacity(0.12),
                                lineWidth: 1.5
                            )
                    )
                }
                .buttonStyle(.plain)
                .scaleEffect(selectedCategory == category ? 1.05 : 1.0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(8)
    }
    
    // MARK: - Live Value Helper
    /// Returns a compact live value string for each category to show in the picker tabs
    private func liveValue(for category: MetricCategory) -> String {
        switch category {
        case .cpu:
            return "\(Int(monitor.cpu.usage * 100))%"
        case .gpu:
            return "\(Int(monitor.gpu.utilization * 100))%"
        case .memory:
            return "\(Int(monitor.memory.usagePercentage * 100))%"
        case .disk:
            return "\(Int(monitor.disk.usagePercentage * 100))%"
        case .battery:
            return "\(monitor.battery.level)%"
        case .network:
            let speed = monitor.network.downloadSpeed
            if speed >= 1_000_000 {
                return String(format: "%.0fM", speed / 1_000_000)
            } else if speed >= 1_000 {
                return String(format: "%.0fK", speed / 1_000)
            } else {
                return "0B"
            }
        }
    }
}

#Preview {
    MainDashboardView()
        .environment(SystemMonitor())
}
