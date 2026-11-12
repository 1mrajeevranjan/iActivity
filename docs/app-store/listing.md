# iActivity — Mac App Store listing (v1.0)

Paste-ready fields for App Store Connect. Character counts verified.

## Indexed fields (drive search)

| Field | Value | Count / limit |
|---|---|---|
| Name | `iActivity: System Monitor` | 25 / 30 |
| Subtitle | `CPU, GPU & Temps in Menu Bar` | 28 / 30 |
| Keywords | `stats,ram,memory,battery,network,disk,temperature,usage,performance,activity,thermal,cores,health` | 97 / 100 bytes |

Rules applied: no word repeated across name, subtitle and keywords (Apple indexes each once);
commas, no spaces; no competitor brands (iStat, Stats) and no "Apple"/"Mac" trademarks; no
"fan" because the app has no fan readout.

Why these terms:
- **system monitor** — head term every competitor (Pulse, iStat Menus, MenuBar Stats) ranks on; it goes in the name, where it carries the most weight.
- **cpu / gpu / temps / menu bar** — the high-intent modifiers people add to "system monitor". The subtitle carries them.
- **ram, memory, battery, health, disk, network** — each one is a category tab users search for on its own ("battery health mac").
- **thermal, temperature** — both spellings. A competitor's listing says sandboxed apps can't read temperatures; we can, so it's a differentiator.
- **performance, cores, usage, stats, activity** — long-tail ("cpu usage", "performance cores", "activity monitor alternative").

## Category

- Primary: **Utilities**
- Secondary: **Developer Tools**

## Price

Free. Every App Store competitor charges $2.99–$11.99, so "Free" goes in the promo text and in the first screenshot.

## Promotional text (170 max, not indexed, editable without a release)

```
Free, native and power-aware. Pin any mix of CPU, GPU, memory, disk, battery and network to your menu bar, each with its own live mini chart.
```
(141 chars)

## Description (not indexed — written for conversion; first 3 lines show before "more")

```
Your whole Mac, one menu bar icon. iActivity puts live CPU, GPU, memory, disk, battery and network stats in your menu bar, and opens a native dashboard with one click.

Built for Apple silicon, light on battery, and free.

SIX LIVE CATEGORIES
• CPU: overall load plus Performance and Efficiency clusters read separately, with per-core bars
• GPU: utilization and history
• Memory: usage, pressure and swap
• Disk: capacity, read and write speed
• Battery: charge, health, cycle count and power draw
• Network: live upload and download speed

TEMPERATURES
Real-time temperature for CPU, GPU, memory, disk and battery, in Celsius or Fahrenheit.

YOUR MENU BAR, YOUR WAY
• Show any combination of categories at once, not just one
• Each category gets its own live mini chart
• Line, area, bar or stepped charts, applied everywhere

FEELS LIKE PART OF macOS
• Drops down from the menu bar with a pointed popover, like Control Center
• Frosted glass that follows Light, Dark or Auto appearance
• VoiceOver, Reduce Motion, Reduce Transparency, Increase Contrast and Full Keyboard Access supported

POWER-AWARE
When the dashboard is closed, iActivity pauses every category you haven't pinned to the menu bar. One pinned category costs a fraction of a percent of CPU.

PRIVATE
No accounts, no analytics, no network connections. Everything is read on your Mac and stays there.

Requires macOS 26 Tahoe or later.
```

## What's New (1.0)

```
First release. Six live categories, multi-category menu bar with mini charts, temperatures, four chart styles and Launch at Login.
```

## Screenshots (2880×1800, 16:10; first 3 show in search results)

Captions are indexed (since June 2025), so they reuse the search terms. Format: bold caption on top, real UI underneath, desktop wallpaper behind it.

| # | Caption | Shows |
|---|---|---|
| 1 | **Your whole Mac. One menu bar icon.** | Menu bar with 3–4 pinned categories + CPU dashboard open |
| 2 | **CPU & GPU monitor for Apple silicon** | CPU tab, Performance/Efficiency clusters, cores expanded |
| 3 | **Live temperatures, °C or °F** | GPU or CPU tab with Temp tile visible |
| 4 | **Battery health, cycles & power draw** | Battery tab |
| 5 | **Memory pressure, swap & disk speed** | Memory tab |
| 6 | **Network speed at a glance** | Network tab |
| 7 | **Pin any mix to your menu bar** | Settings → Menu bar categories + menu bar strip |
| 8 | **Light, Dark & four chart styles** | Split light/dark dashboard |

No preview video for v1 (optional). If one is added later, use the existing `videos/iactivity-promo` cut, trimmed to 15–30 s.

## App Privacy (nutrition label)

Answer "Data Not Collected". The app makes no network calls and ships `PrivacyInfo.xcprivacy` declaring no collected data.

## URLs

- Support URL: `https://github.com/1mrajeevranjan/iActivity/issues`
- Privacy Policy URL: `https://github.com/1mrajeevranjan/iActivity/blob/main/PRIVACY.md`
- Marketing URL (optional): `https://github.com/1mrajeevranjan/iActivity`

(The repo must be public for these links to work. Otherwise host PRIVACY.md somewhere public.)

## App Review notes (paste into "Notes")

```
iActivity is a menu bar system monitor. Click the menu bar icon to open the dashboard; right-click for Settings and Quit.

Entitlement com.apple.security.temporary-exception.iokit-user-client-class = AppleSMCClient:
used read-only to read temperature sensor keys from the System Management Controller, which is the only source of CPU/GPU/SSD temperatures on macOS. The app only issues read commands (key info and read-bytes). It never writes SMC keys and never changes fan or power settings. Without the entitlement, temperature readings show "—" and everything else still works.

The app makes no network connections and collects no data.
```

## Age rating

Fill in "None" for every question → 4+.

## After launch

- Ask for a review with `SKStoreReviewController` after about a week of use (3 prompts per year max). With 0 ratings, getting the first 10–20 matters most.
- Rewrite the promotional text with each release. It can change without review.
- Publish an In-App Event for major feature drops (events are indexed in search).
