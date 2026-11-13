// SPDX-License-Identifier: MIT
/*
 * BreatheViewModel.swift
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

import Foundation
import Combine
import SwiftUI
import WidgetKit

@MainActor
final class BreatheViewModel: ObservableObject {

    @Published var zones: [Zone] = []
    @Published var sensorInfos: [SensorInfo] = []
    
    @Published var pinnedZoneIds: [String] = [] {
        didSet {
            if let encoded = try? JSONEncoder().encode(pinnedZoneIds) {
                let sharedDefaults = UserDefaults(suiteName: "group.com.sidharthify.BreatheOSS.BreatheWidget") ?? .standard
                sharedDefaults.set(encoded, forKey: "pinned_zones")
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
    
    var pinnedZones: [Zone] {
        pinnedZoneIds.compactMap { id in
            zones.first { $0.id == id }
        }
    }

    @Published var selectedZone: Zone? {
        didSet {
            let sharedDefaults = UserDefaults(suiteName: "group.com.sidharthify.BreatheOSS.BreatheWidget") ?? .standard
            if let zone = selectedZone {
                sharedDefaults.set(zone.id, forKey: "selected_zone_id")
            } else {
                sharedDefaults.removeObject(forKey: "selected_zone_id")
            }
            WidgetCenter.shared.reloadAllTimelines()
            guard let zone = selectedZone else { return }
            if let cached = allAqiData[zone.id] {
                currentAqi = cached
            }
            Task { await fetchAqi(for: zone, isMapSelection: false) }
        }
    }
    
    @Published var selectedMapZone: Zone? {
        didSet {
            guard let zone = selectedMapZone else { return }
            Task { await fetchAqi(for: zone, isMapSelection: true) }
        }
    }
    
    @Published var currentAqi: AqiResponse?
    @Published var allAqiData: [String: AqiResponse] = [:]
    private var sourceAqi: [String: AqiResponse] = [:]

    @Published var rawMode: Bool {
        didSet {
            let sharedDefaults = UserDefaults(suiteName: "group.com.sidharthify.BreatheOSS.BreatheWidget") ?? .standard
            sharedDefaults.set(rawMode, forKey: "raw_readings")
            allAqiData = sourceAqi.mapValues { shown($0) }
            if let id = currentAqi?.zoneId, let source = sourceAqi[id] {
                currentAqi = shown(source)
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    @Published var rawHintHidden: Bool {
        didSet {
            UserDefaults.standard.set(rawHintHidden, forKey: "raw_hint_hidden")
        }
    }

    private func shown(_ response: AqiResponse) -> AqiResponse {
        rawMode ? response.asRaw() : response
    }

    private func store(_ response: AqiResponse) {
        sourceAqi[response.zoneId] = response
        allAqiData[response.zoneId] = shown(response)
    }
    @Published var isLoading = false
    @Published var error: String?

    @Published var isUsAqi: Bool {
        didSet {
            let sharedDefaults = UserDefaults(suiteName: "group.com.sidharthify.BreatheOSS.BreatheWidget") ?? .standard
            sharedDefaults.set(isUsAqi, forKey: "is_us_aqi")
        }
    }

    @Published var hasOnboarded: Bool = true {
        didSet {
            let sharedDefaults = UserDefaults(suiteName: "group.com.sidharthify.BreatheOSS.BreatheWidget") ?? .standard
            sharedDefaults.set(hasOnboarded, forKey: "has_onboarded")
        }
    }

    var liveZones: [Zone] {
        zones.filter { !$0.isEstimate }
    }

    var comparablePlaces: [Zone] {
        zones.filter { !$0.isEstimate && $0.id != historyZoneId }
    }

    func displayAqi(for zoneId: String) -> Int? {
        guard let r = allAqiData[zoneId] else {
            return nil
        }
        return isUsAqi ? (r.usAqi ?? r.nAqi) : r.nAqi
    }

    /// Returns the display AQI value based on the selected standard.
    var displayAqi: Int? {
        guard let r = currentAqi else { return nil }
        return isUsAqi ? (r.usAqi ?? r.nAqi) : r.nAqi
    }

    var displayPollutant: String? {
        guard let r = currentAqi else { return nil }
        return isUsAqi ? (r.usMainPollutant ?? r.mainPollutant) : r.mainPollutant
    }

    /// Computes a 1-hour trend from the last two history entries,
    /// using the AQI field that matches the selected standard.
    var display1hTrend: Int? {
        guard let history = currentAqi?.history, history.count >= 2 else { return nil }
        let latest  = history[history.count - 1]
        let previous = history[history.count - 2]
        let latestVal  = isUsAqi ? (latest.usAqi ?? latest.aqi) : latest.aqi
        let previousVal = isUsAqi ? (previous.usAqi ?? previous.aqi) : previous.aqi
        return latestVal - previousVal
    }

    /// Formats the API's timestamp_unix into a relative time string (e.g., "25 minutes ago")
    var formattedLastUpdated: String? {
        guard let ts = currentAqi?.timestampUnix else { return nil }
        let date = Date(timeIntervalSince1970: ts)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    init() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.sidharthify.BreatheOSS.BreatheWidget") ?? .standard
        
        // Migrate from standard UserDefaults if migrating for the first time
        let oldDefaults = UserDefaults.standard
        if sharedDefaults.object(forKey: "is_us_aqi") == nil && oldDefaults.object(forKey: "is_us_aqi") != nil {
            sharedDefaults.set(oldDefaults.bool(forKey: "is_us_aqi"), forKey: "is_us_aqi")
            if let data = oldDefaults.data(forKey: "pinned_zones") {
                sharedDefaults.set(data, forKey: "pinned_zones")
            }
        }
        
        if sharedDefaults.object(forKey: "is_us_aqi") == nil {
            sharedDefaults.set(true, forKey: "is_us_aqi")
        }
        self.isUsAqi = sharedDefaults.bool(forKey: "is_us_aqi")
        self.rawMode = sharedDefaults.bool(forKey: "raw_readings")
        self.rawHintHidden = UserDefaults.standard.bool(forKey: "raw_hint_hidden")
        
        if let data = sharedDefaults.data(forKey: "pinned_zones"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.pinnedZoneIds = decoded
        }
        self.hasOnboarded = sharedDefaults.bool(forKey: "has_onboarded") || !pinnedZoneIds.isEmpty
        
        Task { await loadZones() }
    }

    func loadZones() async {
        isLoading = true
        error = nil
        do {
            let fetchedZones = try await BreatheAPI.shared.getZones()
            zones = fetchedZones
            let migrated = migratePinnedIds(pinnedZoneIds, zones: fetchedZones)
            if migrated != pinnedZoneIds {
                pinnedZoneIds = migrated
            }
            
            do {
                sensorInfos = try await BreatheAPI.shared.getSensorInfo()
            } catch {
                print("Failed to fetch sensor info: \(error)")
            }

            if pinnedZoneIds.isEmpty {
                Task { await fetchAllAqiData() }
            }
            
            // Set selection to saved selected zone if exists, otherwise fallback to first pinned
            if selectedZone == nil {
                let sharedDefaults = UserDefaults(suiteName: "group.com.sidharthify.BreatheOSS.BreatheWidget") ?? .standard
                if let savedSelectedId = sharedDefaults.string(forKey: "selected_zone_id"),
                   let matchedZone = fetchedZones.first(where: { $0.id == savedSelectedId }) {
                    selectedZone = matchedZone
                } else {
                    let currentPinned = pinnedZones
                    if let firstPinned = currentPinned.first {
                        selectedZone = firstPinned
                    }
                }
            }
#if DEBUG
            if let shotZone = ShotHooks.zone,
               let match = fetchedZones.first(where: { $0.id == shotZone }),
               selectedZone?.id != match.id {
                selectedZone = match
            }
#endif
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func fetchAqi(for zone: Zone, isMapSelection: Bool = false) async {
        isLoading = true
        do {
            let fetchedData = try await BreatheAPI.shared.getZoneAqi(zoneId: zone.id)
            store(fetchedData)
            if !isMapSelection && zone.id == selectedZone?.id {
                currentAqi = shown(fetchedData)
            }
            // Fetch the rest silently for the map
            Task { await fetchAllAqiData() }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func fetchAllAqiData() async {
        let missing = zones.filter { allAqiData[$0.id] == nil }.map(\.id)
        guard !missing.isEmpty else {
            return
        }

        // one /aqi/zones request when the backend has it. older backends 404,
        // and then it goes back to asking zone by zone
        if let bulk = try? await BreatheAPI.shared.getZonesAqi(zoneIds: missing) {
            for response in bulk {
                store(response)
            }
            return
        }

        await withTaskGroup(of: (String, AqiResponse?).self) { group in
            for zone in zones where allAqiData[zone.id] == nil {
                group.addTask {
                    do {
                        let response = try await BreatheAPI.shared.getZoneAqi(zoneId: zone.id)
                        return (zone.id, response)
                    } catch {
                        return (zone.id, nil)
                    }
                }
            }
            
            for await (zoneId, response) in group {
                if let response = response {
                    store(response)
                }
            }
        }
    }

    func refresh() async {
        guard let zone = selectedZone else {
            await loadZones()
            return
        }
        await fetchAqi(for: zone)
    }

    func dismissError() {
        error = nil
    }
    
    func togglePin(for zone: Zone) {
        var currentIds = pinnedZoneIds
        if let index = currentIds.firstIndex(of: zone.id) {
            currentIds.remove(at: index)
        } else {
            currentIds.append(zone.id)
        }
        pinnedZoneIds = currentIds

        if !currentIds.isEmpty && !hasOnboarded {
            hasOnboarded = true
        }
        
        // Handle selection logic when pinning/unpinning
        let currentPinned = pinnedZones
        if !currentPinned.contains(where: { $0.id == selectedZone?.id }) {
            selectedZone = currentPinned.first
        }
    }

    func movePinnedZones(from source: IndexSet, to destination: Int) {
        var currentIds = pinnedZoneIds
        currentIds.move(fromOffsets: source, toOffset: destination)
        pinnedZoneIds = currentIds
    }

    // MARK: - Extended History

    @Published var historyState = HistoryState()

    private var historyZoneId: String?
    private var historyFetchTask: Task<Void, Never>?
    private var compareFetchTask: Task<Void, Never>?

    func openHistory(zoneId: String) {
        let sameZone = historyZoneId == zoneId
        let previous = historyState
        historyZoneId = zoneId
        var next = HistoryState()
        next.metric = previous.metric
        next.mode = rawMode ? .raw : .cal
        next.compareIds = sameZone ? previous.compareIds : []
        historyState = next
        fetchHistoricalData()
    }

    func setHistoryRange(_ range: String) {
        historyState.selectedRange = range
        historyState.interval = "1h"
        historyState.showCustomInputs = false
        historyState.periodActive = false
        fetchHistoricalData()
    }

    func toggleHistoryCustomInputs() {
        historyState.showCustomInputs.toggle()
        historyState.periodActive = false
    }

    func showHistoryPeriod() {
        let mode = historyState.periodMode
        let period = historyState.period ?? HistoryPeriod.containing(mode: mode, date: Date())
        applyHistoryPeriod(mode: mode, period: period)
    }

    func setHistoryPeriodMode(_ mode: HistoryPeriodMode) {
        let today = Date()
        let anchor = min(historyState.period?.end ?? today, today)
        applyHistoryPeriod(mode: mode, period: HistoryPeriod.containing(mode: mode, date: anchor))
    }

    func stepHistoryPeriod(by direction: Int) {
        guard let period = historyState.period else { return }
        let mode = historyState.periodMode
        applyHistoryPeriod(mode: mode, period: period.shifted(mode: mode, by: direction))
    }

    func pickHistoryPeriodDate(_ date: Date) {
        let mode = historyState.periodMode
        applyHistoryPeriod(mode: mode, period: HistoryPeriod.containing(mode: mode, date: date))
    }

    func pickHistoryPeriodSpan(from start: Date, to end: Date) {
        applyHistoryPeriod(mode: .days, period: HistoryPeriod.span(from: start, to: end))
    }

    private func applyHistoryPeriod(mode: HistoryPeriodMode, period: HistoryPeriod) {
        historyState.periodActive = true
        historyState.periodMode = mode
        historyState.period = period
        historyState.selectedRange = period.token
        historyState.interval = "1h"
        historyState.showCustomInputs = false
        fetchHistoricalData()
    }

    func setCustomRange(_ range: String) {
        historyState.customRange = range
    }

    func setCustomInterval(_ interval: String) {
        historyState.customInterval = interval
    }

    func applyCustomHistory() {
        let interval = historyState.customInterval.trimmingCharacters(in: .whitespaces)
        historyState.selectedRange = historyState.customRange.trimmingCharacters(in: .whitespaces)
        historyState.interval = interval.isEmpty ? "1h" : interval
        fetchHistoricalData()
    }

    func setHistoryMetric(_ metric: HistoryMetric) {
        historyState.metric = metric
    }

    func setHistoryMode(_ mode: HistoryMode) {
        historyState.mode = mode
    }

    func setWeatherFilter(_ condition: String) {
        historyState.weatherFilter = condition
    }

    func toggleCompare(_ id: String) {
        if let index = historyState.compareIds.firstIndex(of: id) {
            historyState.compareIds.remove(at: index)
        } else {
            historyState.compareIds.append(id)
        }
        fetchCompareRows()
    }

    func setCompareIds(_ ids: [String]) {
        historyState.compareIds = ids
        fetchCompareRows()
    }

    private func fetchHistoricalData() {
        guard let zoneId = historyZoneId else { return }
        let state = historyState

        historyState.isLoading = true
        historyState.error = nil
        historyState.compareRows = [:]

        historyFetchTask?.cancel()
        historyFetchTask = Task {
            do {
                async let historyTask = BreatheAPI.shared.getHistoricalData(
                    location: zoneId,
                    timeRange: state.selectedRange,
                    interval: state.interval,
                    metrics: historyMetrics
                )
                async let weatherTask = optionalWeatherHistory(
                    zoneId: zoneId,
                    timeRange: state.selectedRange,
                    interval: state.interval
                )

                let response = try await historyTask
                let weather = await weatherTask
                guard !Task.isCancelled else { return }
                let rows = response.data.sorted { $0.ts < $1.ts }
                let groups = weatherPm25Groups(data: rows, weather: weather)
                let nextFilter: String
                if state.weatherFilter != "all" && (groups[state.weatherFilter]?.count ?? 0) == 0 {
                    nextFilter = "all"
                } else {
                    nextFilter = state.weatherFilter
                }

                historyState.isLoading = false
                historyState.data = rows
                historyState.weatherHistory = weather
                historyState.weatherFilter = nextFilter
                fetchCompareRows()
            } catch {
                guard !Task.isCancelled else { return }
                historyState.isLoading = false
                historyState.error = "Failed to load: \(error.localizedDescription)"
            }
        }
    }

    private func fetchCompareRows() {
        let state = historyState
        let missing = state.compareIds.filter { state.compareRows[$0] == nil }
        guard !missing.isEmpty else { return }
        historyState.compareLoading = true
        compareFetchTask?.cancel()
        let range = state.selectedRange
        let interval = state.interval
        compareFetchTask = Task {
            var results: [String: [HistoricalDataPoint]] = [:]
            await withTaskGroup(of: (String, [HistoricalDataPoint]).self) { group in
                for id in missing {
                    group.addTask {
                        let rows = (try? await BreatheAPI.shared.getHistoricalData(
                            location: id,
                            timeRange: range,
                            interval: interval,
                            metrics: historyMetrics
                        ).data) ?? []
                        return (id, rows.sorted { $0.ts < $1.ts })
                    }
                }
                for await (id, rows) in group {
                    results[id] = rows
                }
            }
            guard !Task.isCancelled,
                  historyState.selectedRange == range,
                  historyState.interval == interval else {
                return
            }
            historyState.compareRows.merge(results) { _, new in new }
            historyState.compareLoading = false
        }
    }

    private func optionalWeatherHistory(
        zoneId: String,
        timeRange: String,
        interval: String
    ) async -> WeatherHistory? {
        try? await BreatheAPI.shared.getWeatherHistory(
            zoneId: zoneId,
            timeRange: timeRange,
            interval: interval
        )
    }

    func historyCSVURL() -> URL? {
        guard let zoneId = historyZoneId else { return nil }
        let state = historyState
        return URL(string: "https://api.breatheoss.app/historical-data/\(zoneId)/\(state.selectedRange)/\(state.interval)/\(historyMetrics)?format=csv")
    }
}
