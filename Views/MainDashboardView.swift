import SwiftUI

struct MainDashboardView: View {
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage("selectedCategory") private var selectedCategory: MetricCategory = .cpu
    @AppStorage("isDarkMode") private var isDarkMode: Bool = true
    @State private var animateBackground = false
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            // Subtle animated background glow
            if isDarkMode {
                Circle()
                    .fill(AppTheme.Colors.accentColor(for: selectedCategory).opacity(0.06))
                    .frame(width: 400, height: 400)
                    .blur(radius: 100)
                    .offset(x: animateBackground ? 100 : -100, y: animateBackground ? -100 : 100)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                            animateBackground.toggle()
                        }
                    }
            }

            VStack(spacing: 0) {
                categoryPicker
                
                // Content Area
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
        }
        .frame(width: 420, height: 580)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
    
    // MARK: - Category Picker
    private var categoryPicker: some View {
        HStack(spacing: 4) {
            ForEach(MetricCategory.allCases) { category in
                navButton(category: category)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Divider().opacity(0.4), alignment: .bottom)
        }
    }

    private func navButton(category: MetricCategory) -> some View {
        let isSelected = selectedCategory == category
        let accent = AppTheme.Colors.accentColor(for: category)
        
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedCategory = category
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accent.opacity(0.12))
                            .matchedGeometryEffect(id: "navBG", in: navNamespace)
                    }
                    
                    Image(systemName: isSelected ? "\(category.icon).fill" : category.icon)
                        .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                }
                .frame(width: 36, height: 32)
                
                VStack(spacing: 0) {
                    Text(category.shortTitle)
                        .font(.system(size: 9, weight: .black))
                        .opacity(isSelected ? 1.0 : 0.6)
                    
                    Text(liveValue(for: category))
                        .font(.system(size: 9, weight: .bold).monospacedDigit())
                        .opacity(isSelected ? 0.9 : 0.5)
                }
            }
            .foregroundColor(isSelected ? accent : .secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @Namespace private var navNamespace
    
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
