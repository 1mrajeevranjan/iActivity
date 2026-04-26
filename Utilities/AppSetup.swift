import Foundation
import AppKit
import ServiceManagement

@MainActor
class AppSetup {
    static let shared = AppSetup()
    
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
                print("Failed to update launch at login status: \(error)")
            }
        }
    }
    
    // MARK: - Move to Applications
    
    func moveToApplicationsIfNeeded() {
        let bundlePath = Bundle.main.bundlePath
        
        // Check if we're already in /Applications or /Users/shared/Applications etc.
        if bundlePath.hasPrefix("/Applications") || bundlePath.hasPrefix("/Users/\(NSUserName())/Applications") {
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Move to Applications?"
        alert.informativeText = "iActivity works best when installed in your Applications folder. This will also make it appear in Launchpad."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Stay in Downloads")
        
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
