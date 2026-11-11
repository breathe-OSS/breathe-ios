// SPDX-License-Identifier: MIT
/*
 * NodeReadingCard.swift
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

struct NodeReadingCard: View {
    let nodeName: String
    let reading: NodeReading
    let isUsAqi: Bool

    @State private var showingSensorInfo = false
    @EnvironmentObject private var viewModel: BreatheViewModel

    private var isDown: Bool { reading.pm25 == nil }

    private var displayAqi: Int? {
        guard !isDown else {
            return nil
        }
        if isUsAqi {
            return reading.usAqi ?? reading.aqi
        }
        return reading.aqi
    }

    private var aqiLabelStr: String { AqiPalette.standardName(isUsAqi: isUsAqi) }

    var body: some View {
        Button {
            showingSensorInfo = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 4) {
                    Text(nodeName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }

                if let aqi = displayAqi {
                    AqiChip(aqi: aqi, isUsAqi: isUsAqi)
                } else {
                    Label("Offline", systemImage: "wifi.slash")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }

                HStack(spacing: 12) {
                    metric("PM2.5", reading.pm25)
                    metric("PM10", reading.pm10)
                }
            }
            .card(padding: 14)
            .opacity(isDown ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows sensor details")
        .sheet(isPresented: $showingSensorInfo) {
            NodeDetailSheet(
                nodeName: nodeName,
                reading: reading,
                isUsAqi: isUsAqi,
                displayAqi: displayAqi,
                aqiLabelStr: aqiLabelStr,
                sensorInfo: getSensorInfo()
            )
            .presentationDetents([.medium, .large])
        }
#if DEBUG
        .task {
            if ShotHooks.nodeToOpen(in: viewModel.currentAqi?.nodes) == nodeName {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                showingSensorInfo = true
            }
        }
#endif
    }

    private func metric(_ label: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.map { String(format: "%.1f", $0) } ?? "N/A")
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func getSensorInfo() -> SensorInfo? {
        let zoneName = viewModel.currentAqi?.zoneName
        return viewModel.sensorInfos.first { $0.name == nodeName && $0.zone == zoneName }
            ?? viewModel.sensorInfos.first { $0.name == nodeName }
    }
}

struct AqiChip: View {
    let aqi: Int
    let isUsAqi: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("\(aqi)")
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()
            Text(AqiPalette.standardName(isUsAqi: isUsAqi))
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .foregroundStyle(AqiPalette.onColor(aqi, isUsAqi: isUsAqi))
        .background(Capsule().fill(AqiPalette.color(aqi, isUsAqi: isUsAqi)))
    }
}

struct NodeDetailSheet: View {
    let nodeName: String
    let reading: NodeReading
    let isUsAqi: Bool
    let displayAqi: Int?
    let aqiLabelStr: String
    let sensorInfo: SensorInfo?
    var onOpenZone: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            List {
                if reading.pm25 == nil {
                    Section {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sensor offline")
                                    .font(.headline)
                                Text("It hasn't sent a reading lately, so there's nothing to show until it reconnects.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "wifi.slash")
                                .foregroundStyle(.orange)
                        }
                    }
                } else {
                    Section {
                        HStack {
                            Text("AQI")
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let aqi = displayAqi {
                                AqiChip(aqi: aqi, isUsAqi: isUsAqi)
                            }
                        }
                        if let aqi = displayAqi {
                            infoRow("Category", AqiPalette.label(aqi, isUsAqi: isUsAqi))
                        }
                        infoRow("PM2.5", reading.pm25.map { String(format: "%.1f µg/m³", $0) })
                        infoRow("PM10", reading.pm10.map { String(format: "%.1f µg/m³", $0) })
                        infoRow("Temperature", reading.temp.map { String(format: "%.1f °C", $0) })
                        infoRow("Humidity", reading.humidity.map { String(format: "%.0f%%", $0) })
                    } header: {
                        Text("Readings")
                    } footer: {
                        Text("Temperature and humidity are measured inside the sensor housing to correct the PM readings, so they can differ from the air outside.")
                    }
                }

                if let info = sensorInfo {
                    Section("Sensor") {
                        infoRow("Zone", info.zone)
                        infoRow("Provider", info.provider)
                        infoRow("Model", info.model)
                        infoRow("Location ID", "\(info.locationId)")
                        infoRow("Installed", info.installationDate)
                    }
                }

                if let onOpenZone {
                    Section {
                        Button(action: onOpenZone) {
                            Label("Open \(sensorInfo?.zone ?? "zone")", systemImage: "arrow.up.forward.square")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(nodeName)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
        }
    }

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String?) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value ?? "N/A")
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
