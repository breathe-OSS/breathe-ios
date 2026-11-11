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

private struct SeriesPoint: Identifiable {
    let date: Date
    let value: Double
    let series: String

    var id: String { "\(series)-\(date.timeIntervalSince1970)" }
}

struct ExtendedHistoryView: View {
    let zoneName: String
    let nodeKeys: [String]

    @EnvironmentObject private var viewModel: BreatheViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedDate: Date? = nil
    @State private var chartMode = 0

    private var state: HistoryState {
        viewModel.historyState
    }

    private var weatherHistory: WeatherHistory? {
        state.weatherHistory
    }

    private var weatherGroups: [String: (sum: Double, count: Int)] {
        weatherPm25Groups(data: state.data, weather: weatherHistory)
    }

    private var filteredData: [HistoricalDataPoint] {
        filterHistoryByWeather(data: state.data, weather: weatherHistory, filter: state.weatherFilter)
            .sorted { $0.ts < $1.ts }
    }

    private var impactCards: [WeatherPm25Group] {
        weatherImpactCards(data: state.data, weather: weatherHistory)
    }

    private var rangeSelection: Binding<String> {
        Binding(
            get: {
                if viewModel.historyState.periodActive {
                    return "date"
                }
                if viewModel.historyState.showCustomInputs {
                    return "custom"
                }
                return viewModel.historyState.selectedRange
            },
            set: { key in
                selectedDate = nil
                switch key {
                case "date":
                    viewModel.showHistoryPeriod()
                case "custom":
                    if !viewModel.historyState.showCustomInputs {
                        viewModel.toggleHistoryCustomInputs()
                    }
                default:
                    viewModel.setHistoryRange(key)
                }
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Range", selection: rangeSelection) {
                    Text("1W").tag("1w")
                    Text("1M").tag("1mo")
                    Text("6M").tag("6mo")
                    Text("Date").tag("date")
                    Text("Custom").tag("custom")
                }
                .pickerStyle(.segmented)

                if state.periodActive, let period = state.period {
                    periodCard(period: period)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if state.showCustomInputs {
                    customCard
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                seriesRow

                if !state.isLoading, let weatherHistory, !weatherHistory.points.isEmpty {
                    WeatherFilterChips(
                        selectedFilter: state.weatherFilter,
                        presentConditions: Set(weatherGroups.filter { $0.value.count > 0 }.keys),
                        onFilterSelected: { condition in
                            selectedDate = nil
                            viewModel.setWeatherFilter(condition)
                        }
                    )
                }

                chartCard

                if !state.isLoading, let stats = state.stats {
                    statsCard(stats: stats)
                }

                if !state.isLoading, !impactCards.isEmpty {
                    WeatherImpactPanel(cards: impactCards)
                }

                downloadRow
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
            .animation(reduceMotion ? .none : .snappy, value: state.periodActive)
            .animation(reduceMotion ? .none : .snappy, value: state.showCustomInputs)
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: viewModel.historyState.selectedRange) { _, _ in
            selectedDate = nil
        }
        .navigationTitle("\(zoneName) History")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Controls

    private var seriesRow: some View {
        HStack(spacing: 8) {
            if !nodeKeys.isEmpty {
                Menu {
                    Picker("Sensor", selection: Binding(
                        get: { viewModel.historyState.selectedSensor },
                        set: { sensor in
                            selectedDate = nil
                            viewModel.setHistorySensor(sensor)
                        }
                    )) {
                        Text("Zone average").tag("zone")
                        ForEach(nodeKeys, id: \.self) { key in
                            Text(key).tag(key)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.caption)
                        Text(state.selectedSensor == "zone" ? "Zone average" : state.selectedSensor)
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(.secondarySystemGroupedBackground)))
                }
                .tint(.primary)
            }

            Spacer(minLength: 0)

            seriesToggle("PM2.5", color: SeriesPalette.pm25, isOn: state.showPm25) {
                selectedDate = nil
                viewModel.toggleHistoryPm25()
            }
            seriesToggle("PM10", color: SeriesPalette.pm10, isOn: state.showPm10) {
                selectedDate = nil
                viewModel.toggleHistoryPm10()
            }
        }
    }

    private func seriesToggle(_ label: String, color: Color, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isOn ? color : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text(label)
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isOn ? Color.primary : Color.secondary)
            .background(
                Capsule()
                    .fill(isOn ? color.opacity(0.16) : Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    @ViewBuilder
    private func periodCard(period: HistoryPeriod) -> some View {
        let mode = state.periodMode
        let canStepForward = period.shifted(mode: mode, by: 1).start <= Date()

        VStack(spacing: 12) {
            Picker("Period", selection: Binding(
                get: { viewModel.historyState.periodMode },
                set: { viewModel.setHistoryPeriodMode($0) }
            )) {
                ForEach(HistoryPeriodMode.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)

            if mode == .days {
                DatePicker(
                    "From",
                    selection: Binding(
                        get: { period.start },
                        set: { viewModel.pickHistoryPeriodSpan(from: $0, to: period.end) }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                DatePicker(
                    "To",
                    selection: Binding(
                        get: { period.end },
                        set: { viewModel.pickHistoryPeriodSpan(from: period.start, to: $0) }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
            } else {
                DatePicker(
                    mode == .month ? "Month containing" : "Week containing",
                    selection: Binding(
                        get: { period.start },
                        set: { viewModel.pickHistoryPeriodDate($0) }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
            }

            HStack {
                Button {
                    viewModel.stepHistoryPeriod(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(.tertiarySystemFill)))
                }
                .accessibilityLabel("Previous period")

                Spacer()

                Text(period.label(mode: mode))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Spacer()

                Button {
                    viewModel.stepHistoryPeriod(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(.tertiarySystemFill)))
                }
                .disabled(!canStepForward)
                .accessibilityLabel("Next period")
            }
        }
        .card()
    }

    private var customCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField("Range, like 14d", text: Binding(
                    get: { viewModel.historyState.customRange },
                    set: { viewModel.setCustomRange($0) }
                ))
                .textFieldStyle(.roundedBorder)

                TextField("Interval, like 1h", text: Binding(
                    get: { viewModel.historyState.customInterval },
                    set: { viewModel.setCustomInterval($0) }
                ))
                .textFieldStyle(.roundedBorder)
            }

            Button {
                selectedDate = nil
                viewModel.applyCustomHistory()
            } label: {
                Text("Apply")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .card()
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Chart style", selection: $chartMode) {
                Text("Trend").tag(0)
                Text("Calendar").tag(1)
            }
            .pickerStyle(.segmented)

            if state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 260)
            } else if let error = state.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else if filteredData.isEmpty {
                Text(state.data.isEmpty ? "No readings for this selection." : "No readings during this weather.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else if chartMode == 0 {
                trendReadout
                trendChart
            } else {
                ExtendedDotGrid(data: filteredData, showPm25: state.showPm25, showPm10: state.showPm10)
            }
        }
        .card()
    }

    private var selectedPoint: HistoricalDataPoint? {
        guard let selectedDate else {
            return nil
        }
        let target = selectedDate.timeIntervalSince1970
        return filteredData.min { abs(Double($0.ts) - target) < abs(Double($1.ts) - target) }
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }
        return values.reduce(0, +) / Double(values.count)
    }

    private var trendReadout: some View {
        let point = selectedPoint
        let pm25 = point.map { $0.pm25 } ?? average(filteredData.compactMap(\.pm25))
        let pm10 = point.map { $0.pm10 } ?? average(filteredData.compactMap(\.pm10))
        let caption = point.map {
            Date(timeIntervalSince1970: TimeInterval($0.ts)).formatted(.dateTime.day().month(.abbreviated).hour().minute())
        } ?? "Average over range"

        return VStack(alignment: .leading, spacing: 4) {
            Text(caption)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 20) {
                if state.showPm25 {
                    readoutValue("PM2.5", value: pm25, color: SeriesPalette.pm25)
                }
                if state.showPm10 {
                    readoutValue("PM10", value: pm10, color: SeriesPalette.pm10)
                }
                Spacer(minLength: 0)
                Text("µg/m³")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func readoutValue(_ label: String, value: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value.map { String(format: "%.1f", $0) } ?? "N/A")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    private var trendChart: some View {
        let data = filteredData
        let showPm25 = state.showPm25
        let showPm10 = state.showPm10
        let primary = showPm25 ? "PM2.5" : "PM10"
        let primaryColor = showPm25 ? SeriesPalette.pm25 : SeriesPalette.pm10

        var points: [SeriesPoint] = []
        for point in data {
            let date = Date(timeIntervalSince1970: TimeInterval(point.ts))
            if showPm25, let value = point.pm25 {
                points.append(SeriesPoint(date: date, value: value, series: "PM2.5"))
            }
            if showPm10, let value = point.pm10 {
                points.append(SeriesPoint(date: date, value: value, series: "PM10"))
            }
        }

        let first = data.first.map { Date(timeIntervalSince1970: TimeInterval($0.ts)) } ?? Date()
        let last = data.last.map { Date(timeIntervalSince1970: TimeInterval($0.ts)) } ?? Date()
        let spansDays = last.timeIntervalSince(first) > 2 * 86400
        let labelFormat: Date.FormatStyle = spansDays
            ? .dateTime.day().month(.abbreviated)
            : .dateTime.hour()
        let selected = selectedPoint
        let span = last.timeIntervalSince(first)
        let xTicks = [0.1, 0.37, 0.63, 0.9].map { first.addingTimeInterval(span * $0) }

        return Chart {
            ForEach(points.filter { $0.series == primary }) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    y: .value("Concentration", point.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [primaryColor.opacity(0.25), primaryColor.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            ForEach(points) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Concentration", point.value),
                    series: .value("Series", point.series)
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .foregroundStyle(point.series == "PM2.5" ? SeriesPalette.pm25 : SeriesPalette.pm10)
            }

            if showPm25 {
                RuleMark(y: .value("WHO PM2.5", 15))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(SeriesPalette.pm25.opacity(0.6))
                    .annotation(position: .top, alignment: .leading, spacing: 2) {
                        Text("WHO 24h PM2.5")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }

            if showPm10 {
                RuleMark(y: .value("WHO PM10", 45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(SeriesPalette.pm10.opacity(0.6))
                    .annotation(position: .top, alignment: .trailing, spacing: 2) {
                        Text("WHO 24h PM10")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }

            if let selected {
                let date = Date(timeIntervalSince1970: TimeInterval(selected.ts))

                RuleMark(x: .value("Selected", date))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.6))

                if showPm25, let value = selected.pm25 {
                    PointMark(x: .value("Time", date), y: .value("Concentration", value))
                        .symbol {
                            ChartSelectionDot(color: SeriesPalette.pm25)
                        }
                }

                if showPm10, let value = selected.pm10 {
                    PointMark(x: .value("Time", date), y: .value("Concentration", value))
                        .symbol {
                            ChartSelectionDot(color: SeriesPalette.pm10)
                        }
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXScale(domain: first...last)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .chartXAxis {
            AxisMarks(values: xTicks) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel(format: labelFormat, centered: true)
                    .font(.caption2)
            }
        }
        .frame(height: 240)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PM concentrations over the selected range")
    }

    // MARK: - Summary

    private func statsCard(stats: HistoricalStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Summary")
                    .font(.headline)
                Spacer()
                Text("µg/m³")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("")
                        .gridColumnAlignment(.leading)
                    gridHeader("Average")
                    gridHeader("Lowest")
                    gridHeader("Highest")
                }

                Divider()
                    .gridCellUnsizedAxes(.horizontal)

                statRow("PM2.5", color: SeriesPalette.pm25, values: [stats.avgPm25, stats.minPm25, stats.maxPm25])

                Divider()
                    .gridCellUnsizedAxes(.horizontal)

                statRow("PM10", color: SeriesPalette.pm10, values: [stats.avgPm10, stats.minPm10, stats.maxPm10])
            }
            .font(.subheadline)
        }
        .card()
    }

    private func gridHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func statRow(_ label: String, color: Color, values: [Double?]) -> some View {
        GridRow {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .fontWeight(.medium)
            }
            .gridColumnAlignment(.leading)

            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                Text(value.map { String(format: "%.1f", $0) } ?? "N/A")
                    .fontWeight(index == 0 ? .bold : .regular)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Download

    @ViewBuilder
    private var downloadRow: some View {
        if let url = viewModel.historyCSVURL() {
            Link(destination: url) {
                HStack {
                    Label("Download CSV", systemImage: "arrow.down.doc")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }
                .card()
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Weather Filter Chips

struct WeatherFilterChips: View {
    let selectedFilter: String
    let presentConditions: Set<String>
    let onFilterSelected: (String) -> Void

    private var options: [(condition: String, label: String)] {
        [("all", "All weather")] + weatherFilterLabels.filter { presentConditions.contains($0.condition) }
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(options, id: \.condition) { option in
                    let isSelected = selectedFilter == option.condition
                    Button {
                        if !isSelected {
                            onFilterSelected(option.condition)
                        }
                    } label: {
                        Label(option.label, systemImage: weatherConditionSymbol(option.condition))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
    }
}

// MARK: - Weather Impact

struct WeatherImpactPanel: View {
    let cards: [WeatherPm25Group]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PM2.5 by Weather")
                .font(.headline)

            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                if index > 0 {
                    Divider()
                }
                WeatherImpactRow(card: card)
            }
        }
        .card()
    }
}

private struct WeatherImpactRow: View {
    let card: WeatherPm25Group

    private var diffText: String {
        if card.diffPct == 0 {
            return "Same as average"
        }
        if card.diffPct > 0 {
            return "\(card.diffPct)% above average"
        }
        return "\(-card.diffPct)% below average"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: weatherConditionSymbol(card.condition))
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(card.label)
                    .fontWeight(.medium)
                Text("\(card.hours)h of data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f µg/m³", card.avg))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text(diffText)
                    .font(.caption)
                    .foregroundStyle(card.diffPct > 0 ? Color.orange : Color.green)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
