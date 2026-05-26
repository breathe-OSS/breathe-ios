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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                controlsBar
                rangeSelector
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
            .buttonStyle(.bordered)
            .tint(viewModel.historyState.showPm25 ? pm25Color : .secondary)

            Toggle(isOn: Binding(
                get: { viewModel.historyState.showPm10 },
                set: { _ in viewModel.toggleHistoryPm10() }
            )) {
                Text("PM10")
                    .font(.system(.caption, design: .rounded))
            }
            .toggleStyle(.button)
            .buttonStyle(.bordered)
            .tint(viewModel.historyState.showPm10 ? pm10Color : .secondary)
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
        } else if !viewModel.historyState.data.isEmpty {
            historyChart
        }
    }

    private var historyChart: some View {
        let data = viewModel.historyState.data
        let showPm25 = viewModel.historyState.showPm25
        let showPm10 = viewModel.historyState.showPm10

        struct SeriesPoint: Identifiable {
            let id: String
            let date: Date
            let value: Double
            let series: String
        }

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

            Chart(points) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Concentration", point.value)
                )
                .foregroundStyle(by: .value("Series", point.series))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))

                AreaMark(
                    x: .value("Time", point.date),
                    y: .value("Concentration", point.value)
                )
                .foregroundStyle(by: .value("Series", point.series))
                .interpolationMethod(.catmullRom)
                .opacity(0.15)
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
                AxisMarks { value in
                    AxisGridLine()
                    AxisTick()
                    if let _ = value.as(Date.self) {
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated), collisionResolution: .automatic)
                            .font(.system(size: 10))
                    }
                }
            }
            .chartXScale(range: .plotDimension(padding: 10))
            .frame(height: 220)
            .padding(.top, 8)

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
}
