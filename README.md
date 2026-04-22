# iActivity

A premium, minimalist macOS system monitor featuring a stunning **Liquid Glass HUD**, real-time activity tracking, and a **native macOS squircle design**. Built with Swift and SwiftUI for maximum performance and a premium aesthetic.

![iActivity Preview](icon.png)

## Core Features

- **Liquid Glass UI**: A beautiful, translucent HUD that floats on your desktop, providing a modern alternative to cluttered system monitors.
- **Native Squircle Design**: A redesigned category picker featuring unified **macOS-style squircles** (continuous rounded rectangles) for a premium, system-native look and feel.
- **Full Thermal Monitoring**: Real-time temperature readings for every critical component:
  - **CPU & GPU**: Precise die temperatures for performance tracking.
  - **SoC (Memory)**: Monitor the substrate temperature of the Apple Silicon chip.
  - **SSD**: Real-time NVMe storage temperature.
  - **Battery**: Thermal tracking for energy health.
- **Top 5 Resource Monitoring**: Real-time identification of the most resource-intensive processes across all categories (CPU, RAM, GPU, Disk, Network).
- **Enhanced Menu Bar**: Quick-glance metrics featuring both the **activity level** and the **component temperature** (e.g., `52° 34%`) right in your system menu bar.
- **Native Performance**: Uses low-level macOS kernel APIs (`libproc`, `IOKit`, `SMC`) to fetch system data with minimal overhead.

## How to Use

### Installation
1. Locate the `iActivity.app` bundle in the project root.
2. Drag **iActivity** to your **Applications** folder.
3. Launch the app from your Applications folder or via Spotlight.

### Navigation
- **HUD Panel**: The main dashboard displays a live history chart, component-specific details (including real-time temperature), and a list of the top 5 most active processes.
- **Switching Categories**: Click the icons at the top of the HUD to switch between CPU, GPU, Memory, etc. The menu bar will automatically update to reflect the selected category.
- **Menu Bar**: Displays the icon, current temperature, and activity level for the selected category. Click the icon to toggle the dashboard visibility.

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
