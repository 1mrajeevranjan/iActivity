import Testing
import SwiftUI
@testable import iActivity

struct MetricCategoryTests {
    @Test("There are exactly the six dashboard tabs, in the expected order")
    func allCasesAreExpected() {
        #expect(MetricCategory.allCases == [.cpu, .gpu, .memory, .disk, .battery, .network])
    }

    @Test("Every category has a non-empty icon and short title", arguments: MetricCategory.allCases)
    func everyCategoryHasIconAndShortTitle(category: MetricCategory) {
        #expect(!category.icon.isEmpty)
        #expect(!category.shortTitle.isEmpty)
    }

    @Test("id matches rawValue, so AppStorage round-trips correctly")
    func idMatchesRawValue() {
        for category in MetricCategory.allCases {
            #expect(category.id == category.rawValue)
        }
    }

    @Test("Short titles are unique — the tab bar and menu bar picker rely on this to disambiguate")
    func shortTitlesAreUnique() {
        let titles = MetricCategory.allCases.map(\.shortTitle)
        #expect(Set(titles).count == titles.count)
    }
}

struct AppearanceModeTests {
    @Test("Light and dark map to their SwiftUI ColorScheme; auto maps to nil (follow system)")
    func colorSchemeMapping() {
        #expect(AppearanceMode.light.colorScheme == .light)
        #expect(AppearanceMode.dark.colorScheme == .dark)
        #expect(AppearanceMode.auto.colorScheme == nil)
    }

    @Test("id matches rawValue for AppStorage round-tripping")
    func idMatchesRawValue() {
        for mode in AppearanceMode.allCases {
            #expect(mode.id == mode.rawValue)
        }
    }
}

struct RefreshIntervalTests {
    @Test("Presets are ordered fast < normal < slow")
    func presetsAreOrdered() {
        #expect(RefreshInterval.fast.rawValue < RefreshInterval.normal.rawValue)
        #expect(RefreshInterval.normal.rawValue < RefreshInterval.slow.rawValue)
    }

    @Test("All presets are positive — a zero or negative interval would spin the monitor timers")
    func presetsArePositive() {
        for interval in RefreshInterval.allCases {
            #expect(interval.rawValue > 0)
        }
    }
}

struct CategoryKeyboardNavigationTests {
    @Test("Right arrow advances one tab, left arrow goes back one")
    func steppingMovesOneTab() {
        #expect(MetricCategory.stepping(from: .cpu, by: 1) == .gpu)
        #expect(MetricCategory.stepping(from: .gpu, by: -1) == .cpu)
    }

    @Test("Stepping wraps at both ends so the tab bar has no dead edges")
    func steppingWraps() {
        #expect(MetricCategory.stepping(from: .cpu, by: -1) == .network)
        #expect(MetricCategory.stepping(from: .network, by: 1) == .cpu)
    }

    @Test("Command-N maps to the Nth tab, one-based, and nothing outside that range")
    func commandDigitSelectsNthTab() {
        #expect(MetricCategory.at(oneBasedIndex: 1) == .cpu)
        #expect(MetricCategory.at(oneBasedIndex: 6) == .network)
        #expect(MetricCategory.at(oneBasedIndex: 0) == nil)
        #expect(MetricCategory.at(oneBasedIndex: 7) == nil)
    }

    @Test("Display names are unique and read as prose, not as the all-caps tab labels")
    func displayNamesAreDistinct() {
        let names = MetricCategory.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
        #expect(MetricCategory.memory.displayName == "Memory")
        #expect(MetricCategory.battery.displayName == "Battery")
    }
}
