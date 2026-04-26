import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @State private var launchAtLogin = AppSetup.shared.isLaunchAtLoginEnabled
    @State private var showInDock = UserDefaults.standard.bool(forKey: "showInDock")
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 12) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 80, height: 80)
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Text("Welcome to iActivity")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Text("Monitor your system performance beautifully from your menu bar.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Options
            VStack(spacing: 20) {
                OptionRow(
                    icon: "rocket.fill",
                    title: "Launch at Login",
                    subtitle: "Keep iActivity running even after a restart.",
                    isOn: $launchAtLogin
                )
                
            }
            .padding(.horizontal, 30)
            
            Spacer()
            
            // Action Button
            Button(action: {
                AppSetup.shared.isLaunchAtLoginEnabled = launchAtLogin
                UserDefaults.standard.set(showInDock, forKey: "showInDock")
                AppSetup.shared.setDockIconVisibility(showInDock)
                UserDefaults.standard.set(true, forKey: "hasFinishedOnboarding")
                
                // Also trigger move to applications check
                AppSetup.shared.moveToApplicationsIfNeeded()
                
                dismiss()
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .frame(width: 400, height: 500)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }
}

struct OptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(12)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(10)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
