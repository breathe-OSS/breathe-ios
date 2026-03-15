import SwiftUI
import Charts

struct GraphView: View {
    let history: [HistoryPoint]
    let isUsAqi: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("24-Hour Trend")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if history.isEmpty {
                Text("No data available for the last 24 hours.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(history, id: \.ts) { point in
                    let value = isUsAqi ? (point.usAqi ?? point.aqi) : point.aqi
                    let date = Date(timeIntervalSince1970: TimeInterval(point.ts))
                    
                    LineMark(
                        x: .value("Time", date),
                        y: .value("AQI", value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    AreaMark(
                        x: .value("Time", date),
                        y: .value("AQI", value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.4), Color.accentColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                        AxisGridLine()
                        AxisTick()
                        if let date = value.as(Date.self) {
                            AxisValueLabel(format: .dateTime.hour(), collisionResolution: .disabled)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 250)
                .padding(.vertical, 10)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
