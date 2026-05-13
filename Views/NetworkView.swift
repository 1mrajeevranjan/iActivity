import SwiftUI

struct NetworkView: View {
    @Environment(SystemMonitor.self) private var monitor
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            HStack(spacing: AppTheme.Spacing.medium) {
                SpeedIndicator(label: "Download", speed: monitor.network.downloadSpeed, color: .blue, icon: "arrow.down.circle.fill")
                    .vibrantCard()
                SpeedIndicator(label: "Upload", speed: monitor.network.uploadSpeed, color: AppTheme.Colors.batteryGreen, icon: "arrow.up.circle.fill")
                    .vibrantCard()
            }
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Traffic History")
                    .font(.headline)
                
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Download").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                        MiniHistoryChart(data: normalize(monitor.network.downloadHistory), gradient: Gradient(colors: [.blue, .cyan]))
                            .frame(height: 50)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Upload").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                        MiniHistoryChart(data: normalize(monitor.network.uploadHistory), gradient: Gradient(colors: [AppTheme.Colors.batteryGreen, .mint]))
                            .frame(height: 50)
                    }
                }
            }
            .vibrantCard()
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Connection")
                    .font(.headline)
                
                DetailRow(label: "Interface", value: "Wi-Fi (en0)")
                DetailRow(label: "Status", value: "Connected")
            }
            .vibrantCard()
            
            TopProcessesView(
                title: "Most Active Processes",
                processes: monitor.processes.topByCPU,
                metric: .cpu,
                color: AppTheme.Colors.accentColor(for: .network)
            )
        }
    }
    
    private func normalize(_ data: [Double]) -> [Double] {
        let maxVal = data.max() ?? 1.0
        if maxVal == 0 { return data }
        return data.map { $0 / maxVal }
    }
}

struct SpeedIndicator: View {
    let label: String
    let speed: Double
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 12, weight: .bold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            Text(formatSpeed(speed))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_000_000)
        } else if bytesPerSecond >= 1_000 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1_000)
        } else {
            return String(format: "%.0f B/s", bytesPerSecond)
        }
    }
}
