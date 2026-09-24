import SwiftUI

/// Compact process list: name left, reading right, a faint proportional bar behind each row.
/// No rank badges, no card of its own — it is a group inside the category's single card.
struct TopProcessesView: View {
    let processes: [ProcessMonitor.ProcessEntry]
    let metric: Metric
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Metric {
        case cpu
        case memory
        case disk
    }

    private var rows: [ProcessMonitor.ProcessEntry] { Array(processes.prefix(5)) }

    private func amount(_ process: ProcessMonitor.ProcessEntry) -> Double {
        switch metric {
        case .cpu: process.cpuPercent
        case .memory: process.memoryMB
        case .disk: process.diskBytesPerSecond
        }
    }

    /// Bars scale against the largest value **in the same unit**. Dividing every row by the top
    /// process's CPU percentage made the Memory list compare gigabytes to a percentage.
    private var peak: Double { max(rows.map(amount).max() ?? 0, .leastNonzeroMagnitude) }

    var body: some View {
        VStack(spacing: 2) {
            if rows.isEmpty && metric == .disk {
                // Unlike CPU, an idle disk genuinely has nothing to rank.
                Text("No disk activity")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            } else if rows.isEmpty {
                HStack {
                    Spacer()
                    ProgressView().controlSize(.small)
                    Spacer()
                }
                .frame(height: 56)
                .accessibilityLabel(Text("Loading processes"))
            } else {
                ForEach(rows) { process in
                    row(process)
                }
            }
        }
    }

    private func row(_ process: ProcessMonitor.ProcessEntry) -> some View {
        let display = switch metric {
        case .cpu: formatCPU(process.cpuPercent)
        case .memory: formatMemory(process.memoryMB)
        case .disk: formatRate(process.diskBytesPerSecond)
        }
        let fraction = amount(process) / peak

        return HStack(spacing: 8) {
            Text(process.name)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Text(display)
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(alignment: .leading) {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tint.opacity(0.13))
                    .frame(width: geo.size.width * CGFloat(min(max(fraction, 0), 1)))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: fraction)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(process.name))
        .accessibilityValue(Text(display))
    }

    private func formatCPU(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    private func formatRate(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000 { return String(format: "%.1f MB/s", bytesPerSecond / 1_000_000) }
        if bytesPerSecond >= 1_000 { return String(format: "%.0f KB/s", bytesPerSecond / 1_000) }
        return String(format: "%.0f B/s", bytesPerSecond)
    }

    private func formatMemory(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }
}
