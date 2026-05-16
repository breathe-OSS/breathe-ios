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

    @Environment(\.colorScheme) var colorScheme
    @State private var showingSensorInfo = false
    @EnvironmentObject private var viewModel: BreatheViewModel

    // Mirrors Android logic: if pm25 is nil the sensor is offline
    private var isDown: Bool { reading.pm25 == nil }

    // Pick the right AQI value based on the selected standard
    private var displayAqi: Int? {
        guard !isDown else { return nil }
        if isUsAqi {
            return reading.usAqi ?? reading.aqi
        } else {
            return reading.aqi
        }
    }

    private var aqiLabelStr: String { isUsAqi ? "US AQI" : "NAQI" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header row: node name + menu button ──
            HStack {
                Text(nodeName)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button {
                    showingSensorInfo = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 4)

            // ── AQI value ──
            if isDown {
                Text("N/A")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Text(displayAqi.map { "\($0)" } ?? "—")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(nodeAqiColor)
                    .monospacedDigit()
            }

            Text(aqiLabelStr)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, 10)

            Divider()
                .opacity(0.4)
                .padding(.bottom, 8)

            // ── PM2.5 / PM10 side by side ──
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PM2.5")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(isDown ? "N/A" : (reading.pm25.map { formatValue($0) } ?? "—"))
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("PM10")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(isDown ? "N/A" : (reading.pm10.map { formatValue($0) } ?? "—"))
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .onLongPressGesture {
            showingSensorInfo = true
        }
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
    }

    // MARK: - Helpers

    private var nodeAqiColor: Color {
        guard let aqi = displayAqi else { return .secondary }
        return aqiColorFor(aqi: aqi, isUsAqi: isUsAqi)
    }

    private func formatValue(_ v: Double) -> String {
        String(format: "%.1f", v)
    }

    private func getSensorInfo() -> SensorInfo? {
        viewModel.sensorInfos.first { $0.name == nodeName }
    }

    private func aqiColorFor(aqi: Int, isUsAqi: Bool) -> Color {
        if isUsAqi {
            switch aqi {
            case ..<51:  return Color(red: 0/255, green: 228/255, blue: 0/255)
            case ..<101: return Color(red: 255/255, green: 255/255, blue: 0/255)
            case ..<151: return Color(red: 255/255, green: 126/255, blue: 0/255)
            case ..<201: return Color(red: 255/255, green: 0/255, blue: 0/255)
            case ..<301: return Color(red: 143/255, green: 63/255, blue: 151/255)
            default:     return Color(red: 126/255, green: 0/255, blue: 35/255)
            }
        } else {
            switch aqi {
            case ..<51:  return Color(red: 0/255, green: 176/255, blue: 80/255)
            case ..<101: return Color(red: 146/255, green: 208/255, blue: 80/255)
            case ..<201: return Color(red: 255/255, green: 255/255, blue: 0/255)
            case ..<301: return Color(red: 244/255, green: 145/255, blue: 28/255)
            case ..<401: return Color(red: 233/255, green: 63/255, blue: 51/255)
            default:     return Color(red: 175/255, green: 45/255, blue: 36/255)
            }
        }
    }

    private var cardBackground: Color {
#if os(iOS)
        return Color(UIColor.secondarySystemGroupedBackground)
#elseif os(macOS)
        return Color(NSColor.windowBackgroundColor)
#else
        return Color.gray.opacity(0.1)
#endif
    }
}

// MARK: - Detail sheet (mirrors Android's ModalBottomSheet content)

private struct NodeDetailSheet: View {
    let nodeName: String
    let reading: NodeReading
    let isUsAqi: Bool
    let displayAqi: Int?
    let aqiLabelStr: String
    let sensorInfo: SensorInfo?

    var body: some View {
        NavigationStack {
            List {
                if reading.pm25 == nil {
                    Section {
                        Label("Sensor is currently offline.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                } else {
                    Section(header: Text("Readings")) {
                        infoRow("AQI", displayAqi.map { "\($0)" } ?? "—")
                        infoRow("AQI Standard", aqiLabelStr)
                        infoRow("PM2.5", reading.pm25.map { String(format: "%.2f µg/m³", $0) } ?? "—")
                        infoRow("PM10", reading.pm10.map { String(format: "%.2f µg/m³", $0) } ?? "—")
                        infoRow("Temperature", reading.temp.map { String(format: "%.1f °C", $0) } ?? "—")
                        infoRow("Humidity", reading.humidity.map { String(format: "%.1f%%", $0) } ?? "—")
                    }
                }

                if let info = sensorInfo {
                    Section(header: Text("Hardware")) {
                        infoRow("Provider", info.provider)
                        infoRow("Model", info.model)
                        infoRow("Location ID", "\(info.locationId)")
                        infoRow("Install Date", info.installationDate)
                    }
                }
            }
            .navigationTitle(nodeName)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
        }
    }

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
    }
}
