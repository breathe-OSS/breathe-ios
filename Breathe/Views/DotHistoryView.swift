// SPDX-License-Identifier: MIT
/*
 * DotHistoryView.swift
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

struct DotHistoryView: View {
    let history: [HistoryPoint]
    let isUsAqi: Bool

    @State private var selectedDate: Date? = nil

    var body: some View {
        let samples = aqiSamples(history, isUsAqi: isUsAqi)
        let selected = closestSample(to: selectedDate, in: samples)
        let peak = samples.max { $0.value < $1.value }
        let shown = selected ?? peak

        VStack(alignment: .leading, spacing: 14) {
            if let shown {
                ChartReadout(
                    caption: selected == nil ? "Peak" : "Selected",
                    value: "\(shown.value)",
                    detail: shown.date.formatted(.dateTime.hour().minute()),
                    tint: AqiPalette.color(shown.value, isUsAqi: isUsAqi)
                ) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Category")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(AqiPalette.label(shown.value, isUsAqi: isUsAqi))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                    }
                }
            }

            if samples.isEmpty {
                Text("No data for the last 24 hours.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                Chart(samples) { sample in
                    BarMark(
                        x: .value("Hour", sample.date, unit: .hour),
                        y: .value("AQI", sample.value),
                        width: .ratio(0.72)
                    )
                    .cornerRadius(3)
                    .foregroundStyle(AqiPalette.color(sample.value, isUsAqi: isUsAqi))
                    .opacity(selected == nil || selected?.date == sample.date ? 1 : 0.35)
                }
                .chartXSelection(value: $selectedDate)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                            .foregroundStyle(Color.secondary.opacity(0.4))
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                        AxisValueLabel(format: .dateTime.hour())
                            .font(.caption2)
                    }
                }
                .frame(height: 160)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Hourly AQI over the last 24 hours")
                .accessibilityValue("Peak \(peak?.value ?? 0)")

                AqiLegend(isUsAqi: isUsAqi)
            }
        }
        .card()
        .sensoryFeedback(.selection, trigger: selected?.date)
    }
}
