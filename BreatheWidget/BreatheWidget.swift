//  BreatheWidget.swift
//  BreatheWidget

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), aqi: nil, zoneName: "Loading...", secondaryZones: [])
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), aqi: nil, zoneName: "Loading...", secondaryZones: [])
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let currentDate = Date()
        var aqiResponse: AqiResponse?
        var zName = "Select Zone"
        var primaryId: String? = nil
        var secondaryZones: [(String, AqiResponse)] = []
        
        let sharedDefaults = UserDefaults(suiteName: "group.com.sidharthify.Breathe.BreatheWidget")
        
        // Use user's selected widget zone if configured:
        if let configZone = configuration.selectedZone {
            primaryId = configZone.id
            aqiResponse = try? await BreatheAPI.shared.getZoneAqi(zoneId: configZone.id)
            zName = aqiResponse?.zoneName ?? configZone.name
        } 
        // fallback to app-selected zone if no configuration is present
        else if let selectedStr = sharedDefaults?.string(forKey: "selected_zone_id"), !selectedStr.isEmpty {
            primaryId = selectedStr
            aqiResponse = try? await BreatheAPI.shared.getZoneAqi(zoneId: selectedStr)
            zName = aqiResponse?.zoneName ?? "Loading..."
        } else if let savedPinned = sharedDefaults?.data(forKey: "pinned_zones"),
                  let pinnedIds = try? JSONDecoder().decode([String].self, from: savedPinned),
                  let firstPinned = pinnedIds.first, !firstPinned.isEmpty {
            // fallback for now if no configuration is selected and no active selection exists
            primaryId = firstPinned
            aqiResponse = try? await BreatheAPI.shared.getZoneAqi(zoneId: firstPinned)
            zName = aqiResponse?.zoneName ?? "Loading..."
        }
        
        if let primaryId = primaryId, let savedPinned = sharedDefaults?.data(forKey: "pinned_zones"),
           let pinnedIds = try? JSONDecoder().decode([String].self, from: savedPinned) {
            
            // Limit secondary fetches to 3 items and avoid the primaryId
            let others = pinnedIds.filter { $0 != primaryId }.prefix(3)
            
            for zoneId in others {
                if let aqiStr = try? await BreatheAPI.shared.getZoneAqi(zoneId: zoneId) {
                    secondaryZones.append((aqiStr.zoneName, aqiStr))
                }
            }
        }
        
        let entry = SimpleEntry(date: currentDate, aqi: aqiResponse, zoneName: zName, secondaryZones: secondaryZones)
        
        // Refresh every 16 mins
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 16, to: currentDate)!
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let aqi: AqiResponse?
    let zoneName: String
    let secondaryZones: [(String, AqiResponse)]
}

struct BreatheWidgetEntryView : View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry
    
    var isUsAqi: Bool {
        let sharedDefaults = UserDefaults(suiteName: "group.com.sidharthify.Breathe.BreatheWidget")
        if let stored = sharedDefaults?.object(forKey: "is_us_aqi") as? Bool {
            return stored
        }
        return true // Default to US AQI if not set
    }
    
    var aqiValue: Int? {
        guard let aqi = entry.aqi else { return nil }
        return isUsAqi ? (aqi.usAqi ?? aqi.nAqi) : aqi.nAqi
    }
    
    var pm25: Double? {
        entry.aqi?.concentrations?["pm2.5"] ?? entry.aqi?.concentrations?["pm2_5"]
    }
    
    var pm10: Double? {
        entry.aqi?.concentrations?["pm10"]
    }

    var body: some View {
        if let aqiValue = aqiValue, let aqiInfo = entry.aqi {
            if family == .systemSmall {
                smallWidget(aqiValue: aqiValue, aqiInfo: aqiInfo)
            } else {
                mediumLargeWidget(aqiValue: aqiValue, aqiInfo: aqiInfo)
            }
        } else {
            emptyStateView
        }
    }
    
    @ViewBuilder
    func smallWidget(aqiValue: Int, aqiInfo: AqiResponse) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(entry.zoneName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                providerLogo(source: aqiInfo.source, height: 16)
            }
            
            Spacer(minLength: 2)
            
            HStack(alignment: .center) {
                Text("\(aqiValue)")
                    .font(.system(size: 48, weight: .regular))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                
                Spacer()
            }
            
            Spacer(minLength: 4)
            
            HStack(alignment: .bottom) {
                HStack(spacing: 8) {
                    concentrationView(name: "PM2.5", value: pm25)
                    concentrationView(name: "PM10", value: pm10)
                }
                Spacer()
                Text(isUsAqi ? "US AQI" : "NAQI")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
    
    @ViewBuilder
    func mediumLargeWidget(aqiValue: Int, aqiInfo: AqiResponse) -> some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.zoneName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                Spacer()
                providerLogo(source: aqiInfo.source, height: 20)
            }
            
            Spacer(minLength: 4)
            
            HStack(alignment: .center) {
                Text("\(aqiValue)")
                    .font(.system(size: 64, weight: .regular))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                
                Spacer()
                
                Text(getAqiDescription(value: aqiValue))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Spacer(minLength: 4)
            
            HStack(alignment: .bottom) {
                HStack(spacing: 12) {
                    concentrationView(name: "PM2.5", value: pm25)
                    concentrationView(name: "PM10", value: pm10)
                    concentrationView(name: "CO", value: aqiInfo.concentrations?["co"])
                    concentrationView(name: "SO₂", value: aqiInfo.concentrations?["so2"])
                    concentrationView(name: "NO₂", value: aqiInfo.concentrations?["no2"])
                    concentrationView(name: "CH₄", value: aqiInfo.concentrations?["ch4"])
                }
                
                Spacer()
                
                Text(isUsAqi ? "US AQI" : "NAQI")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            if !entry.secondaryZones.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.3))
                    .padding(.vertical, 4)
                
                VStack(spacing: 6) {
                    ForEach(entry.secondaryZones.prefix(family == .systemMedium ? 1 : 3), id: \.0) { item in
                        HStack {
                            Text(item.0)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Spacer()
                            let aqiP = isUsAqi ? (item.1.usAqi ?? item.1.nAqi) : item.1.nAqi
                            Text("\(aqiP) \(getAqiDescription(value: aqiP))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
    }

    var emptyStateView: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: family == .systemSmall ? 18 : 24))
                    .foregroundColor(.white)
            }
            Spacer()
            Text("No locations pinned!")
                .font(family == .systemSmall ? .subheadline : .headline)
                .foregroundColor(.white)
            Text("Open the app and pin some to see them here")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    @ViewBuilder
    func providerLogo(source: String?, height: CGFloat) -> some View {
        if let source = source {
            if source.lowercased().contains("airgradient") {
                Image("airgradient_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
            } else if source.lowercased().contains("openmeteo") {
                Image("openmeteo_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
            } else {
                Text(source)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
    }
    
    @ViewBuilder
    func concentrationView(name: String, value: Double?) -> some View {
        if let val = value {
            VStack(alignment: .center, spacing: 2) {
                Text(name)
                    .font(.system(size: 8, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                Text(String(format: "%.1f", val))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }
    
    func getAqiDescription(value: Int) -> String {
        if isUsAqi {
            switch value {
            case 0...50: return "Good"
            case 51...100: return "Moderate"
            case 101...150: return "Unhealthy (SG)"
            case 151...200: return "Unhealthy"
            case 201...300: return "Very Unhealthy"
            default: return "Hazardous"
            } // US AQI
        } else {
            switch value {
            case 0...50: return "Good"
            case 51...100: return "Satisfactory"
            case 101...200: return "Moderate"
            case 201...300: return "Poor"
            case 301...400: return "Very Poor"
            default: return "Severe"
            } // NAQI
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
        .description("Check the air quality of your selected zones. You can edit the widget to select a specific pinned zone.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
