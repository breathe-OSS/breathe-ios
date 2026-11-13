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

private struct DistrictGroup: Identifiable {
    let id: String
    let district: String
    let division: String
    let places: [Zone]
}

struct SearchView: View {
    @EnvironmentObject private var viewModel: BreatheViewModel
    @State private var searchText = ""
    @State private var openZone: Zone?

    private var groups: [DistrictGroup] {
        let needle = searchText.trimmingCharacters(in: .whitespaces)
        let grouped = Dictionary(grouping: viewModel.zones) { zone in
            "\(zone.division ?? "Other")/\(zone.district ?? zone.name)"
        }
        return grouped.compactMap { key, zones -> DistrictGroup? in
            let district = zones.first?.district ?? zones.first?.name ?? key
            let division = zones.first?.division ?? "Other"
            var places = zones.sorted { lhs, rhs in
                if lhs.isEstimate != rhs.isEstimate {
                    return !lhs.isEstimate
                }
                return lhs.name < rhs.name
            }
            if !needle.isEmpty && !district.localizedCaseInsensitiveContains(needle) {
                places = places.filter { $0.name.localizedCaseInsensitiveContains(needle) }
            }
            if places.isEmpty {
                return nil
            }
            return DistrictGroup(id: key, district: district, division: division, places: places)
        }
        .sorted { lhs, rhs in
            if divisionRank(lhs.division) != divisionRank(rhs.division) {
                return divisionRank(lhs.division) < divisionRank(rhs.division)
            }
            return lhs.district < rhs.district
        }
    }

    private var divisions: [String] {
        var seen: [String] = []
        for group in groups where !seen.contains(group.division) {
            seen.append(group.division)
        }
        return seen
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading && viewModel.zones.isEmpty {
                    ProgressView("Loading places...")
                        .frame(maxWidth: .infinity)
                } else if groups.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(divisions, id: \.self) { division in
                        Section(division) {
                            ForEach(groups.filter { $0.division == division }) { group in
                                districtRow(group)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Explore")
            .searchable(text: $searchText, prompt: "Sensor or district")
            .refreshable {
                await viewModel.loadZones()
            }
            .task {
                await viewModel.fetchAllAqiData()
            }
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.pinnedZoneIds)
            .sheet(item: $openZone) { zone in
                ZoneSheet(zone: zone)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    @ViewBuilder
    private func districtRow(_ group: DistrictGroup) -> some View {
        if group.places.count == 1, let place = group.places.first {
            placeRow(place, title: "\(group.district) district", subtitle: summary(group))
        } else {
            DisclosureGroup {
                ForEach(group.places) { place in
                    placeRow(place, title: place.name, subtitle: kindText(place))
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(group.district) district")
                            .font(.body)
                            .fontWeight(.semibold)
                        Text(summary(group))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    aqiChip(group.places.compactMap { viewModel.displayAqi(for: $0.id) }.max())
                }
            }
        }
    }

    private func placeRow(_ place: Zone, title: String, subtitle: String) -> some View {
        let isPinned = viewModel.pinnedZoneIds.contains(place.id)
        return Button {
            openZone = place
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    HStack(spacing: 4) {
                        if !place.isEstimate {
                            Circle()
                                .fill(isOffline(place) ? Color.gray : Color.green)
                                .frame(width: 6, height: 6)
                        }
                        Text(subtitle)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                aqiChip(viewModel.displayAqi(for: place.id))
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Pinned")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                viewModel.togglePin(for: place)
            } label: {
                Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin")
            }
            .tint(isPinned ? .gray : .accentColor)
        }
        .contextMenu {
            Button {
                viewModel.selectedZone = place
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
            } label: {
                Label("View on Home", systemImage: "house")
            }
            Button {
                viewModel.togglePin(for: place)
            } label: {
                Label(isPinned ? "Unpin" : "Pin to Home", systemImage: isPinned ? "pin.slash" : "pin")
            }
        }
    }

    private func isOffline(_ place: Zone) -> Bool {
        viewModel.allAqiData[place.id]?.isSensorOffline == true
    }

    private func kindText(_ place: Zone) -> String {
        if place.isEstimate {
            return "Satellite estimate"
        }
        return isOffline(place) ? "Offline, showing a satellite estimate" : "Live sensor"
    }

    private func summary(_ group: DistrictGroup) -> String {
        let sensors = group.places.filter { !$0.isEstimate }.count
        let estimates = group.places.count - sensors
        if group.places.count == 1, let only = group.places.first {
            if only.isEstimate {
                return only.name == group.district ? "Satellite estimate" : "\(only.name) · satellite estimate"
            }
            return isOffline(only) ? "\(only.name) · offline" : "\(only.name) · 1 sensor"
        }
        var parts: [String] = []
        if sensors > 0 {
            parts.append(sensors == 1 ? "1 sensor" : "\(sensors) sensors")
        }
        if estimates > 0 {
            parts.append(estimates == 1 ? "1 satellite estimate" : "\(estimates) satellite estimates")
        }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private func aqiChip(_ aqi: Int?) -> some View {
        if let aqi {
            Text("\(aqi)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .foregroundStyle(AqiPalette.onColor(aqi, isUsAqi: viewModel.isUsAqi))
                .background(Capsule().fill(AqiPalette.color(aqi, isUsAqi: viewModel.isUsAqi)))
                .accessibilityLabel("AQI \(aqi), \(AqiPalette.label(aqi, isUsAqi: viewModel.isUsAqi))")
        }
    }
}
