import SwiftUI

struct OnboardingView: View {
    /// Supplied by `AppDelegate`, which owns the window. `@Environment(\.dismiss)` is a no-op in a
    /// bare `NSHostingView` — there is no scene to dismiss — so "Get Started" closed nothing.
    let onFinish: () -> Void

    @State private var launchAtLogin = AppSetup.shared.isLaunchAtLoginEnabled
    @State private var showInDock = UserDefaults.standard.bool(forKey: "showInDock")

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 80, height: 80)
                    // Neutral drop shadow: the blue one tinted the icon's own edge and did not
                    // belong to any semantic meaning.
                    .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)

                Text("Welcome to iActivity")
                    .font(.largeTitle.weight(.semibold))

                Text("Monitor your system performance from the menu bar.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                OptionRow(
                    icon: "bolt.badge.clock",
                    title: "Launch at Login",
                    subtitle: "Keep iActivity running even after a restart.",
                    isOn: $launchAtLogin
                )
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 0)

            // `.borderedProminent` picks up the user's system accent colour. The hand-rolled
            // blue→purple gradient pill ignored it, and ignored the pressed and disabled states
            // a real button draws for free.
            Button {
                AppSetup.shared.isLaunchAtLoginEnabled = launchAtLogin
                UserDefaults.standard.set(showInDock, forKey: "showInDock")
                AppSetup.shared.setDockIconVisibility(showInDock)
                UserDefaults.standard.set(true, forKey: "hasFinishedOnboarding")

                AppSetup.shared.moveToApplicationsIfNeeded()

                onFinish()
            } label: {
                // The width has to go on the *label*. A button hugs its title and centres inside
                // whatever frame you give it — same trap as a segmented `Picker` (§ 14).
                Text("Get Started").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .padding(.top, 32)
        .frame(width: 400, height: 500)
        .background(VisualEffectView(material: .windowBackground, blendingMode: .behindWindow, cornerRadius: 16))
        .onExitCommand { onFinish() }
    }
}

struct OptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)

            SubtitleToggle(title: title, subtitle: subtitle, isOn: $isOn)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.tileRadius, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.tileRadius, style: .continuous)
                .strokeBorder(AppTheme.Colors.hairline(contrast), lineWidth: 1)
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        if cornerRadius > 0 {
            view.layer?.cornerRadius = cornerRadius
            view.layer?.cornerCurve = .continuous
            view.layer?.masksToBounds = true
        }
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        if cornerRadius > 0 {
            nsView.wantsLayer = true
            nsView.layer?.cornerRadius = cornerRadius
            nsView.layer?.cornerCurve = .continuous
            nsView.layer?.masksToBounds = true
        } else {
            nsView.layer?.cornerRadius = 0
            nsView.layer?.masksToBounds = false
        }
    }
}
