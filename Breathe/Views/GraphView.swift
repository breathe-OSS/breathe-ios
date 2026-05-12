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

// Unified history point for the chart – works for both zone history and node history.
private struct ChartPoint: Identifiable {
    let id = UUID()
    let ts: Int
    let aqi: Int
    let usAqi: Int?
}

struct GraphView: View {
    let history: [HistoryPoint]
    let isUsAqi: Bool

    /// Optional node map – when provided, a Picker lets the user switch between
    /// the zone average and any individual node, mirroring the website's chart-node-select
    /// dropdown and Android's AqiHistoryGraph(nodes:) parameter.
    var nodes: [String: NodeReading]? = nil

    // MARK: – Selection state

    // nil means "Zone Average"
    @State private var selectedNodeName: String? = nil
    @State private var selectedPoint: ChartPoint? = nil

    // MARK: – Derived

    private var nodeNamesWithHistory: [String] {
        guard let nodes else { return [] }
        return nodes.keys.filter { name in
            if let h = nodes[name]?.history { return !h.isEmpty }
            return false
        }.sorted()
    }

    private var activePoints: [ChartPoint] {
        if let name = selectedNodeName,
           let nodeHistory = nodes?[name]?.history {
            return nodeHistory.sorted { $0.ts < $1.ts }.map {
                ChartPoint(ts: $0.ts, aqi: $0.aqi, usAqi: $0.usAqi)
            }
        }
        return history.sorted { $0.ts < $1.ts }.map {
            ChartPoint(ts: $0.ts, aqi: $0.aqi, usAqi: $0.usAqi)
        }
    }

    private func value(for point: ChartPoint) -> Int {
        isUsAqi ? (point.usAqi ?? point.aqi) : point.aqi
    }

    // MARK: – Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row: title + optional node picker
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("24-Hour Trend")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if let name = selectedNodeName {
                        Text(name)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    } else if !nodeNamesWithHistory.isEmpty {
                        Text("Zone Average")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }

                Spacer()

                if !nodeNamesWithHistory.isEmpty {
                    Menu {
                        Button {
                            withAnimation { selectedNodeName = nil }
                        } label: {
                            Label(
                                "Zone Average",
                                systemImage: selectedNodeName == nil ? "checkmark" : ""
                            )
                        }

                        Divider()

                        ForEach(nodeNamesWithHistory, id: \.self) { name in
                            Button {
                                withAnimation { selectedNodeName = name }
                            } label: {
                                Label(
                                    name,
                                    systemImage: selectedNodeName == name ? "checkmark" : ""
                                )
                            }
                        }
                    } label: {
                        Label("Select node", systemImage: "slider.horizontal.3")
                            .font(.system(.caption, design: .rounded))
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
            }

            if activePoints.isEmpty {
                Text("No data available for the last 24 hours.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(activePoints) { point in
                        let val = value(for: point)
                        let date = Date(timeIntervalSince1970: TimeInterval(point.ts))

                        LineMark(
                            x: .value("Time", date),
                            y: .value("AQI", val)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.accentColor)
                        .lineStyle(StrokeStyle(lineWidth: 3))

                        AreaMark(
                            x: .value("Time", date),
                            y: .value("AQI", val)
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
                        let val = value(for: selected)
                        let date = Date(timeIntervalSince1970: TimeInterval(selected.ts))

                        RuleMark(x: .value("Time", date))
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
                                            selectedPoint = findClosestPoint(to: date, in: activePoints)
                                        }
                                    }
                                    .onEnded { _ in selectedPoint = nil }
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
        .onChange(of: selectedNodeName) { _ in
            selectedPoint = nil
        }
    }

    // MARK: – Helpers

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

    private func findClosestPoint(to date: Date, in points: [ChartPoint]) -> ChartPoint? {
        let targetTimestamp = date.timeIntervalSince1970
        return points.min { a, b in
            abs(Double(a.ts) - targetTimestamp) < abs(Double(b.ts) - targetTimestamp)
        }
    }
}
