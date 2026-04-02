import Foundation
import Combine
import SwiftUI

@MainActor
final class BreatheViewModel: ObservableObject {

    @Published var zones: [Zone] = []
    
    @Published var pinnedZoneIds: [String] = [] {
        didSet {
            if let encoded = try? JSONEncoder().encode(pinnedZoneIds) {
                UserDefaults.standard.set(encoded, forKey: "pinned_zones")
            }
        }
    }
    
    var pinnedZones: [Zone] {
        zones.filter { pinnedZoneIds.contains($0.id) }
    }

    @Published var selectedZone: Zone? {
        didSet {
            guard let zone = selectedZone else { return }
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
    @Published var isLoading = false
    @Published var error: String?

    @Published var isUsAqi: Bool {
        didSet {
            UserDefaults.standard.set(isUsAqi, forKey: "is_us_aqi")
        }
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
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "is_us_aqi") == nil {
            defaults.set(true, forKey: "is_us_aqi")
        }
        self.isUsAqi = defaults.bool(forKey: "is_us_aqi")
        
        if let data = UserDefaults.standard.data(forKey: "pinned_zones"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.pinnedZoneIds = decoded
        }
        
        Task { await loadZones() }
    }

    func loadZones() async {
        isLoading = true
        error = nil
        do {
            let fetched = try await BreatheAPI.shared.getZones()
            zones = fetched
            
            // Set selection to first pinned zone if exists, otherwise keep nil
            if selectedZone == nil {
                let currentPinned = pinnedZones
                if let firstPinned = currentPinned.first {
                    selectedZone = firstPinned
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func fetchAqi(for zone: Zone, isMapSelection: Bool = false) async {
        isLoading = true
        do {
            let fetchedData = try await BreatheAPI.shared.getZoneAqi(zoneId: zone.id)
            if !isMapSelection {
                currentAqi = fetchedData
            }
            allAqiData[zone.id] = fetchedData
            // Fetch the rest silently for the map
            Task { await fetchAllAqiData() }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func fetchAllAqiData() async {
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
                    allAqiData[zoneId] = response
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
        
        // Handle selection logic when pinning/unpinning
        let currentPinned = pinnedZones
        if !currentPinned.contains(where: { $0.id == selectedZone?.id }) {
            selectedZone = currentPinned.first
        }
    }
}
