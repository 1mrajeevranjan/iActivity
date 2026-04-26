import SwiftUI

struct NetworkView: View {
    @Environment(SystemMonitor.self) private var monitor
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Real-time Speed")
                    .font(.headline)
                
                HStack(spacing: AppTheme.Spacing.medium) {
                    SpeedIndicator(label: "Download", speed: monitor.network.downloadSpeed, color: .blue, icon: "arrow.down")
                    SpeedIndicator(label: "Upload", speed: monitor.network.uploadSpeed, color: .green, icon: "arrow.up")
                }
            }
            .liquidGlass()
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Traffic History")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    Text("Download History").font(.caption).foregroundStyle(.secondary)
                    MiniHistoryChart(data: normalize(monitor.network.downloadHistory), gradient: Gradient(colors: [.blue, .cyan]))
                    
                    Text("Upload History").font(.caption).foregroundStyle(.secondary)
                    MiniHistoryChart(data: normalize(monitor.network.uploadHistory), gradient: Gradient(colors: [.green, .mint]))
                }
            }
            .liquidGlass()
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Connection Info")
                    .font(.headline)
                
                DetailRow(label: "Interface", value: "en0 (Wi-Fi)")
                DetailRow(label: "IP Address", value: "192.168.1.15") // Placeholder
            }
            .liquidGlass()
            
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                Text(label).font(.caption2)
            }
            .foregroundStyle(.secondary)
            
            Text(formatSpeed(speed))
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
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
