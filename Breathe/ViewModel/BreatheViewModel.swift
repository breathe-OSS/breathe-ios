import Foundation
import Combine

@MainActor
final class BreatheViewModel: ObservableObject {

    @Published var zones: [Zone] = []
    @Published var selectedZone: Zone? {
        didSet {
            guard let zone = selectedZone else { return }
            Task { await fetchAqi(for: zone) }
        }
    }
    @Published var currentAqi: AqiResponse?
    @Published var isLoading = false
    @Published var error: String?

    @Published var isUsAqi: Bool {
        didSet { UserDefaults.standard.set(isUsAqi, forKey: "is_us_aqi") }
    }

    /// Returns the display AQI value based on the selected standard.
    var displayAqi: Int? {
        guard let r = currentAqi else { return nil }
        // isUsAqi = false → Indian NAQI (nAqi field)
        // isUsAqi = true  → US AQI (usAqi field, fallback to nAqi)
        return isUsAqi ? (r.usAqi ?? r.nAqi) : r.nAqi
    }

    var displayPollutant: String? {
        guard let r = currentAqi else { return nil }
        return isUsAqi ? (r.usMainPollutant ?? r.mainPollutant) : r.mainPollutant
    }

    init() {
        isUsAqi = UserDefaults.standard.bool(forKey: "is_us_aqi")
        Task { await loadZones() }
    }

    func loadZones() async {
        isLoading = true
        error = nil
        do {
            let fetched = try await BreatheAPI.shared.getZones()
            zones = fetched
            if selectedZone == nil, let first = fetched.first {
                selectedZone = first          // triggers didSet → fetchAqi
            }
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    func fetchAqi(for zone: Zone) async {
        isLoading = true
        do {
            currentAqi = try await BreatheAPI.shared.getZoneAqi(zoneId: zone.id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
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
}
