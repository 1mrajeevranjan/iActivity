import SwiftUI

struct MainDashboardView: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(PanelAnchor.self) private var anchor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage("selectedCategory") private var selectedCategory: MetricCategory = .cpu
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .dark
    @Namespace private var tabPill
    /// Direction of the last tab change, so content slides the way the pill travels.
    @State private var isForward = true

    private var panelFill: AnyShapeStyle {
        reduceTransparency ? AnyShapeStyle(AppTheme.Colors.background) : AnyShapeStyle(.ultraThinMaterial)
    }

    /// Card and beak as one surface, with the beak aimed at the menu bar icon.
    private var popoverShape: MenuBarPopoverShape {
        MenuBarPopoverShape(beakOffsetX: anchor.beakOffsetX)
    }

    var body: some View {
        ZStack(alignment: .top) {
            popoverShape
                .fill(panelFill)
                // Hairline edge, as native popovers have. Without it the beak — a bare sliver of
                // translucent material — is indistinguishable from whatever sits behind it.
                .overlay(popoverShape.stroke(Color.primary.opacity(0.14), lineWidth: 1))
                // Offset down by nearly the blur radius so the shadow barely reaches above the
                // beak — it has only `topGutter` of room up there before the window clips it.
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 8)

            VStack(spacing: 0) {
                categoryTabs
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // Content Area — slides in from the side the new tab sits on, so the panel reads as
                // one strip moving under the pill rather than a hard cut.
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.medium) {
                        content(for: selectedCategory)
                    }
                    .padding(AppTheme.Spacing.medium)
                }
                // Keeps the overlay scroller off the card's rounded corner.
                .padding(.trailing, 4)
                .id(selectedCategory)
                .transition(contentTransition)
            }
            // Sits below the beak, clipped to the same silhouette as the fill.
            .padding(.top, AppTheme.Panel.beakRise)
            .clipShape(popoverShape)
        }
        .frame(width: AppTheme.Panel.cardWidth, height: AppTheme.Panel.cardHeight + AppTheme.Panel.beakRise)
        // Transparent gutter so the shadow fades out before the window edge clips it — a shadow
        // cut off at the window bounds reads as a hard rectangular outline around the popover.
        // The top is kept tight so the beak stays close to the menu bar.
        .padding(.horizontal, AppTheme.Panel.shadowMargin)
        .padding(.bottom, AppTheme.Panel.shadowMargin)
        .padding(.top, AppTheme.Panel.topGutter)
        .preferredColorScheme(appearanceMode.colorScheme)
    }

    // MARK: - Category Tabs (glass pill bar with a sliding selection)
    private var categoryTabs: some View {
        HStack(spacing: 2) {
            ForEach(MetricCategory.allCases) { category in
                CategoryTabButton(
                    category: category,
                    isSelected: selectedCategory == category,
                    tint: AppTheme.Colors.accentColor(for: category),
                    namespace: tabPill,
                    reduceMotion: reduceMotion
                ) {
                    select(category)
                }
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background {
            Capsule(style: .continuous)
                .fill(reduceTransparency ? AnyShapeStyle(AppTheme.Colors.cardBackground) : AnyShapeStyle(.ultraThinMaterial))
                .overlay(Capsule(style: .continuous).stroke(Color.primary.opacity(0.10), lineWidth: 1))
        }
    }

    @ViewBuilder
    private func content(for category: MetricCategory) -> some View {
        switch category {
        case .cpu: CPUView()
        case .gpu: GPUView()
        case .memory: MemoryView()
        case .disk: DiskView()
        case .battery: BatteryView()
        case .network: NetworkView()
        }
    }

    /// Outgoing page exits opposite the incoming one, so both travel the same direction together.
    private var contentTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: isForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: isForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private func select(_ category: MetricCategory) {
        guard category != selectedCategory else { return }

        let order = MetricCategory.allCases
        if let from = order.firstIndex(of: selectedCategory), let to = order.firstIndex(of: category) {
            // Set outside the animation — the transition reads it while building the change.
            isForward = to > from
        }

        guard !reduceMotion else {
            selectedCategory = category
            return
        }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            selectedCategory = category
        }
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

private struct CategoryTabButton: View {
    let category: MetricCategory
    let isSelected: Bool
    let tint: Color
    let namespace: Namespace.ID
    let reduceMotion: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? tint : .secondary)
                Text(category.shortTitle)
                    .font(.system(size: 10, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background {
            if isSelected {
                // One pill shared across every tab via matchedGeometryEffect, so changing tabs
                // glides the glass across the bar rather than cross-fading in place.
                Capsule(style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(Capsule(style: .continuous).fill(tint.opacity(0.18)))
                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.45), lineWidth: 0.8))
                    .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
                    .matchedGeometryEffect(id: "selectedTabPill", in: namespace)
            } else if isHovered {
                Capsule(style: .continuous).fill(Color.primary.opacity(0.06))
            }
        }
        .onHover { hovering in
            if reduceMotion {
                isHovered = hovering
            } else {
                withAnimation(.easeOut(duration: 0.12)) { isHovered = hovering }
            }
        }
        .accessibilityLabel(Text(category.shortTitle))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    MainDashboardView()
        .environment(SystemMonitor())
        .environment(PanelAnchor())
}
