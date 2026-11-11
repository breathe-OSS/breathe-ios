// SPDX-License-Identifier: MIT
/*
 * GraphView.swift
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

struct AqiSample: Identifiable {
    let date: Date
    let value: Int

    var id: Date { date }
}

func aqiSamples(_ history: [HistoryPoint], isUsAqi: Bool) -> [AqiSample] {
    history
        .sorted { $0.ts < $1.ts }
        .map { point in
            AqiSample(
                date: Date(timeIntervalSince1970: TimeInterval(point.ts)),
                value: isUsAqi ? (point.usAqi ?? point.aqi) : point.aqi
            )
        }
}

func closestSample(to date: Date?, in samples: [AqiSample]) -> AqiSample? {
    guard let date else {
        return nil
    }
    return samples.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
}

struct GraphView: View {
    let history: [HistoryPoint]
    let isUsAqi: Bool

    @State private var selectedDate: Date? = nil

    private var samples: [AqiSample] {
        aqiSamples(history, isUsAqi: isUsAqi)
    }

    private var low: Int { samples.map(\.value).min() ?? 0 }
    private var high: Int { samples.map(\.value).max() ?? 0 }

    private var yMax: Int {
        let target = high + 10
        let edge = AqiPalette.bands(isUsAqi: isUsAqi).map(\.upper).first { $0 >= target } ?? 500
        return max(edge, 100)
    }

    private var visibleBands: [AqiBand] {
        AqiPalette.bands(isUsAqi: isUsAqi).filter { $0.lower < yMax }
    }

    private var axisValues: [Int] {
        [0] + visibleBands.map(\.upper).filter { $0 <= yMax }
    }

    var body: some View {
        let samples = samples
        let shown = closestSample(to: selectedDate, in: samples) ?? samples.last

        VStack(alignment: .leading, spacing: 14) {
            if let shown {
                ChartReadout(
                    caption: selectedDate == nil ? "Now" : shown.date.formatted(.dateTime.weekday(.abbreviated).hour().minute()),
                    value: "\(shown.value)",
                    detail: AqiPalette.label(shown.value, isUsAqi: isUsAqi),
                    tint: AqiPalette.color(shown.value, isUsAqi: isUsAqi)
                ) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("24h range")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(low) to \(high)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                }
            }

            if samples.isEmpty {
                Text("No data for the last 24 hours.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                chart(samples: samples, shown: shown)
            }
        }
        .card()
    }

    private func chart(samples: [AqiSample], shown: AqiSample?) -> some View {
        let first = samples.first?.date ?? Date()
        let last = samples.last?.date ?? Date()

        return Chart {
            ForEach(visibleBands) { band in
                RectangleMark(
                    xStart: .value("Start", first),
                    xEnd: .value("End", last),
                    yStart: .value("Lower", band.lower),
                    yEnd: .value("Upper", min(band.upper, yMax))
                )
                .foregroundStyle(band.color.opacity(0.09))
            }

            ForEach(samples) { sample in
                AreaMark(
                    x: .value("Time", sample.date),
                    y: .value("AQI", sample.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            AqiPalette.color(high, isUsAqi: isUsAqi).opacity(0.28),
                            AqiPalette.color(low, isUsAqi: isUsAqi).opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            ForEach(samples) { sample in
                LineMark(
                    x: .value("Time", sample.date),
                    y: .value("AQI", sample.value),
                    series: .value("Series", "halo")
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .foregroundStyle(Color.primary.opacity(0.12))
            }

            ForEach(samples) { sample in
                LineMark(
                    x: .value("Time", sample.date),
                    y: .value("AQI", sample.value),
                    series: .value("Series", "aqi")
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(AqiPalette.lineGradient(low: low, high: high, isUsAqi: isUsAqi))
            }

            if let shown {
                if selectedDate != nil {
                    RuleMark(x: .value("Selected", shown.date))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }

                PointMark(
                    x: .value("Time", shown.date),
                    y: .value("AQI", shown.value)
                )
                .symbol {
                    ChartSelectionDot(color: AqiPalette.color(shown.value, isUsAqi: isUsAqi))
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: 0...yMax)
        .chartXScale(domain: first...last)
        .chartYAxis {
            AxisMarks(position: .trailing, values: axisValues) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel(format: .dateTime.hour())
                    .font(.caption2)
            }
        }
        .frame(height: 180)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AQI over the last 24 hours")
        .accessibilityValue("Lowest \(low), highest \(high), latest \(samples.last?.value ?? 0)")
    }
}
