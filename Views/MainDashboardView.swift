import SwiftUI

struct MainDashboardView: View {
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage("selectedCategory") private var selectedCategory: MetricCategory = .cpu
    @AppStorage("isDarkMode") private var isDarkMode: Bool = true
    
    var body: some View {
        ZStack {
            // Liquid Glass background with rounded corners and subtle border
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 12)

            VStack(spacing: 0) {
                categoryTabs

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
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(6)
        .frame(width: 420, height: 580)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
    
    // MARK: - Category Tabs (custom macOS-styled segmented tabs)
    private var categoryTabs: some View {
        HStack(spacing: 0) {
            ForEach(MetricCategory.allCases) { category in
                let isSelected = selectedCategory == category
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        selectedCategory = category
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: category.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(category.shortTitle)
                            .font(.system(size: 11, weight: .semibold))
                            .textCase(.uppercase)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
                                )
                        }
                    }
                )
                .accessibilityLabel(Text(category.shortTitle))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
