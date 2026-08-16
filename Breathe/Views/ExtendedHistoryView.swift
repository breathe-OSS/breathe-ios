// SPDX-License-Identifier: MIT
/*
 * ExtendedHistoryView.swift
 *
 * Copyright (C) 2026 The Breathe Open Source Project
 * Copyright (C) 2026 sidharthify <wednisegit@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import SwiftUI
import Charts

struct ExtendedHistoryView: View {
    let zoneName: String
    let nodeKeys: [String]

    @EnvironmentObject private var viewModel: BreatheViewModel
    @Environment(\.dismiss) private var dismiss

    private let pm25Color = Color(red: 168/255, green: 199/255, blue: 250/255)
    private let pm10Color = Color(red: 216/255, green: 180/255, blue: 254/255)
    private let pm25SelectedColor = Color(red: 59/255, green: 110/255, blue: 220/255)
    private let pm10SelectedColor = Color(red: 140/255, green: 70/255, blue: 210/255)

    @State private var selectedDataPoint: HistoricalDataPoint? = nil
    @State private var chartPage = 0

    private var weatherHistory: WeatherHistory? {
        viewModel.historyState.weatherHistory
    }

    private var weatherGroups: [String: (sum: Double, count: Int)] {
        weatherPm25Groups(data: viewModel.historyState.data, weather: weatherHistory)
    }

    private var filteredData: [HistoricalDataPoint] {
        filterHistoryByWeather(
            data: viewModel.historyState.data,
            weather: weatherHistory,
            filter: viewModel.historyState.weatherFilter
        )
    }

    private var impactCards: [WeatherPm25Group] {
        weatherImpactCards(data: viewModel.historyState.data, weather: weatherHistory)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                controlsBar
                rangeSelector
                weatherSection
                if let stats = viewModel.historyState.stats {
                    statsPanel(stats: stats)
                }
                chartSection
                downloadButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .navigationTitle("\(zoneName) History")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
    }

    // MARK: - Controls Bar

    private var controlsBar: some View {
        HStack(spacing: 12) {
            if !nodeKeys.isEmpty {
                Menu {
                    Button {
                        viewModel.setHistorySensor("zone")
                    } label: {
                        Label(
                            "Zone Average",
                            systemImage: viewModel.historyState.selectedSensor == "zone" ? "checkmark" : ""
                        )
                    }

                    Divider()

                    ForEach(nodeKeys, id: \.self) { key in
                        Button {
                            viewModel.setHistorySensor(key)
                        } label: {
                            Label(
                                key,
                                systemImage: viewModel.historyState.selectedSensor == key ? "checkmark" : ""
                            )
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.historyState.selectedSensor == "zone"
                             ? "Zone Average"
                             : viewModel.historyState.selectedSensor)
                            .font(.system(.subheadline, design: .rounded))
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                }
                .tint(.primary)
            }

            Spacer()

            Toggle(isOn: Binding(
                get: { viewModel.historyState.showPm25 },
                set: { _ in viewModel.toggleHistoryPm25() }
            )) {
                Text("PM2.5")
                    .font(.system(.caption, design: .rounded))
            }
            .toggleStyle(.button)
            .buttonStyle(.borderedProminent)
            .tint(viewModel.historyState.showPm25 ? pm25SelectedColor : Color.secondary.opacity(0.35))

            Toggle(isOn: Binding(
                get: { viewModel.historyState.showPm10 },
                set: { _ in viewModel.toggleHistoryPm10() }
            )) {
                Text("PM10")
                    .font(.system(.caption, design: .rounded))
            }
            .toggleStyle(.button)
            .buttonStyle(.borderedProminent)
            .tint(viewModel.historyState.showPm10 ? pm10SelectedColor : Color.secondary.opacity(0.35))
        }
    }

    // MARK: - Range Selector

    private var rangeSelector: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach([("1w", "1 Week"), ("1mo", "1 Month"), ("6mo", "6 Months")], id: \.0) { key, label in
                    let isSelected = viewModel.historyState.selectedRange == key && !viewModel.historyState.showCustomInputs
                    Button {
                        viewModel.setHistoryRange(key)
                    } label: {
                        Text(label)
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(isSelected ? .accentColor : .secondary)
                }

                Button {
                    viewModel.toggleHistoryCustomInputs()
                } label: {
                    Text("Custom")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.historyState.showCustomInputs ? .accentColor : .secondary)
            }

            if viewModel.historyState.showCustomInputs {
                HStack(spacing: 8) {
                    TextField("Range (e.g. 14d)", text: Binding(
                        get: { viewModel.historyState.customRange },
                        set: { viewModel.setCustomRange($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.subheadline, design: .rounded))

                    TextField("Interval (e.g. 1h)", text: Binding(
                        get: { viewModel.historyState.customInterval },
                        set: { viewModel.setCustomInterval($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.subheadline, design: .rounded))

                    Button("Apply") {
                        viewModel.applyCustomHistory()
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.system(.caption, design: .rounded))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.historyState.showCustomInputs)
    }

    // MARK: - Weather Filter + Impact

    @ViewBuilder
    private var weatherSection: some View {
        if !viewModel.historyState.isLoading,
           let weatherHistory,
           !weatherHistory.points.isEmpty {
            WeatherFilterChips(
                selectedFilter: viewModel.historyState.weatherFilter,
                presentConditions: Set(weatherGroups.filter { $0.value.count > 0 }.keys),
                onFilterSelected: viewModel.setWeatherFilter
            )
            if !impactCards.isEmpty {
                WeatherImpactPanel(cards: impactCards)
            }
        }
    }

    // MARK: - Stats Panel

    @ViewBuilder
    private func statsPanel(stats: HistoricalStats) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                statItem(label: "Max PM2.5", value: stats.maxPm25)
                statItem(label: "Min PM2.5", value: stats.minPm25)
                statItem(label: "Avg PM2.5", value: stats.avgPm25)
            }
            HStack(spacing: 8) {
                statItem(label: "Max PM10", value: stats.maxPm10)
                statItem(label: "Min PM10", value: stats.minPm10)
                statItem(label: "Avg PM10", value: stats.avgPm10)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func statItem(label: String, value: Double?) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value.map { String(format: "%.1f", $0) } ?? "--")
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartSection: some View {
        if viewModel.historyState.isLoading {
            HStack {
                Spacer()
                ProgressView()
                    .frame(height: 200)
                Spacer()
            }
        } else if let error = viewModel.historyState.error {
            Text(error)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.red)
                .padding()
        } else if !filteredData.isEmpty {
            chartPager
        } else if !viewModel.historyState.data.isEmpty {
            Text("No samples for this weather")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
        }
    }

    private var chartPager: some View {
        VStack(spacing: 12) {
            TabView(selection: $chartPage) {
                historyChart
                    .padding(.horizontal, 8)
                    .tag(0)
                ExtendedDotGrid(
                    data: filteredData,
                    showPm25: viewModel.historyState.showPm25,
                    showPm10: viewModel.historyState.showPm10
                )
                .padding(.horizontal, 8)
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 400)
            .padding(.horizontal, -8)

            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .fill(index == chartPage ? Color.primary : Color.secondary.opacity(0.4))
                        .frame(width: 7, height: 7)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: chartPage)

            Text("Swipe for Dots History")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var historyChart: some View {
        let data = filteredData
        let showPm25 = viewModel.historyState.showPm25
        let showPm10 = viewModel.historyState.showPm10

        struct SeriesPoint: Identifiable {
            let id: String
            let date: Date
            let value: Double
            let series: String
        }

        let xAxisTicks: [Date] = {
            guard let firstTs = data.map(\.ts).min(),
                  let lastTs = data.map(\.ts).max(),
                  lastTs > firstTs else { return [] }
            return (0...4).map {
                Date(timeIntervalSince1970: TimeInterval(firstTs + (lastTs - firstTs) * $0 / 4))
            }
        }()

        var points: [SeriesPoint] = []
        for pt in data {
            if showPm25, let v = pt.pm25 {
                points.append(SeriesPoint(
                    id: "\(pt.ts)-pm25",
                    date: Date(timeIntervalSince1970: TimeInterval(pt.ts)),
                    value: v,
                    series: "PM2.5"
                ))
            }
            if showPm10, let v = pt.pm10 {
                points.append(SeriesPoint(
                    id: "\(pt.ts)-pm10",
                    date: Date(timeIntervalSince1970: TimeInterval(pt.ts)),
                    value: v,
                    series: "PM10"
                ))
            }
        }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Extended History")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.secondary)

            // Legend
            HStack(spacing: 16) {
                if showPm25 {
                    legendDot(color: pm25Color, label: "PM2.5")
                }
                if showPm10 {
                    legendDot(color: pm10Color, label: "PM10")
                }
            }
            .font(.system(.caption, design: .rounded))

            Chart {
                ForEach(points) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("Concentration", point.value)
                    )
                    .foregroundStyle(by: .value("Series", point.series))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }

                if let selected = selectedDataPoint {
                    let date = Date(timeIntervalSince1970: TimeInterval(selected.ts))

                    RuleMark(x: .value("Time", date))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5]))
                        .foregroundStyle(Color.secondary)
                        .annotation(position: .top, spacing: 0) {
                            tooltipView(for: selected)
                        }

                    if showPm25, let v = selected.pm25 {
                        PointMark(
                            x: .value("Time", date),
                            y: .value("Concentration", v)
                        )
                        .symbolSize(60)
                        .foregroundStyle(pm25Color)
                        .annotation(position: .overlay) {
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 2)
                                .frame(width: 10, height: 10)
                        }
                    }

                    if showPm10, let v = selected.pm10 {
                        PointMark(
                            x: .value("Time", date),
                            y: .value("Concentration", v)
                        )
                        .symbolSize(60)
                        .foregroundStyle(pm10Color)
                        .annotation(position: .overlay) {
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 2)
                                .frame(width: 10, height: 10)
                        }
                    }
                }
            }
            .chartForegroundStyleScale([
                "PM2.5": pm25Color,
                "PM10": pm10Color,
            ])
            .chartLegend(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: xAxisTicks) { value in
                    AxisGridLine()
                    AxisTick()
                    if let _ = value.as(Date.self) {
                        AxisValueLabel(
                            format: .dateTime.day().month(.abbreviated),
                            anchor: value.index == 0
                                ? .topLeading
                                : (value.index == value.count - 1 ? .topTrailing : nil)
                        )
                        .font(.system(size: 10))
                    }
                }
            }
            .frame(height: 220)
            .padding(.top, selectedDataPoint != nil ? 30 : 8)
            .animation(.easeInOut(duration: 0.1), value: selectedDataPoint != nil)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let locationX = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                    guard locationX >= 0, locationX <= proxy.plotAreaSize.width else { return }
                                    if let date: Date = proxy.value(atX: locationX) {
                                        selectedDataPoint = findClosestDataPoint(to: date, in: data)
                                    }
                                }
                                .onEnded { _ in selectedDataPoint = nil }
                        )
                }
            }

            Text("Concentration (µg/m³)")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
        }
    }

    // MARK: - Download

    private var downloadButton: some View {
        Group {
            if let url = viewModel.historyCSVURL() {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "arrow.down.doc")
                        Text("Download CSV")
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.accentColor, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Tooltip

    @ViewBuilder
    private func tooltipView(for point: HistoricalDataPoint) -> some View {
        let date = Date(timeIntervalSince1970: TimeInterval(point.ts))
        let showPm25 = viewModel.historyState.showPm25
        let showPm10 = viewModel.historyState.showPm10

        VStack(spacing: 4) {
            HStack(spacing: 12) {
                if showPm25, let v = point.pm25 {
                    HStack(spacing: 4) {
                        Circle().fill(pm25Color).frame(width: 6, height: 6)
                        Text(String(format: "PM2.5: %.1f", v))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                }
                if showPm10, let v = point.pm10 {
                    HStack(spacing: 4) {
                        Circle().fill(pm10Color).frame(width: 6, height: 6)
                        Text(String(format: "PM10: %.1f", v))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                }
            }

            Text(date, format: .dateTime.day().month(.abbreviated).hour().minute())
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
        )
        .padding(.bottom, 8)
    }

    private func findClosestDataPoint(to date: Date, in data: [HistoricalDataPoint]) -> HistoricalDataPoint? {
        let target = date.timeIntervalSince1970
        return data.min { a, b in
            abs(Double(a.ts) - target) < abs(Double(b.ts) - target)
        }
    }
}

// MARK: - Weather Filter Chips

struct WeatherFilterChips: View {
    let selectedFilter: String
    let presentConditions: Set<String>
    let onFilterSelected: (String) -> Void

    private var options: [(condition: String, label: String)] {
        [("all", "All")] + weatherFilterLabels.filter { presentConditions.contains($0.condition) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Filter by weather during that time")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(options, id: \.condition) { option in
                    let isSelected = selectedFilter == option.condition
                    Button {
                        if selectedFilter != option.condition {
                            onFilterSelected(option.condition)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: weatherConditionSymbol(option.condition))
                                .font(.system(size: 11))
                            Text(option.label)
                                .font(.system(.caption2, design: .rounded))
                                .fontWeight(.medium)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(isSelected ? .accentColor : .secondary)
                }
            }
        }
    }
}

// MARK: - Weather Impact

struct WeatherImpactPanel: View {
    let cards: [WeatherPm25Group]

    var body: some View {
        VStack(spacing: 12) {
            Text("Average PM2.5 by weather condition")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)

            ForEach(Array(stride(from: 0, to: cards.count, by: 2)), id: \.self) { index in
                HStack(spacing: 12) {
                    WeatherImpactStat(card: cards[index])
                    if index + 1 < cards.count {
                        WeatherImpactStat(card: cards[index + 1])
                    } else {
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct WeatherImpactStat: View {
    let card: WeatherPm25Group

    private var diffText: String {
        if card.diffPct == 0 {
            return "same as average"
        } else if card.diffPct > 0 {
            return "+\(card.diffPct)% vs average"
        } else {
            return "\(card.diffPct)% vs average"
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(card.label) (\(card.hours)h of data)")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(String(format: "%.1f µg/m³", card.avg))
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)

            Text(diffText)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(card.diffPct <= 0 ? Color.accentColor : Color.orange)
        }
        .frame(maxWidth: .infinity)
    }
}
