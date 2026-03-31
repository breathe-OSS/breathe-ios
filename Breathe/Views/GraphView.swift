import SwiftUI
import Charts

struct GraphView: View {
    let history: [HistoryPoint]
    let isUsAqi: Bool
    
    @State private var selectedPoint: HistoryPoint?
    
    // Sort history by time just to be safe
    var sortedHistory: [HistoryPoint] {
        history.sorted { $0.ts < $1.ts }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("24-Hour Trend")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if sortedHistory.isEmpty {
                Text("No data available for the last 24 hours.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(sortedHistory, id: \.ts) { point in
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
                    
                    if let selected = selectedPoint {
                        let val = isUsAqi ? (selected.usAqi ?? selected.aqi) : selected.aqi
                        let date = Date(timeIntervalSince1970: TimeInterval(selected.ts))
                        
                        RuleMark(
                            x: .value("Time", date)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundStyle(Color.secondary)
                        .annotation(position: .top, spacing: 0) {
                            VStack(spacing: 4) {
                                Text("\(val)")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text(date, format: .dateTime.hour().minute())
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(chartCardBackground)
                                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                            )
                            .padding(.bottom, 8)
                        }
                        
                        PointMark(
                            x: .value("Time", date),
                            y: .value("AQI", val)
                        )
                        .symbolSize(80)
                        .foregroundStyle(Color.accentColor)
                        .annotation(position: .overlay) {
                            Circle()
                                .stroke(chartDotStrokeBackground, lineWidth: 2)
                                .frame(width: 10, height: 10)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                        AxisGridLine()
                        AxisTick()
                        // Ensure it fits and we show smaller text
                        if let _ = value.as(Date.self) {
                            AxisValueLabel(format: .dateTime.hour(), collisionResolution: .automatic)
                                .font(.system(size: 10))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXScale(range: .plotDimension(padding: 15))
                .frame(height: 160)
                .padding(.top, selectedPoint != nil ? 30 : 10)
                .padding(.bottom, 10)
                .animation(.easeInOut(duration: 0.1), value: selectedPoint != nil)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let locationX = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                        guard locationX >= 0, locationX <= proxy.plotAreaSize.width else { return }
                                        
                                        if let date: Date = proxy.value(atX: locationX) {
                                            selectedPoint = findClosestPoint(to: date, in: sortedHistory)
                                        }
                                    }
                                    .onEnded { _ in
                                        selectedPoint = nil
                                    }
                            )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
            .fill(chartCardBackground)
        )
    }

        private var chartCardBackground: Color {
    #if os(iOS)
        return Color(.secondarySystemBackground)
    #elseif os(macOS)
        return Color(nsColor: .windowBackgroundColor)
    #else
        return Color.gray.opacity(0.15)
    #endif
        }

        private var chartDotStrokeBackground: Color {
    #if os(iOS)
        return Color(.systemBackground)
    #elseif os(macOS)
        return Color(nsColor: .textBackgroundColor)
    #else
        return Color.white
    #endif
        }
    
    private func findClosestPoint(to date: Date, in history: [HistoryPoint]) -> HistoryPoint? {
        let targetTimestamp = date.timeIntervalSince1970
        return history.min(by: { a, b in
            abs(Double(a.ts) - targetTimestamp) < abs(Double(b.ts) - targetTimestamp)
        })
    }
}
