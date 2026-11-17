import Foundation
import AppKit
import ServiceManagement
import OSLog

@MainActor
class AppSetup {
    static let shared = AppSetup()
    private static let log = Logger(subsystem: "com.rajeev.iActivity", category: "AppSetup")

    /// True in the Mac App Store build. The sandbox denies reading other processes' usage and
    /// writing to /Applications, so features that need either hide themselves instead of failing.
    nonisolated static let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil

    // MARK: - Launch at Login
    
    var isLaunchAtLoginEnabled: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                Self.log.error("Failed to update launch at login: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    // MARK: - Move to Applications
    
    func moveToApplicationsIfNeeded() {
        guard !Self.isSandboxed else { return }
        let bundlePath = Bundle.main.bundlePath
        
        // Check if we're already in /Applications or /Users/shared/Applications etc.
        if bundlePath.hasPrefix("/Applications") || bundlePath.hasPrefix("/Users/\(NSUserName())/Applications") {
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Move to Applications?"
        alert.informativeText = "iActivity works best when installed in your Applications folder. This will also make it appear in Launchpad."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not Now")
        // NSAlert only auto-binds Esc to a button titled exactly "Cancel" — neither button
        // here qualifies, so Esc silently did nothing. Bind it explicitly to the safe,
        // non-destructive choice.
        alert.buttons[1].keyEquivalent = "\u{1b}"

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let fileManager = FileManager.default
            let targetURL = URL(fileURLWithPath: "/Applications").appendingPathComponent(URL(fileURLWithPath: bundlePath).lastPathComponent)
            
            do {
                if fileManager.fileExists(atPath: targetURL.path) {
                    try fileManager.removeItem(at: targetURL)
                }
                
                // Copy ourselves to /Applications
                try fileManager.copyItem(at: URL(fileURLWithPath: bundlePath), to: targetURL)
                
                // Relaunch from new location
                let configuration = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: targetURL, configuration: configuration) { _, error in
                    if error == nil {
                        Task { @MainActor in
                            NSApplication.shared.terminate(nil)
                        }
                    }
                }
            } catch {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Could not move to Applications"
                errorAlert.informativeText = error.localizedDescription
                errorAlert.runModal()
            }
        }
    }
    
    // MARK: - Dock Icon Toggle
    
    func setDockIconVisibility(_ visible: Bool) {
        if visible {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
