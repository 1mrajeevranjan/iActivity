import SwiftUI
import Charts

struct MiniHistoryChart: View {
    let data: [Double]
    let gradient: Gradient
    var domain: ClosedRange<Double>? = nil
    
    struct HistoricalData: Identifiable {
        let id = UUID()
        let index: Int
        let value: Double
    }
    
    private var chartData: [HistoricalData] {
        data.enumerated().map { (offset, element) in HistoricalData(index: offset, value: element) }
    }
    
    var body: some View {
        Chart(chartData) { item in
            AreaMark(
                x: .value("Time", item.index),
                y: .value("Value", item.value)
            )
            .foregroundStyle(LinearGradient(gradient: gradient, startPoint: .top, endPoint: .bottom).opacity(0.3))
            .interpolationMethod(.catmullRom)
            
            LineMark(
                x: .value("Time", item.index),
                y: .value("Value", item.value)
            )
            .foregroundStyle(LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing))
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: domain ?? (0...max(0.1, (data.max() ?? 1) * 1.1)))
        .frame(height: 100)
    }
}
