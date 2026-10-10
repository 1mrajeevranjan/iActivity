import AppKit
import Darwin
import SwiftUI
import Testing
@testable import iActivity

@MainActor
struct PerformanceTests {
    // ponytail: opt-in native counters, rather than timing assertions that fail under system load.
    // Run: IACTIVITY_BENCHMARK=1 swift test -c release --filter PerformanceTests
    @Test(.enabled(if: ProcessInfo.processInfo.environment["IACTIVITY_BENCHMARK"] == "1"))
    func resourceUsage() async throws {
        _ = NSApplication.shared
        let domain = "iActivity.performance.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defaults.set("cpu", forKey: MenuBarSelection.storageKey)
        defaults.set("cpu", forKey: "selectedCategory")
        defaults.set("area", forKey: "chartStyle")
        defaults.set(false, forKey: "showTemperature")
        let monitor = SystemMonitor()
        monitor.applyInterval(1)
        let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: AppTheme.Panel.windowWidth, height: 750),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let anchor = PanelAnchor()
        anchor.maxCardHeight = 900
        anchor.onContentHeightChange = { height in
            window.setContentSize(CGSize(width: AppTheme.Panel.windowWidth, height: height + 22))
        }
        defer {
            window.contentView = nil
            window.close()
            monitor.stop()
            defaults.removePersistentDomain(forName: domain)
        }

        func snapshot() throws -> rusage_info_v4 {
            var usage = rusage_info_v4()
            let result = withUnsafeMutablePointer(to: &usage) { pointer in
                pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0)
                }
            }
            #expect(result == 0)
            return usage
        }
        for dashboard in [false, true] {
            if dashboard {
                monitor.resumeAll()
                monitor.applyInterval(1)
                let hosting = NSHostingView(rootView: MainDashboardView().environment(monitor).environment(anchor)
                    .defaultAppStorage(defaults))
                hosting.sizingOptions = []
                window.contentView = hosting
            } else {
                let hosting = NSHostingView(rootView: MenuBarLabel(monitor: monitor).defaultAppStorage(defaults))
                hosting.sizingOptions = [.intrinsicContentSize]
                window.contentView = hosting
            }
            window.orderFront(nil)
            try await Task.sleep(for: .seconds(4))
            let before = try snapshot()
            var posixBefore = rusage()
            getrusage(RUSAGE_SELF, &posixBefore)
            let start = ProcessInfo.processInfo.systemUptime
            try await Task.sleep(for: .seconds(20))
            let elapsed = ProcessInfo.processInfo.systemUptime - start
            let after = try snapshot()
            var posixAfter = rusage()
            getrusage(RUSAGE_SELF, &posixAfter)
            let wakeups = Double(after.ri_interrupt_wkups - before.ri_interrupt_wkups) / elapsed
            let memory = Double(after.ri_phys_footprint) / 1_048_576
            let written = after.ri_diskio_byteswritten - before.ri_diskio_byteswritten
            func seconds(_ usage: rusage) -> Double {
                Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
                    + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1e6
            }
            let cpu = (seconds(posixAfter) - seconds(posixBefore)) / elapsed * 100
            print(String(format: "RESOURCE %@ cpu=%.3f%% footprint=%.2fMiB wakeups=%.2f/s writes=%lluB",
                         dashboard ? "dashboard" : "menu", cpu, memory, wakeups, written))
        }
    }
}
