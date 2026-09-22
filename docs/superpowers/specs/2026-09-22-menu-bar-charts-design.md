# Menu bar charts, chart styles, and multi-category menu bar

Date: 2026-09-22
Status: approved, not yet implemented

## Problem

Three requests, one underlying change:

1. The dashboard can only draw a line sparkline. The user wants an area chart plus a
   few more styles, chosen in Settings.
2. The menu bar shows numbers only. The user wants a graph there too.
3. The menu bar shows exactly one category. The user wants several at once — CPU, GPU,
   memory, network, disk together.

None of this may regress what already ships.

## What the code actually looks like today

Two findings shaped the whole design and are worth recording, because neither is
obvious from the file names:

- **`Views/MenuBarLabel.swift` is dead code.** It is a complete SwiftUI view of the menu
  bar readout that nothing references. The menu bar is really drawn by
  `AppDelegate.updateMenuBarDisplay()` in AppKit, as `button.attributedTitle` plus an
  SF Symbol in `button.image`. Anyone reaching for "the menu bar view" will edit the
  wrong file.
- **`selectedCategory` means two different things at once.** It is the dashboard's
  selected tab (`MainDashboardView`) *and* the menu bar's category
  (`updateMenuBarDisplay`) *and* the input to the power policy
  (`SystemMonitor.pauseBackground`, which stops every monitor except that one while the
  panel is closed). That single key is why the README can claim idle CPU of "a fraction
  of a percent".

Every monitor already keeps a 60-sample history buffer (`cpu.history`,
`memory.usageHistory`, `network.downloadHistory`, …), so the data for menu bar charts
exists and needs no new collection.

## Decisions

| Decision | Choice | Why |
| --- | --- | --- |
| Menu bar layout | **One status item** holding a strip of categories | `PanelManager` anchors the popover's beak to a single `statusItem.button`. N status items make that anchor ambiguous and put the app's most delicate, test-covered code (`PanelPlacementTests`) at risk for a cosmetic gain. |
| Menu bar rendering | **Host SwiftUI** in the status button | Gives **one** chart renderer shared by dashboard and menu bar. The AppKit alternative needs every chart style written twice — once in SwiftUI, once in Core Graphics — and kept in sync forever. |
| Chart styles | Line (default), Area, Bars, Stepped | Dots rejected: 60 samples in a 34pt row is mush. Candlestick rejected: needs OHLC data the monitors do not collect. |
| Tab ↔ menu bar coupling | **Decoupled** | Today, clicking a dashboard tab rewrites the menu bar. Once the menu bar holds a configured set, browsing tabs must not wipe it. |

## Architecture

```
AppTheme.swift
  ├─ ChartStyle           (new, @AppStorage "chartStyle")
  └─ MenuBarSelection     (new, @AppStorage "menuBarCategories")
                                  │
Sparkline.swift ──────────────────┤ reads ChartStyle
  │  one renderer, four styles    │
  ├──────────────► MetricRow ─────┴──► dashboard cards
  └──────────────► MenuBarLabel ──────► NSHostingView in statusItem.button

SystemMonitor.pauseBackground() ──► reads MenuBarSelection (was: selectedCategory)
```

### 1. `ChartStyle`

Lives in `Theme/AppTheme.swift` beside the other `@AppStorage`-backed enums
(`AppearanceMode`, `TemperatureUnit`, `RefreshInterval`), matching their shape:
`String`-backed, `CaseIterable`, `Identifiable`, with a `title` for the picker.

```
case line     // current: stroke + faint gradient wash
case area     // same polyline, filled to the baseline
case bars     // one column per sample
case stepped  // staircase; holds each value until it changes
```

### 2. `Sparkline`

Gains style-aware path construction. `.line` reproduces today's output exactly, so the
dashboard is unchanged until the user opts in.

`Sparkline` reads `@AppStorage("chartStyle")` itself rather than taking it as a
parameter, so **none of its existing call sites change**. It also accepts an optional
override, which the menu bar uses for its own smaller geometry.

The existing `domain` / auto-scale logic is untouched — it is shared by all four styles.

### 3. `MenuBarLabel` — from dead code to the live view

Rewritten as the real menu bar strip and hosted in `statusItem.button` via
`NSHostingView`. It renders, per selected category, in `MetricCategory.allCases` order:

`[temperature] [value] [mini chart] [SF Symbol]`

Everything `updateMenuBarDisplay()` does today must be carried over verbatim — this is
the regression surface and is enumerated below.

The mini chart draws **28×12pt from the last 24 samples**, not all 60 — the full buffer
is illegible at that width. It uses the **same `ChartStyle` as the dashboard** (picking
"Area" changes both surfaces); only the geometry differs, which is what the override
parameter is for.

**Hosting mechanics.** `statusItem.length` must be recomputed from the hosting view's
fitting size whenever the content's width changes — network's `↓42.1M ↑1.2M` is far
wider than `4%`, and a stale length either clips the strip or leaves dead space. Clicks
must still reach the `NSStatusBarButton`, so the hosting view overrides
`hitTest(_:)` to return `nil`. `button.attributedTitle` and `button.image` must be
cleared, or they will draw underneath the hosting view.

### 4. `MenuBarSelection` + migration

`@AppStorage` cannot store a `Set`, so a small `RawRepresentable` wrapper stores the
categories as a comma-joined string of raw values.

- **Migration:** when the key is absent, seed from the existing `selectedCategory`. An
  existing install therefore looks *identical* after upgrade.
- **One accessor, not two.** `SystemMonitor` reads `UserDefaults` directly while the
  views use `@AppStorage`; if each implements the seed-and-fallback rule separately they
  will drift. A single `static var current` on `MenuBarSelection` owns migration, the
  empty-set fallback, and unknown-raw-value tolerance, and **both** paths call it.
- **Empty-set guard:** a user can untick all six. The **authoritative** guard is in
  `MenuBarSelection.current`, which falls back to the dashboard category so the status
  item can never be zero-width and unclickable. Settings disabling the last toggle is a
  UI affordance on top, not the safety net.
- **Order:** always rendered in `MetricCategory.allCases` order, not tick order, so the
  strip is stable and predictable.

### 5. Power policy

`SystemMonitor.pauseBackground()` changes from "keep one monitor alive" to "keep the
selected set alive". The process scanner stays paused, unchanged — it is the expensive
one.

**Stated cost:** idle work now scales with the number of pinned categories. Showing all
five roughly quintuples the background cost the README describes as "a fraction of a
percent". This is the direct, unavoidable price of the feature, not a defect.

### 6. Settings

The single "Menu Bar Shows" picker is replaced by six category toggles. Added: a chart
style picker (Display section) and a "Show Graph in Menu Bar" toggle (Monitoring
section, default **on** — it is the headline feature, and it is a visible change on
upgrade).

## Regression surface — must survive the rewrite

`updateMenuBarDisplay()` carries behaviour that is easy to drop when porting to SwiftUI:

- Warning/critical thresholds and colours, which differ per category: CPU and GPU
  warn ≥0.70 / critical ≥0.90; memory ≥0.75 / ≥0.90; disk ≥0.85 / ≥0.95; battery
  ≤20% / ≤10% **and only when not charging**.
- Battery icon variants: `battery.100.bolt` when charging, then `.100 / .75 / .50 /
  .25 / .0` by level.
- `showTemperature` toggle; the `temp > 0` guard; network having no sensor at all.
- Temperature unit conversion at 0 decimals.
- Network's own compact formatter (`%.1fM` / `%.0fK` / `%.0fB`), which is *not* the same
  as the dashboard's `MB/s` formatter.
- Monospaced digits, so the strip does not jitter as values change.
- `labelColor`, deliberately not `secondaryLabelColor` — there is a comment in the
  source explaining that the dimmer tone disappears against a translucent menu bar.
- Left-click toggles the panel, right-click opens the menu
  (`sendAction(on: [.leftMouseUp, .rightMouseUp])`).
- `PanelManager` anchoring off `statusItem.button.window.frame`.

## Testing

Existing `AppThemeTests`, `PanelPlacementTests`, `TemperatureUnitTests` must stay green.

New:
- `ChartStyle` raw-value round-trip and `allCases` coverage.
- `MenuBarSelection` encode/decode, unknown-raw-value tolerance, empty-string handling,
  and migration seeding from `selectedCategory`.
- Threshold classification (value → normal/warning/critical per category) extracted to a
  pure function so it can be tested without a status bar.

## Out of scope

Per-category click targets inside the strip; ⌘-draggable independent status items;
user-defined chart colours; configurable history window; chart styles that need data the
monitors do not collect.

---

## Addendum — P/E core utilisation (added during implementation)

A fourth request arrived with the go-ahead: the CPU representation must show performance and
efficiency core utilisation.

The data was collectable but not collected. `CPUMonitor` had `coreUsages` and
`efficiencyCoreCount` but only ever averaged *every* core into one `usage` — which is precisely
the number that hides the split, since four pinned P-cores and six idle E-cores average to a
middling figure describing neither cluster.

Added: `performanceUsage` / `efficiencyUsage` and their own history buffers, fed by
`clusterAverages(coreUsages:efficiencyCoreCount:)` — `nonisolated` and pure, so the split is
tested without a Mach call. The kernel reports efficiency cores first, the same convention
`coreKind(at:)` already relied on, and the count is clamped because it comes from a sysctl that
need not agree with the core list. `hasCoreSplit` gates all of it: Intel reports no clusters and
drawing a split there would invent a distinction the hardware does not make.

Surfaced in two places, both of which required `Sparkline` to accept a second series:

- **Dashboard** — `CoreClusterRow`: both readings side by side over one shared chart. Two
  separate `MetricRow`s would say the same thing at twice the height, and the comparison is the
  point. A coloured dot precedes each label, so colour is never the only carrier of meaning.
- **Menu bar** — the CPU segment's mini chart draws P and E as two series on one scale. Scaling
  them independently would render an idle efficiency cluster as busy as a pinned performance one.

## Implementation notes — two things the design did not predict

**The status item sized itself to nothing.** Pinning the hosting view to the button's four edges
makes `fittingSize` report the *button's* width, which is itself whatever `statusItem.length` was
last set to. The loop resolves to zero and leaves an invisible, unclickable item. The hosting view
must size from its own content and drive the length, not inherit it.

**The strip is wide.** One category with temperature, value, chart and icon measures ~121pt. Five
would approach 600pt, and on a notched Mac macOS moves the overflow into its hidden section — so
the strip can be configured into invisibility. The "Show Temperature" and "Show Graph" toggles are
the mitigation, and the category set is the real control.


## Addendum — cluster names follow the chip (added after the first build)

Asked for: M5 reportedly names its cores differently from M4, so labels should match the detected
CPU and fall back to Apple's standard names on older chips.

Rejected the obvious implementation. A `chip → core name` table would need M5's naming guessed at
today and corrected with every future generation — and would be wrong the moment Apple shipped
something unanticipated.

macOS already answers the question. `hw.nperflevels` gives the cluster count and
`hw.perflevelN.name` gives each cluster's name, as the kernel names it on the machine actually
running. On this M4: `perflevel0 = Performance` (4 cores), `perflevel1 = Efficiency` (6). Reading
those means the labels are right on every chip, past and future, with no table to maintain.

Two things were verified empirically rather than assumed:

- **Enumeration order.** The existing code assumed efficiency cores are enumerated first, which
  matters because `clusterAverages` splits the core list at that index — if it were backwards, the
  P/E split shipped in the previous commit would have been reporting each cluster as the other.
  Saturating four threads and sampling `host_processor_info` showed indices 6–9 pegged and 0–5
  idling, i.e. the 6 Efficiency cores come first. The assumption holds, and the display order is
  the **reverse** of the perflevel index order.
- **The sysctl keys themselves.** A mistyped key would return nil and silently degrade every Mac
  to `Core N` while every pure unit test still passed, so `LiveCoreClusterTests` reads the machine
  running the suite. It no-ops where no clusters are reported.

Labels are cluster-relative and one-based (`E-Core 1…6`, then `P-Core 1…4`), which also fixed a
pre-existing off-by-one that numbered Intel's cores from zero. Short forms are derived from the
reported name's initial, falling back to the full names if two clusters ever share one. A chip
reporting three or more clusters still labels every core from its own cluster's name; only the
tint grouping stays binary.
