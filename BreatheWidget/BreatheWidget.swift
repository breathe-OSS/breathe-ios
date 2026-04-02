//  BreatheWidget.swift
//  BreatheWidget

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), aqi: nil, zoneName: "Loading...")
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        if let zone = configuration.selectedZone {
            if let aqiData = try? await BreatheAPI.shared.getZoneAqi(zoneId: zone.id) {
                return SimpleEntry(date: Date(), configuration: configuration, aqi: aqiData, zoneName: zone.name)
            }
        }
        return SimpleEntry(date: Date(), configuration: configuration, aqi: nil, zoneName: configuration.selectedZone?.name ?? "Unknown")
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let currentDate = Date()
        var aqiResponse: AqiResponse?
        var zName = configuration.selectedZone?.name ?? "Select Zone"
        
        let sharedDefaults = UserDefaults(suiteName: "group.com.sidharthify.Breathe")
        
        // If a zone is selected via intent, use it. Otherwise, use the pinned zones.
        if let zone = configuration.selectedZone {
            aqiResponse = try? await BreatheAPI.shared.getZoneAqi(zoneId: zone.id)
            zName = zone.name
        } else if let savedPinned = sharedDefaults?.data(forKey: "pinned_zones"),
                  let pinnedIds = try? JSONDecoder().decode([String].self, from: savedPinned),
                  let firstPinned = pinnedIds.first {
            // fallback for now if no configuration is selected
            aqiResponse = try? await BreatheAPI.shared.getZoneAqi(zoneId: firstPinned)
            zName = aqiResponse?.zoneName ?? "Loading..."
        }
        
        let entry = SimpleEntry(date: currentDate, configuration: configuration, aqi: aqiResponse, zoneName: zName)
        
        // Refresh every 16 mins
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 16, to: currentDate)!
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let aqi: AqiResponse?
    let zoneName: String
}

struct BreatheWidgetEntryView : View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry
    
    var isUsAqi: Bool {
        let sharedDefaults = UserDefaults(suiteName: "group.com.sidharthify.Breathe")
        return sharedDefaults?.bool(forKey: "is_us_aqi") ?? true
    }
    
    var aqiValue: Int? {
        guard let aqi = entry.aqi else { return nil }
        return isUsAqi ? (aqi.usAqi ?? aqi.nAqi) : aqi.nAqi
    }
    
    var pm25: Double? {
        entry.aqi?.concentrations?["PM2.5"]
    }
    
    var pm10: Double? {
        entry.aqi?.concentrations?["PM10"]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(entry.zoneName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if entry.aqi != nil {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.top, 4)
                }
                
                Spacer()
            }
            
            if let aqiValue = aqiValue {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(aqiValue)")
                        .font(.system(size: family == .systemSmall ? 40 : 56, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(isUsAqi ? "US AQI" : "NAQI")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer(minLength: 0)
                
                HStack(spacing: 16) {
                    if let pm25 = pm25 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PM2.5")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                            Text(String(format: "%.1f", pm25))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    
                    if let pm10 = pm10 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PM10")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                            Text(String(format: "%.1f", pm10))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                }
            } else {
                Spacer()
                Text("No Data")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
            }
        }
    }
}

struct BreatheWidget: Widget {
    let kind: String = "BreatheWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            BreatheWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.black
                }
        }
        .configurationDisplayName("Breathe AQI")
        .description("Check the air quality of your selected zones.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
