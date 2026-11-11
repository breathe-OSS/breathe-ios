// SPDX-License-Identifier: MIT
/*
 * DataSourcesView.swift
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

struct DataSourcesView: View {
    @EnvironmentObject private var viewModel: BreatheViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var sensorZones: [Zone] {
        viewModel.zones
            .filter { $0.provider?.localizedCaseInsensitiveContains("airgradient") == true }
            .sorted { $0.name < $1.name }
    }

    private var modelZoneCount: Int {
        viewModel.zones.count - sensorZones.count
    }

    private func sensorCount(for zone: Zone) -> Int {
        viewModel.sensorInfos.filter { $0.zone == zone.name }.count
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    ProviderLogo(name: "air_gradient_logo", height: 28)
                    Text("Outdoor AirGradient sensors measure PM2.5 and PM10 on the ground. Where a zone has more than one, Breathe averages the ones that are reporting.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)

                ForEach(sensorZones) { zone in
                    let count = sensorCount(for: zone)
                    HStack {
                        Text(zone.name)
                        Spacer()
                        if count > 0 {
                            Text(count == 1 ? "1 sensor" : "\(count) sensors")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                LinkRow(title: "airgradient.com", systemImage: "globe", url: "https://www.airgradient.com/")
            } header: {
                Text("Ground Sensors")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    ProviderLogo(
                        name: colorScheme == .dark ? "open_meteo_logo" : "open_meteo_logo_light",
                        height: 28
                    )
                    Text("Open-Meteo's air quality model supplies the gases everywhere and PM2.5 and PM10 for the \(modelZoneCount) zones without a sensor. It also stands in when a zone's sensors go offline. Weather comes from Open-Meteo too.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)

                LinkRow(title: "open-meteo.com", systemImage: "globe", url: "https://open-meteo.com/")
            } header: {
                Text("Satellite and Model Data")
            }
        }
        .navigationTitle("Data Sources")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}
