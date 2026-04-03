// SPDX-License-Identifier: MIT
/*
 * AppIntent.swift
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
        
        // Let's only suggest pinned zones for the widget
        let sharedDefaults = UserDefaults(suiteName: "group.com.sidharthify.Breathe.BreatheWidget")
        if let savedPinned = sharedDefaults?.data(forKey: "pinned_zones"),
           let pinnedIds = try? JSONDecoder().decode([String].self, from: savedPinned) {
            
            let pinnedZones = zones.filter { pinnedIds.contains($0.id) }
            if !pinnedZones.isEmpty {
                return pinnedZones.map { ZoneEntity(id: $0.id, name: $0.name) }
            }
        }
        
        return zones.map { ZoneEntity(id: $0.id, name: $0.name) }
    }
    
    func defaultResult() async -> ZoneEntity? {
        let sharedDefaults = UserDefaults(suiteName: "group.com.sidharthify.Breathe.BreatheWidget")
        
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
