import SwiftUI
import Combine

/// Posted by `PanelManager`'s key monitor with a `MetricCategory.rawValue` as the object. A
/// borderless panel never routes key events through SwiftUI's `.keyboardShortcut`, so arrow-key
/// and ⌘1–⌘6 tab switching has to arrive this way.
extension Notification.Name {
    static let selectMetricCategory = Notification.Name("iActivity.selectMetricCategory")
}

/// Natural height of the selected tab's card — the part that varies per tab.
///
/// Takes the max rather than the last value: SwiftUI runs `reduce` over every sibling subtree, and
/// all the ones that never set this key contribute `defaultValue`. A plain `value = nextValue()`
/// therefore lets whichever sibling happens to come last overwrite the real measurement with zero.
private struct CardHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Combined height of the fixed furniture around the card: the header/tabs/eyebrow block plus the
/// footer. Reported from two places, so this one **sums** rather than overwrites.
private struct ChromeHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value += nextValue() }
}

private extension View {
    func measureHeight<K: PreferenceKey>(_ key: K.Type) -> some View where K.Value == CGFloat {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: key, value: proxy.size.height)
            }
        }
    }
}

struct MainDashboardView: View {
    @Environment(PanelAnchor.self) private var anchor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @AppStorage("selectedCategory") private var selectedCategory: MetricCategory = .cpu
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .auto
    /// Direction of the last tab change, so content slides the way the pill travels.
    @State private var isForward = true
    @State private var cardHeight: CGFloat = 0
    @State private var chromeHeight: CGFloat = 0

    private let gutter: CGFloat = 12

    /// What the popover should actually be: its furniture plus whatever this tab has to show,
    /// never taller than the screen allows. The `ScrollView` inside only ever engages when the
    /// `min` bites — on every ordinary tab the panel is exactly as tall as its content.
    private var fittedHeight: CGFloat {
        let natural = chromeHeight + cardHeight + AppTheme.Panel.beakRise
        guard anchor.maxCardHeight > 0 else { return natural }
        return min(natural, anchor.maxCardHeight)
    }

    private var panelFill: AnyShapeStyle {
        reduceTransparency ? AnyShapeStyle(AppTheme.Colors.background) : AnyShapeStyle(.regularMaterial)
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
                .overlay(popoverShape.stroke(Color.primary.opacity(contrast == .increased ? 0.5 : 0.14), lineWidth: 1))
                // Offset down by nearly the blur radius so the shadow barely reaches above the
                // beak — it has only `topGutter` of room up there before the window clips it.
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 8)

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    header
                    categoryTabs
                        .padding(.horizontal, gutter)
                        .padding(.bottom, 10)
                }
                .measureHeight(ChromeHeightKey.self)

                // A `ScrollView` proposes its OWN current size to its content rather than letting
                // the content report an ideal size upward — and since that size here comes from
                // the very `.frame(height:)` below that this measurement feeds, the two chase each
                // other down to zero the moment anything squeezes the loop even slightly. `.fixedSize`
                // breaks the loop: it forces the card to lay out (and report, via the GeometryReader
                // in `measureHeight`) its true ideal height regardless of what the ScrollView
                // proposes, so the measurement is no longer a function of its own output.
                ScrollView {
                    content(for: selectedCategory)
                        .cardSurface()
                        .padding(.horizontal, gutter)
                        .padding(.bottom, gutter)
                        .fixedSize(horizontal: false, vertical: true)
                        .measureHeight(CardHeightKey.self)
                }
                .scrollIndicators(.never)
                .id(selectedCategory)
                .transition(contentTransition)

                footer
                    .padding(.horizontal, gutter)
                    .padding(.bottom, gutter)
                    .measureHeight(ChromeHeightKey.self)
            }
            // Sits below the beak, clipped to the same silhouette as the fill.
            .padding(.top, AppTheme.Panel.beakRise)
            .clipShape(popoverShape)
        }
        // Gated on `cardHeight`, not `fittedHeight` — chrome alone plus the beak is already
        // nonzero, which would lock the frame to a sliver for the one frame before the card
        // (the value that starts at zero) has actually measured.
        .frame(width: AppTheme.Panel.cardWidth, height: cardHeight > 0 ? fittedHeight : nil)
        // Transparent gutter so the shadow fades out before the window edge clips it — a shadow
        // cut off at the window bounds reads as a hard rectangular outline around the popover.
        // The top is kept tight so the beak stays close to the menu bar.
        .padding(.horizontal, AppTheme.Panel.shadowMargin)
        .padding(.bottom, AppTheme.Panel.shadowMargin)
        .padding(.top, AppTheme.Panel.topGutter)
        .preferredColorScheme(appearanceMode.colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: .selectMetricCategory)) { note in
            guard let raw = note.object as? String, let category = MetricCategory(rawValue: raw) else { return }
            select(category)
        }
        .onPreferenceChange(CardHeightKey.self) { cardHeight = $0 }
        .onPreferenceChange(ChromeHeightKey.self) { chromeHeight = $0 }
        .onChange(of: fittedHeight) { _, height in
            // Zero means nothing has laid out yet; the panel keeps its opening size until the
            // first real measurement lands rather than flashing shut.
            guard height > 0 else { return }
            anchor.onContentHeightChange?(height)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("iActivity")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .accessibilityHidden(true)
    }

    // MARK: - Category tabs (icon-only, filled selection)

    private var categoryTabs: some View {
        HStack(spacing: 2) {
            ForEach(MetricCategory.allCases) { category in
                CategoryTabButton(
                    category: category,
                    isSelected: selectedCategory == category,
                    tint: AppTheme.Colors.accentColor(for: category),
                    reduceMotion: reduceMotion
                ) {
                    select(category)
                }
            }
        }
        .padding(3)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardRadius, style: .continuous)
                .fill(AppTheme.Colors.card)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            FooterButton(title: "Settings", icon: "gearshape") {
                AppDelegate.shared?.showSettings()
            }
            FooterButton(title: "Quit", icon: "power") {
                NSApplication.shared.terminate(nil)
            }
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
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            selectedCategory = category
        }
    }
}

private struct CategoryTabButton: View {
    let category: MetricCategory
    let isSelected: Bool
    let tint: Color
    let reduceMotion: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(category.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
                .foregroundStyle(isSelected ? Color.white : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: AppTheme.Metrics.tabHeight - 6)
                .contentShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.chipRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .background {
            let shape = RoundedRectangle(cornerRadius: AppTheme.Metrics.chipRadius, style: .continuous)
            if isSelected {
                shape.fill(tint)
            } else if isHovered {
                shape.fill(Color.primary.opacity(0.07))
            }
        }
        .onHover { hovering in
            if reduceMotion {
                isHovered = hovering
            } else {
                withAnimation(.easeOut(duration: 0.12)) { isHovered = hovering }
            }
        }
        .pointerOnHover()
        .help(Text(category.displayName))
        // `shortTitle` here made VoiceOver spell out "M-E-M" and "B-A-T".
        .accessibilityLabel(Text(category.displayName))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct FooterButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.callout)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.Metrics.footerHeight)
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.tileRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.tileRadius, style: .continuous)
                .fill(AppTheme.Colors.card.opacity(isHovered ? 1 : 0.75))
        }
        .onHover { isHovered = $0 }
        .pointerOnHover()
        .accessibilityLabel(Text(title))
    }
}
