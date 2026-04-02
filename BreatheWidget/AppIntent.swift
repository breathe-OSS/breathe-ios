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
        // Default to first few zones just for suggestion 
        return Array(zones.prefix(20)).map { ZoneEntity(id: $0.id, name: $0.name) }
    }
    
    func defaultResult() async -> ZoneEntity? {
        return nil
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Zone"
    static var description = IntentDescription("Displays AQI for a specific zone.")

    @Parameter(title: "Zone")
    var selectedZone: ZoneEntity?
}
