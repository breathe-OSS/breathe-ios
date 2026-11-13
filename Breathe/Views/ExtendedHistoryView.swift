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

struct ChartLine: Identifiable {
    let id: String
    let label: String
    let color: Color
    let dashed: Bool
    let width: CGFloat
    let points: [(date: Date, value: Double)]
}

private struct ChartSegmentPoint: Identifiable {
    let id: String
    let line: String
    let segment: String
    let date: Date
    let value: Double
    let color: Color
    let dashed: Bool
    let width: CGFloat
}

private let compareColorsLight: [Color] = [
    Color(hex: 0xEB6834), Color(hex: 0x1BAF7A), Color(hex: 0xEDA100), Color(hex: 0xE87BA4),
    Color(hex: 0x008300), Color(hex: 0x6250D6), Color(hex: 0xE34948),
]
private let compareColorsDark: [Color] = [
    Color(hex: 0xD95926), Color(hex: 0x199E70), Color(hex: 0xC98500), Color(hex: 0xD55181),
    Color(hex: 0x008300), Color(hex: 0x9085E9), Color(hex: 0xE66767),
]

struct ExtendedHistoryView: View {
    let zoneName: String
    let placeText: String
    let district: String?

    @EnvironmentObject private var viewModel: BreatheViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedDate: Date? = nil
    @State private var hourSelection: Date? = nil
    @State private var compareSelection: Date? = nil

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
    }

    private var series: [HistorySeries] {
        activeSeries(metric: state.metric, mode: state.mode)
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
                if !placeText.isEmpty {
                    Text(placeText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                controlsCard

                if state.periodActive, let period = state.period {
                    periodCard(period: period)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if state.showCustomInputs {
                    customCard
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if !state.isLoading, weatherGroups.count >= 2 {
                    WeatherFilterChips(
                        selectedFilter: state.weatherFilter,
                        presentConditions: Set(weatherGroups.filter { $0.value.count > 0 }.keys),
                        onFilterSelected: { condition in
                            selectedDate = nil
                            viewModel.setWeatherFilter(condition)
                        }
                    )
                }

                rawNoteCard

                if state.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 260)
                } else if let error = state.error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .card()
                } else if filteredData.isEmpty {
                    Text(state.data.isEmpty ? "No readings for this selection." : "No readings during this weather.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 160)
                        .card()
                } else {
                    summaryCard
                    mainChartCard
                    gridCard
                    if intervalSeconds(state.interval) <= 3600 {
                        hourCard
                    }
                    weatherCard
                    compareCard
                }

                downloadRow
            }
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
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

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Show")
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Show", selection: Binding(
                    get: { viewModel.historyState.metric },
                    set: { viewModel.setHistoryMetric($0) }
                )) {
                    ForEach(HistoryMetric.allCases) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.menu)
            }

            Picker("Readings", selection: Binding(
                get: { viewModel.historyState.mode },
                set: { viewModel.setHistoryMode($0) }
            )) {
                ForEach(HistoryMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Picker("Range", selection: rangeSelection) {
                Text("1W").tag("1w")
                Text("1M").tag("1mo")
                Text("6M").tag("6mo")
                Text("Date").tag("date")
                Text("Custom").tag("custom")
            }
            .pickerStyle(.segmented)
        }
        .card()
    }

    @ViewBuilder
    private var rawNoteCard: some View {
        if state.mode != .cal, !state.isLoading, state.error == nil {
            if let note = rawNote(rows: state.data, metric: state.metric, interval: state.interval) {
                Label(note, systemImage: "info.circle")
                    .font(.subheadline)
                    .card()
            } else if !viewModel.rawHintHidden {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Showing the sensor's uncorrected readings.", systemImage: "info.circle")
                        .font(.subheadline)
                    HStack {
                        NavigationLink("What changes") {
                            RawExplainerView()
                        }
                        Spacer()
                        Button("Don't show again") {
                            viewModel.rawHintHidden = true
                        }
                    }
                    .font(.subheadline)
                }
                .card()
            }
        }
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

    // MARK: - Colours

    private var isDark: Bool {
        colorScheme == .dark
    }

    private func seriesColor(_ s: HistorySeries) -> Color {
        switch s.hue {
        case .raw: return isDark ? Color(hex: 0xD95926) : Color(hex: 0xEB6834)
        case .secondary: return isDark ? Color(hex: 0x199E70) : Color(hex: 0x1BAF7A)
        case .primary: return isDark ? Color(hex: 0x3987E5) : Color(hex: 0x2A78D6)
        }
    }

    private func valueColor(key: String, value: Double?) -> Color {
        guard let value else {
            return .primary
        }
        let base = key.hasSuffix("_raw") ? String(key.dropLast(4)) : key
        switch base {
        case "us_aqi": return AqiPalette.color(Int(value.rounded()), isUsAqi: true)
        case "pm2_5": return AqiPalette.color(bandSample(value, bands: pm25Bands), isUsAqi: true)
        case "pm10": return AqiPalette.color(bandSample(value, bands: pm10Bands), isUsAqi: true)
        default: return .primary
        }
    }

    private func timeLabel(_ ts: Int, bucket: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        if bucket >= 86400 {
            return date.formatted(.dateTime.day().month(.abbreviated))
        }
        return date.formatted(.dateTime.day().month(.abbreviated).hour())
    }

    // MARK: - Summary

    private var summaryCard: some View {
        let points = filteredData
        let unit = unitSuffix(state.metric.unit)
        let step = intervalSeconds(state.interval)
        let aqiKey = state.mode == .raw ? "us_aqi_raw" : "us_aqi"
        var tally = Array(repeating: 0, count: 6)
        for point in points {
            if let v = point.value(aqiKey) {
                tally[aqiBandIndex(Int(v.rounded()), isUsAqi: true)] += 1
            }
        }
        let tallied = tally.reduce(0, +)
        let rows = state.data
        let expected: Int
        if rows.count > 1, let first = rows.first, let last = rows.last {
            expected = (last.ts - first.ts) / step + 1
        } else {
            expected = rows.count
        }
        let coverage = expected > 0 ? min(100, Int((Double(rows.count) * 100 / Double(expected)).rounded())) : 0
        let foot: String
        if state.weatherFilter == "all" {
            foot = "\(coverage)% of \(step <= 3600 ? "hours" : "buckets") have readings"
        } else {
            let label = weatherFilterLabels.first { $0.condition == state.weatherFilter }?.label.lowercased() ?? state.weatherFilter
            foot = "Only \(label) hours, \(points.count) of \(rows.count)"
        }

        return VStack(alignment: .leading, spacing: 14) {
            ForEach(series) { s in
                let st = seriesStats(points, key: s.key)
                VStack(alignment: .leading, spacing: 2) {
                    Text(st.count == 0 ? s.label : "\(s.label) average")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if st.count == 0 {
                        Text("No readings")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(formatValue(st.avg, decimals: state.metric.decimals))\(unit)")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(valueColor(key: s.key, value: st.avg))
                        Text("Peak \(formatValue(st.maxValue, decimals: state.metric.decimals)) on \(timeLabel(st.maxTs ?? 0, bucket: step)) · low \(formatValue(st.minValue, decimals: state.metric.decimals))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            if tallied > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text(state.mode == .raw ? "Time in each US AQI category, raw" : "Time in each US AQI category")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(0..<6, id: \.self) { index in
                                if tally[index] > 0 {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(AqiPalette.color(usCategorySamples[index], isUsAqi: true))
                                        .frame(width: max(2, (geo.size.width - 10) * CGFloat(tally[index]) / CGFloat(tallied)))
                                }
                            }
                        }
                    }
                    .frame(height: 12)
                    FlowLegend(items: (0..<6).filter { tally[$0] > 0 }.map { index in
                        (
                            AqiPalette.color(usCategorySamples[index], isUsAqi: true),
                            "\(AqiPalette.label(usCategorySamples[index], isUsAqi: true)) \(Int((Double(tally[index]) * 100 / Double(tallied)).rounded()))%"
                        )
                    })
                }
            }

            Text(foot)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    // MARK: - Charts

    private func segmented(_ lines: [ChartLine], gap: TimeInterval) -> [ChartSegmentPoint] {
        var out: [ChartSegmentPoint] = []
        for line in lines {
            var segment = 0
            var previous: Date? = nil
            for point in line.points {
                if let previous, point.date.timeIntervalSince(previous) > gap {
                    segment += 1
                }
                previous = point.date
                out.append(
                    ChartSegmentPoint(
                        id: "\(line.id)-\(point.date.timeIntervalSince1970)",
                        line: line.label,
                        segment: "\(line.id)#\(segment)",
                        date: point.date,
                        value: point.value,
                        color: line.color,
                        dashed: line.dashed,
                        width: line.width
                    )
                )
            }
        }
        return out
    }

    private func historyChart(
        lines: [ChartLine],
        bands: [Double]?,
        gap: TimeInterval,
        beginAtZero: Bool,
        hourAxis: Bool,
        selection: Binding<Date?>,
        height: CGFloat
    ) -> some View {
        let points = segmented(lines, gap: gap)
        let values = points.map(\.value)
        let rawMin = values.min() ?? 0
        let rawMax = values.max() ?? 1
        let yMin = beginAtZero ? 0 : (rawMin - (rawMax - rawMin) * 0.1 - 1).rounded(.down)
        let yMax = max(rawMax + (rawMax - yMin) * 0.08, yMin + 1)
        let dates = points.map(\.date)
        let first = dates.min() ?? Date()
        let last = max(dates.max() ?? Date(), first.addingTimeInterval(60))
        let selected = selection.wrappedValue

        return Chart {
            if let bands {
                ForEach(0..<(bands.count - 1), id: \.self) { index in
                    let low = max(bands[index], yMin)
                    let high = min(bands[index + 1], yMax)
                    if high > low {
                        RectangleMark(
                            xStart: .value("Start", first),
                            xEnd: .value("End", last),
                            yStart: .value("Low", low),
                            yEnd: .value("High", high)
                        )
                        .foregroundStyle(AqiPalette.color(usCategorySamples[index], isUsAqi: true).opacity(0.09))
                    }
                }
            }

            ForEach(points) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Value", point.value),
                    series: .value("Line", point.segment)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(point.color)
                .lineStyle(StrokeStyle(lineWidth: point.width, lineCap: .round, lineJoin: .round, dash: point.dashed ? [6, 4] : []))
            }

            if let selected {
                RuleMark(x: .value("Selected", selected))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.6))
            }
        }
        .chartXSelection(value: selection)
        .chartXScale(domain: first...last)
        .chartYScale(domain: yMin...yMax)
        .chartLegend(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                if hourAxis {
                    AxisValueLabel(format: .dateTime.hour())
                        .font(.caption2)
                } else {
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .font(.caption2)
                }
            }
        }
        .frame(height: height)
    }

    private func readout(lines: [ChartLine], at date: Date?, hourAxis: Bool) -> some View {
        let text: String
        if let date {
            let parts = lines.compactMap { line -> String? in
                guard let nearest = line.points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) else {
                    return nil
                }
                var part = "\(line.label) \(formatValue(nearest.value, decimals: state.metric.decimals))\(unitSuffix(state.metric.unit))"
                if state.metric == .aqi && !hourAxis {
                    part += " (\(AqiPalette.label(Int(nearest.value.rounded()), isUsAqi: true)))"
                }
                return part
            }
            let when = hourAxis ? date.formatted(.dateTime.hour()) : date.formatted(.dateTime.day().month(.abbreviated).hour())
            text = "\(when) · \(parts.isEmpty ? "no reading" : parts.joined(separator: " · "))"
        } else {
            text = "Touch and drag across the chart for readings"
        }
        return Text(text)
            .font(.footnote)
            .foregroundStyle(date == nil ? .secondary : .primary)
            .lineLimit(3)
    }

    private func legend(_ lines: [ChartLine]) -> some View {
        FlowLegend(items: lines.map { ($0.color, $0.label) })
    }

    private var mainChartCard: some View {
        let bucket = displayBucket(filteredData, interval: state.interval)
        let rows = aggregate(filteredData, bucket: bucket, interval: state.interval, keys: series.map(\.key))
        let lines = series.map { s in
            ChartLine(
                id: s.key,
                label: s.label,
                color: seriesColor(s),
                dashed: s.raw,
                width: 2,
                points: rows.compactMap { row in
                    row.values[s.key].map { (date: Date(timeIntervalSince1970: TimeInterval(row.ts)), value: $0) }
                }
            )
        }
        let step = bucket >= 86400 ? "daily averages" : (bucket >= 4 * 3600 ? "4 hour averages" : "hourly")
        let shaded = state.metric.bands == nil ? "" : ", shaded by US AQI category"

        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.metric.rawValue)
                    .font(.headline)
                Text("\(state.metric.unit), \(step)\(shaded)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if lines.count > 1 {
                legend(lines)
            }
            readout(lines: lines, at: selectedDate, hourAxis: false)
            historyChart(
                lines: lines,
                bands: state.metric.bands,
                gap: TimeInterval(bucket) * 1.5,
                beginAtZero: state.metric != .temp,
                hourAxis: false,
                selection: $selectedDate,
                height: 240
            )
            .sensoryFeedback(.selection, trigger: selectedDate)
        }
        .card()
    }

    private var gridCard: some View {
        let raw = state.mode == .raw
        let mapped = filteredData.map { point -> HistoricalDataPoint in
            var copy = point
            if raw {
                copy.pm25 = point.pm25Raw
                copy.pm10 = point.pm10Raw
            }
            return copy
        }.filter { $0.pm25 != nil || $0.pm10 != nil }

        return VStack(alignment: .leading, spacing: 10) {
            Text("Day by Day")
                .font(.headline)
            if mapped.isEmpty {
                Text("No particulate readings in this selection.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ExtendedDotGrid(data: mapped, showPm25: true, showPm10: true)
            }
        }
        .card()
    }

    private var hourCard: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lines = series.map { s -> ChartLine in
            var sums = Array(repeating: 0.0, count: 24)
            var counts = Array(repeating: 0, count: 24)
            for point in filteredData {
                guard let v = point.value(s.key) else {
                    continue
                }
                let hour = calendar.component(.hour, from: Date(timeIntervalSince1970: TimeInterval(point.ts)))
                sums[hour] += v
                counts[hour] += 1
            }
            let points = (0..<24).compactMap { hour -> (date: Date, value: Double)? in
                guard counts[hour] > 0 else {
                    return nil
                }
                let date = calendar.date(byAdding: .hour, value: hour, to: today) ?? today
                return (date: date, value: sums[hour] / Double(counts[hour]))
            }
            return ChartLine(id: s.key, label: s.label, color: seriesColor(s), dashed: s.raw, width: 2, points: points)
        }

        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hour of Day")
                    .font(.headline)
                Text("Average \(state.metric.rawValue) at each hour, local time")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if lines.count > 1 {
                legend(lines)
            }
            readout(lines: lines, at: hourSelection, hourAxis: true)
            historyChart(
                lines: lines,
                bands: state.metric.bands,
                gap: 5400,
                beginAtZero: state.metric != .temp,
                hourAxis: true,
                selection: $hourSelection,
                height: 180
            )
        }
        .card()
    }

    @ViewBuilder
    private var weatherCard: some View {
        if let key = series.first?.key {
            let cards = weatherImpactCards(data: state.data, weather: weatherHistory) { $0.value(key) }
            if !cards.isEmpty {
                WeatherImpactPanel(
                    cards: cards,
                    title: "Average \(series.first?.label ?? "") by weather",
                    unit: state.metric.unit,
                    decimals: state.metric.decimals,
                    judged: state.metric != .temp && state.metric != .humidity
                )
            }
        }
    }

    // MARK: - Compare

    private func compareColor(_ index: Int, total: Int) -> Color {
        if total > compareColorsLight.count {
            return Color.secondary.opacity(0.45)
        }
        let palette = isDark ? compareColorsDark : compareColorsLight
        return palette[index % palette.count]
    }

    private func toneColor(_ tone: VerdictTone) -> Color {
        switch tone {
        case .good: return .green
        case .fair: return .orange
        case .poor: return .red
        case .none: return .secondary
        }
    }

    private var compareCard: some View {
        let places = viewModel.comparablePlaces
        let ids = state.compareIds
        let key = compareKey(metric: state.metric, mode: state.mode)
        let label = compareLabel(metric: state.metric, mode: state.mode)
        let nameOf: (String) -> String = { id in places.first { $0.id == id }?.name ?? id }
        let others = Dictionary(uniqueKeysWithValues: ids.map { id in
            (id, filterHistoryByWeather(data: state.compareRows[id] ?? [], weather: weatherHistory, filter: state.weatherFilter))
        })

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Compare Sensors")
                    .font(.headline)
                Text("Overlay \(label) from other sensors on \(zoneName) for the same range")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Menu {
                if let district, places.contains(where: { $0.district == district }) {
                    Button("Same District") {
                        viewModel.setCompareIds(places.filter { $0.district == district }.map(\.id))
                    }
                }
                Button("All Sensors") {
                    viewModel.setCompareIds(places.map(\.id))
                }
                if !ids.isEmpty {
                    Button("Clear", role: .destructive) {
                        viewModel.setCompareIds([])
                    }
                }
                Divider()
                ForEach(places.sorted { ($0.district ?? "", $0.name) < ($1.district ?? "", $1.name) }) { place in
                    Button {
                        viewModel.toggleCompare(place.id)
                    } label: {
                        if ids.contains(place.id) {
                            Label(place.name, systemImage: "checkmark")
                        } else {
                            Text(place.name)
                        }
                    }
                }
            } label: {
                HStack {
                    Label(ids.isEmpty ? "Choose sensors" : "\(ids.count) sensor\(ids.count == 1 ? "" : "s")", systemImage: "plus.circle")
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }

            if state.compareLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }

            if !ids.isEmpty {
                compareResults(ids: ids, key: key, label: label, others: others, nameOf: nameOf)
            }
        }
        .card()
    }

    @ViewBuilder
    private func compareResults(
        ids: [String],
        key: String,
        label: String,
        others: [String: [HistoricalDataPoint]],
        nameOf: @escaping (String) -> String
    ) -> some View {
        let base = filteredData
        let bucket = displayBucket(base, interval: state.interval)
        let many = ids.count > compareColorsLight.count
        let toPoints: ([HistoricalDataPoint]) -> [(date: Date, value: Double)] = { rows in
            aggregate(rows, bucket: bucket, interval: state.interval, keys: [key]).compactMap { row in
                row.values[key].map { (date: Date(timeIntervalSince1970: TimeInterval(row.ts)), value: $0) }
            }
        }
        let baseLine = ChartLine(
            id: "base",
            label: zoneName,
            color: isDark ? Color(hex: 0x3987E5) : Color(hex: 0x2A78D6),
            dashed: false,
            width: 3,
            points: toPoints(base)
        )
        let otherLines = ids.enumerated().map { index, id in
            ChartLine(
                id: id,
                label: nameOf(id),
                color: compareColor(index, total: ids.count),
                dashed: false,
                width: many ? 1.25 : 2,
                points: toPoints(others[id] ?? [])
            )
        }
        let lines = otherLines + [baseLine]
        let baseSeries = seriesByTs(base, key: key)
        let results = ids.map { id -> (id: String, stats: PairStats, verdict: Verdict) in
            let stats = pairStats(baseSeries, seriesByTs(others[id] ?? [], key: key))
            return (id: id, stats: stats, verdict: verdictFor(stats, metric: state.metric))
        }.sorted { ($0.stats.r ?? -2) > ($1.stats.r ?? -2) }
        let good = results.filter { $0.verdict.tone == .good }.count
        let counted = results.filter { $0.verdict.tone != .none }.count
        let unit = unitSuffix(state.metric.unit)

        if !many {
            legend([baseLine] + otherLines)
        }
        readout(lines: [baseLine] + otherLines, at: compareSelection, hourAxis: false)
        historyChart(
            lines: lines,
            bands: state.metric.bands,
            gap: TimeInterval(bucket) * 1.5,
            beginAtZero: state.metric != .temp,
            hourAxis: false,
            selection: $compareSelection,
            height: 240
        )

        Text(counted == 0
             ? "Not enough overlapping \(label) readings in this range to judge."
             : "\(good) of \(counted) sensor\(counted == 1 ? "" : "s") track \(zoneName) closely on \(label).")
            .font(.subheadline)
            .fontWeight(.semibold)

        ForEach(results, id: \.id) { result in
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(compareColor(ids.firstIndex(of: result.id) ?? 0, total: ids.count))
                    .frame(width: 10, height: 10)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(nameOf(result.id))
                            .fontWeight(.semibold)
                        Spacer()
                        Text(result.verdict.label)
                            .font(.subheadline)
                            .foregroundStyle(toneColor(result.verdict.tone))
                    }
                    let r = result.stats.r.map { String(format: "%.2f", $0) } ?? "--"
                    let ratio = result.stats.ratio.map { String(format: "%.2f×", $0) } ?? "--"
                    let gap = result.stats.gap.map { "\(formatValue($0, decimals: state.metric.decimals))\(unit)" } ?? "--"
                    Text("Moves together \(r) · ratio \(ratio) · gap \(gap) · \(result.stats.n) hours")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }

        Text("Moves together is the correlation. 1 means they rise and fall at exactly the same times, 0 means no link at all. Typical ratio is their reading over \(zoneName)'s, so 1.20× means they usually read 20% higher. Typical gap is how far apart the two readings are on average. A pair can move together closely and still sit at different levels, which usually means one sensor reads high or low rather than the air being different.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        if ids.count >= 2 {
            compareMatrix(
                names: [zoneName] + ids.map(nameOf),
                maps: [baseSeries] + ids.map { seriesByTs(others[$0] ?? [], key: key) },
                label: label
            )
        }
    }

    private func compareMatrix(names: [String], maps: [[Int: Double]], label: String) -> some View {
        let cell: CGFloat = 52
        return VStack(alignment: .leading, spacing: 8) {
            Text("Every Pair")
                .font(.headline)
            Text("How closely each pair moves together on \(label), from 0 to 1. Darker means more consistent.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                    GridRow {
                        Color.clear
                            .frame(width: 110, height: cell)
                        ForEach(names.indices, id: \.self) { j in
                            Text(names[j])
                                .font(.caption2)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(width: cell, height: cell, alignment: .bottom)
                        }
                    }
                    ForEach(names.indices, id: \.self) { i in
                        GridRow {
                            Text(names[i])
                                .font(.caption)
                                .lineLimit(2)
                                .frame(width: 110, height: cell, alignment: .leading)
                            ForEach(names.indices, id: \.self) { j in
                                matrixCell(i == j ? nil : pairStats(maps[i], maps[j]), isSelf: i == j, size: cell)
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 4)
    }

    private func matrixCell(_ stats: PairStats?, isSelf: Bool, size: CGFloat) -> some View {
        let r: Double? = stats.flatMap { $0.n >= compareMinOverlap ? $0.r : nil }
        let strength = min(max(r ?? 0, 0), 1)
        let blue = isDark ? Color(hex: 0x3987E5) : Color(hex: 0x2A78D6)
        let fill: Color = isSelf ? Color(.tertiarySystemFill) : (r == nil ? Color.clear : blue.opacity(0.08 + strength * 0.65))
        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(fill)
            if !isSelf {
                Text(r.map { String(format: "%.2f", $0) } ?? "--")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(strength > 0.6 ? Color.white : Color.primary)
            }
        }
        .frame(width: size, height: size)
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

struct FlowLegend: View {
    let items: [(Color, String)]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                entries
            }
            VStack(alignment: .leading, spacing: 4) {
                entries
            }
        }
    }

    private var entries: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(item.0)
                    .frame(width: 10, height: 10)
                Text(item.1)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Weather Impact

struct WeatherImpactPanel: View {
    let cards: [WeatherPm25Group]
    var title: String = "PM2.5 by Weather"
    var unit: String = "µg/m³"
    var decimals: Int = 1
    var judged: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                if index > 0 {
                    Divider()
                }
                WeatherImpactRow(card: card, unit: unit, decimals: decimals, judged: judged)
            }
        }
        .card()
    }
}

private struct WeatherImpactRow: View {
    let card: WeatherPm25Group
    let unit: String
    let decimals: Int
    let judged: Bool

    private var diffText: String {
        if card.diffPct == 0 {
            return "Same as average"
        }
        if card.diffPct > 0 {
            return "\(card.diffPct)% above average"
        }
        return "\(-card.diffPct)% below average"
    }

    private var diffColor: Color {
        if !judged {
            return .secondary
        }
        return card.diffPct > 0 ? Color.orange : Color.green
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
                Text("\(formatValue(card.avg, decimals: decimals))\(unitSuffix(unit))")
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text(diffText)
                    .font(.caption)
                    .foregroundStyle(diffColor)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
