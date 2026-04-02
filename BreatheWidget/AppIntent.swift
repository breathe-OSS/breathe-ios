//  AppIntent.swift
//  BreatheWidget


import WidgetKit
import AppIntents

struct ZoneEntity: AppEntity {
    var id: String
    var name: String
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Zone"
    static var defaultQuery = ZoneQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct ZoneQuery: EntityQuery {
    func entities(for identifiers: [ZoneEntity.ID]) async throws -> [ZoneEntity] {
        let zones = try await BreatheAPI.shared.getZones()
        return zones.filter { identifiers.contains($0.id) }.map { ZoneEntity(id: $0.id, name: $0.name) }
    }
    
    func suggestedEntities() async throws -> [ZoneEntity] {
        let zones = try await BreatheAPI.shared.getZones()
        return zones.map { ZoneEntity(id: $0.id, name: $0.name) }
    }
    
    func defaultResult() async -> ZoneEntity? {
        let sharedDefaults = UserDefaults(suiteName: "group.com.sidharthify.Breathe")
        
        do {
            let zones = try await BreatheAPI.shared.getZones()
            
            // Prefer the user's selected zone from the app
            if let selectedId = sharedDefaults?.string(forKey: "selected_zone_id"),
               let selZone = zones.first(where: { $0.id == selectedId }) {
                return ZoneEntity(id: selZone.id, name: selZone.name)
            }
            
            // Fallback to the first pinned zone if they have one
            if let savedPinned = sharedDefaults?.data(forKey: "pinned_zones"),
               let pinnedIds = try? JSONDecoder().decode([String].self, from: savedPinned),
               let firstPinned = pinnedIds.first,
               let pinZone = zones.first(where: { $0.id == firstPinned }) {
                return ZoneEntity(id: pinZone.id, name: pinZone.name)
            }
            
            // If completely unconfigured, returning nil ensures the empty state appears
        } catch { }
        
        return nil
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Zone"
    static var description = IntentDescription("Displays AQI for a specific zone.")

    @Parameter(title: "Zone")
    var selectedZone: ZoneEntity?
}
