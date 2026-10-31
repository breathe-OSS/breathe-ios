// SPDX-License-Identifier: MIT
/*
 * SearchView.swift
 *
 * Copyright (C) 2026 The Breathe Open Source Project
 * Copyright (C) 2026 SleeperOfSaturn <sanidhya1998@icloud.com>
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

struct SearchView: View {
    @EnvironmentObject private var viewModel: BreatheViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var searchText = ""

    private let threeColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    private var filteredZones: [Zone] {
        if searchText.isEmpty {
            return viewModel.zones
        } else {
            return viewModel.zones.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var liveZones: [Zone] {
        filteredZones.filter { isLive($0) }
    }

    private var modelZones: [Zone] {
        filteredZones.filter { !isLive($0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sizeClass == .regular {
                    gridContent
                } else {
                    listContent
                }
            }
            .navigationTitle("Search & Pin Zones")
            .searchable(text: $searchText, prompt: "Search locations...")
            .refreshable {
                await viewModel.loadZones()
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        List {
            if viewModel.isLoading && viewModel.zones.isEmpty {
                ProgressView("Loading zones...")
            } else {
                if !liveZones.isEmpty {
                    Section {
                        ForEach(liveZones) { zone in
                            zoneRow(zone)
                        }
                    } header: {
                        sectionHeader(title: "Live Ground Sensors", subtitle: "Real-time readings from AirGradient sensors")
                    }
                }

                if !modelZones.isEmpty {
                    Section {
                        ForEach(modelZones) { zone in
                            zoneRow(zone)
                        }
                    } header: {
                        sectionHeader(title: "Satellite & Model Data", subtitle: "Ground sensors coming soon")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private var gridContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if viewModel.isLoading && viewModel.zones.isEmpty {
                    ProgressView("Loading zones...")
                        .frame(maxWidth: .infinity)
                } else {
                    if !liveZones.isEmpty {
                        zoneGridSection(
                            title: "Live Ground Sensors",
                            subtitle: "Real-time readings from AirGradient sensors",
                            zones: liveZones
                        )
                    }

                    if !modelZones.isEmpty {
                        zoneGridSection(
                            title: "Satellite & Model Data",
                            subtitle: "Ground sensors coming soon",
                            zones: modelZones// SPDX-License-Identifier: MIT
/*
 * SearchView.swift
 *
 * Copyright (C) 2026 The Breathe Open Source Project
 * Copyright (C) 2026 SleeperOfSaturn <sanidhya1998@icloud.com>
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
struct SearchView: View {
@EnvironmentObject private var viewModel: BreatheViewModel
@State private var searchText = ""

var filteredZones: [Zone] {
    if searchText.isEmpty {
        return viewModel.zones
    } else {
        return viewModel.zones.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
}

var body: some View {

    NavigationStack {

        List {

            if viewModel.isLoading && viewModel.zones.isEmpty {

                ProgressView("Loading zones...")

            } else {

                let liveZones = filteredZones.filter { isLive($0) }
                let modelZones = filteredZones.filter { !isLive($0) }

                if !liveZones.isEmpty {
                    Section {
                        ForEach(liveZones) { zone in
                            zoneRow(zone)
                        }
                    } header: {
                        sectionHeader(title: "Live Ground Sensors", subtitle: "Real-time readings from AirGradient sensors")
                    }
                }

                if !modelZones.isEmpty {
                    Section {
                        ForEach(modelZones) { zone in
                            zoneRow(zone)
                        }
                    } header: {
                        sectionHeader(title: "Satellite & Model Data", subtitle: "Ground sensors coming soon")
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Search & Pin Zones")
        .searchable(text: $searchText, prompt: "Search locations...")
        .refreshable {
            await viewModel.loadZones()
        }
    }
}

private func isLive(_ zone: Zone) -> Bool {
    zone.provider?.localizedCaseInsensitiveContains("airgradient") == true
}

private func sectionHeader(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(title)
            .font(.system(.subheadline, design: .rounded))
            .fontWeight(.bold)
            .foregroundStyle(Color.accentColor)
            .textCase(nil)

        Text(subtitle)
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.secondary)
            .textCase(nil)
    }
}

@ViewBuilder
private func zoneRow(_ zone: Zone) -> some View {
    let isPinned = viewModel.pinnedZoneIds.contains(zone.id)

    Button {

        viewModel.togglePin(for: zone)

    } label: {

        HStack(spacing: 12) {

            Image(systemName: "location.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {

                Text(zone.name)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)

                if let provider = zone.provider {

                    if provider.localizedCaseInsensitiveContains("airgradient") {

                        HStack(spacing: 4) {

                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)

                            Text("Live Ground Sensors")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    } else if provider.localizedCaseInsensitiveContains("open-meteo") || provider.localizedCaseInsensitiveContains("openmeteo") {

                        Text("Satellite & Model Data")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {

                        Text(provider)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: isPinned ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(
                    isPinned
                    ? Color.accentColor
                    : Color.secondary.opacity(0.5)
                )
        }
        .padding(.vertical, 12)
        .opacity(isPinned ? 1 : 0.85)
    }
    .buttonStyle(.plain)
    .animation(.easeInOut(duration: 0.15), value: isPinned)
}
}
