# iActivity

A premium, minimalist macOS system monitor featuring a stunning **Liquid Glass HUD** and real-time activity tracking. Built with Swift and SwiftUI for maximum performance and a native aesthetic.

![iActivity Preview](icon.png)

## Core Features

- **Liquid Glass UI**: A beautiful, translucent HUD that floats on your desktop, providing a modern alternative to cluttered system monitors.
- **Top 5 Resource Monitoring**: Real-time identification of the most resource-intensive processes for:
  - **CPU**: Performance cores and load balancing.
  - **Memory (RAM)**: Visual composition (Wired, Active, Compressed, Free).
  - **GPU**: Graphics utilization metrics.
  - **Disk**: SSD health and throughput.
  - **Network**: Live upload and download tracking.
  - **Battery**: Energy impact and health stats.
- **Native Performance**: Uses low-level macOS kernel APIs (`libproc`) to fetch system data with minimal overhead.
- **Menu Bar Integration**: Quick-glance metrics right in your system menu bar.

## How to Use

### Installation
1. Download the latest `iActivity.dmg`.
2. Open the DMG and drag **iActivity** to your **Applications** folder.
3. Launch the app from your Applications folder or via Spotlight.

### Navigation
- **HUD Panel**: The main dashboard displays a live history chart and a list of the top 5 most active processes for the selected category.
- **Switching Categories**: Click the icons at the top of the HUD to switch between CPU, GPU, Memory, etc.
- **Menu Bar**: Click the iActivity icon in your menu bar to toggle the dashboard visibility.

## Building from Source

If you prefer to build the tool yourself:

```bash
# Clone the repository
git clone https://github.com/1mrajeevranjan/iActivity.git

# Navigate to the project
cd iActivity

# Build and run
swift run
```

### Requirements
- macOS 14.0 or later
- Xcode 15.0+ (for building)

## License
Created by Rajeev Ranjan. All rights reserved.
