// SPDX-License-Identifier: MIT
/*
 * MapView.swift - Every zone and ground sensor on a map, tap one for its details
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
import MapKit

enum MapLayer: String, CaseIterable, Identifiable {
    case sensors = "Sensors"
    case districts = "Districts"

    var id: String { rawValue }
}

// one bubble on the map, either a whole zone or a single sensor
struct MapBubble: Identifiable {
    enum Target {
        case zone(Zone)
        case sensor(SensorPoint)
    }

    let id: String
    let coordinate: CLLocationCoordinate2D
    let aqi: Int?
    // a zone whose numbers haven't come back yet, as opposed to an offline sensor
    let isLoading: Bool
    let isLive: Bool
    // modelled zones get a dashed ring when they sit among real sensors
    let isModelled: Bool
    let target: Target
}

@available(iOS 17.0, *)
struct MapView: View {
    @EnvironmentObject private var viewModel: BreatheViewModel

    // Default region covering J&K and Ladakh
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 34.75, longitude: 76.5),
            span: MKCoordinateSpan(latitudeDelta: 6.0, longitudeDelta: 9.0)
        )
    )
    @State private var layer: MapLayer = .sensors
    @State private var selectedSensor: SensorPoint?

    private var sensorPoints: [SensorPoint] {
        buildSensorPoints(zones: Array(viewModel.allAqiData.values), sensorInfos: viewModel.sensorInfos)
    }

    // in the sensor layer a zone with live sensors is replaced by them, zones
    // that only have modelled data keep their one bubble
    private var bubbles: [MapBubble] {
        let sensors = layer == .sensors ? sensorPoints : []
        let zonesWithSensors = Set(sensors.map(\.zoneId))
        var result: [MapBubble] = []

        for zone in viewModel.zones {
            guard let lat = zone.lat, let lon = zone.lon, !zonesWithSensors.contains(zone.id) else {
                continue
            }
            let aqiData = viewModel.allAqiData[zone.id]
            // prefer the live data source over the zone's static provider so the dot
            // falls back correctly when an AirGradient zone is serving Open-Meteo data
            let provider = aqiData?.source ?? zone.provider ?? ""
            let isLive = provider.localizedCaseInsensitiveContains("airgradient")
            result.append(
                MapBubble(
                    id: "zone/\(zone.id)",
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    aqi: viewModel.displayAqi(for: zone.id),
                    isLoading: aqiData == nil,
                    isLive: isLive,
                    isModelled: layer == .sensors && !isLive,
                    target: .zone(zone)
                )
            )
        }

        for sensor in sensors {
            let aqi: Int? = sensor.isOffline
                ? nil
                : (viewModel.isUsAqi ? (sensor.reading.usAqi ?? sensor.reading.aqi) : sensor.reading.aqi)
            result.append(
                MapBubble(
                    id: "sensor/\(sensor.id)",
                    coordinate: sensor.coordinate,
                    aqi: aqi,
                    isLoading: false,
                    isLive: true,
                    isModelled: false,
                    target: .sensor(sensor)
                )
            )
        }

        // MapKit draws later annotations on top, so the worst air wins overlaps
        return result.sorted { ($0.aqi ?? -1) < ($1.aqi ?? -1) }
    }

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition, interactionModes: .all) {
                ForEach(bubbles) { bubble in
                    Annotation("", coordinate: bubble.coordinate, anchor: .center) {
                        MapBubbleView(bubble: bubble, isUsAqi: viewModel.isUsAqi)
                            .onTapGesture {
                                open(bubble)
                            }
                    }
                }
            }
            .ignoresSafeArea()
            .navigationTitle("Map")
            .safeAreaInset(edge: .top) {
                Picker("Map layer", selection: $layer) {
                    ForEach(MapLayer.allCases) { entry in
                        Text(entry.rawValue).tag(entry)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
                .padding(6)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 8)
            }
            .onAppear {
                Task {
                    await viewModel.fetchAllAqiData()
                }
            }
            .overlay(alignment: .bottom) {
                if let zone = viewModel.selectedMapZone {
                    SelectedZoneCard(zone: zone)
                        .padding(.bottom, 24)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(item: $selectedSensor) { sensor in
                NodeDetailSheet(
                    nodeName: sensor.name,
                    reading: sensor.reading,
                    isUsAqi: viewModel.isUsAqi,
                    displayAqi: sensor.isOffline
                        ? nil
                        : (viewModel.isUsAqi ? (sensor.reading.usAqi ?? sensor.reading.aqi) : sensor.reading.aqi),
                    aqiLabelStr: viewModel.isUsAqi ? "US AQI" : "NAQI",
                    sensorInfo: sensor.info,
                    onOpenZone: {
                        selectedSensor = nil
                        withAnimation(.snappy(duration: 0.3)) {
                            viewModel.selectedMapZone = viewModel.zones.first { $0.id == sensor.zoneId }
                        }
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func open(_ bubble: MapBubble) {
        switch bubble.target {
        case .zone(let zone):
            withAnimation(.snappy(duration: 0.3)) {
                viewModel.selectedMapZone = zone
            }
        case .sensor(let sensor):
            viewModel.selectedMapZone = nil
            selectedSensor = sensor
        }
    }
}

// MARK: - Selected Zone Quick Card
struct SelectedZoneCard: View {
    let zone: Zone

    @EnvironmentObject private var viewModel: BreatheViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let aqiData = viewModel.allAqiData[zone.id]
        // Prefer the live data source over the zone's static provider so the dot
        // falls back correctly when an AirGradient zone is serving Open-Meteo data.
        let provider = aqiData?.source ?? zone.provider ?? ""
        let isOpenMeteo = provider.localizedCaseInsensitiveContains("open-meteo") || provider.localizedCaseInsensitiveContains("openmeteo")
        let isAirGradient = provider.localizedCaseInsensitiveContains("airgradient")

        let displayAqi = aqiData.flatMap { viewModel.isUsAqi ? ($0.usAqi ?? $0.nAqi) : $0.nAqi }
        let displayPollutant = aqiData.flatMap { viewModel.isUsAqi ? ($0.usMainPollutant ?? $0.mainPollutant) : $0.mainPollutant }
        let isPinned = viewModel.pinnedZoneIds.contains(zone.id)
        
        let formattedTime: String? = {
            guard let ts = aqiData?.timestampUnix else { return nil }
            let date = Date(timeIntervalSince1970: ts)
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter.localizedString(for: date, relativeTo: Date())
        }()
        
        let trendValue: Int? = {
            guard let history = aqiData?.history, history.count >= 2 else { return nil }
            let latest  = history[history.count - 1]
            let previous = history[history.count - 2]
            let latestVal  = viewModel.isUsAqi ? (latest.usAqi ?? latest.aqi) : latest.aqi
            let previousVal = viewModel.isUsAqi ? (previous.usAqi ?? previous.aqi) : previous.aqi
            return latestVal - previousVal
        }()
        
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                    Text("NOW VIEWING")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(1)
                }
                .foregroundStyle(.secondary)

                Spacer()

                Button(action: {
                    viewModel.togglePin(for: zone)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isPinned ? "pin.fill" : "pin")
                        Text(isPinned ? "Pinned" : "Pin to Home")
                    }
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(zone.name)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                if isAirGradient {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Live Ground Sensors")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                } else if isOpenMeteo {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                        Text("Satellite & Model Data")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            HStack(alignment: .top) {
                if let aqi = displayAqi {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(aqi)")
                            .font(.system(size: 64, weight: .heavy, design: .rounded))
                            .foregroundStyle(aqiDisplayTextColor(aqi))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Text(viewModel.isUsAqi ? "US AQI" : "NAQI")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(aqiBadgeTextColor(aqi))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(aqiColor(aqi)))
                    }
                } else {
                    ProgressView()
                        .frame(width: 64, height: 64)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 4) {
                        Text("Primary")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        if let p = displayPollutant {
                            Text(formatPollutant(p))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    if let trend = trendValue {
                        HStack(spacing: 4) {
                            Image(systemName: trend == 0 ? "arrow.right" : (trend > 0 ? "arrow.up.right" : "arrow.down.right"))
                            Text("\(trend > 0 ? "+" : "")\(trend) /hr")
                        }
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(trend == 0 ? Color.secondary : (trend < 0 ? Color.green : Color.red))
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.right")
                                .opacity(0)
                            Text("-- /hr")
                        }
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    }
                    
                    if let time = formattedTime {
                        Text(time)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)
            }
            
            HStack(spacing: 12) {
                Spacer()
                Button(action: {
                    withAnimation(.snappy(duration: 0.3)) {
                        viewModel.selectedMapZone = nil
                    }
                }) {
                    Text("Close")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                
                Button(action: {
                    viewModel.selectedZone = zone
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
                    withAnimation(.snappy(duration: 0.3)) {
                        viewModel.selectedMapZone = nil
                    }
                }) {
                    Text("View Full Details")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 10/255, green: 132/255, blue: 255/255))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(.top, 4)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? Color(red: 23/255, green: 24/255, blue: 27/255)
                        : Color(red: 242/255, green: 242/255, blue: 247/255)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.15), radius: 20, x: 0, y: 10)
        )
    }
    
    private func aqiColor(_ value: Int) -> Color {
        if viewModel.isUsAqi {
            switch value {
            case ..<51:  return Color(red: 0/255, green: 228/255, blue: 0/255)
            case ..<101: return Color(red: 255/255, green: 255/255, blue: 0/255)
            case ..<151: return Color(red: 255/255, green: 126/255, blue: 0/255)
            case ..<201: return Color(red: 255/255, green: 0/255, blue: 0/255)
            case ..<301: return Color(red: 143/255, green: 63/255, blue: 151/255)
            default:     return Color(red: 126/255, green: 0/255, blue: 35/255)
            }
        } else {
            switch value {
            case ..<51:  return Color(red: 0/255, green: 176/255, blue: 80/255)
            case ..<101: return Color(red: 146/255, green: 208/255, blue: 80/255)
            case ..<201: return Color(red: 255/255, green: 255/255, blue: 0/255)
            case ..<301: return Color(red: 244/255, green: 145/255, blue: 28/255)
            case ..<401: return Color(red: 233/255, green: 63/255, blue: 51/255)
            default:     return Color(red: 175/255, green: 45/255, blue: 36/255)
            }
        }
    }

    private func isModerateAqi(_ value: Int) -> Bool {
        if viewModel.isUsAqi {
            return (51...100).contains(value)
        }
        return (101...200).contains(value)
    }

    private func aqiDisplayTextColor(_ value: Int) -> Color {
        if colorScheme == .light && isModerateAqi(value) {
            return Color(red: 210.0/255.0, green: 153.0/255.0, blue: 0.0) // Darker yellow/amber
        }
        return aqiColor(value)
    }

    private func aqiBadgeTextColor(_ value: Int) -> Color {
        if viewModel.isUsAqi {
            return value < 101 ? .black : .white
        } else {
            return value < 201 ? .black : .white
        }
    }
    
    private func formatPollutant(_ raw: String) -> AttributedString {
        let input = raw.lowercased().replacingOccurrences(of: "_", with: "")
        var result = AttributedString()
        
        if input == "pm2.5" || input == "pm25" {
            result.append(AttributedString("PM"))
            var sub = AttributedString("2.5")
            sub.baselineOffset = -2
            sub.font = .system(size: 9, weight: .bold)
            result.append(sub)
            return result
        } else if input == "pm10" {
            result.append(AttributedString("PM"))
            var sub = AttributedString("10")
            sub.baselineOffset = -2
            sub.font = .system(size: 9, weight: .bold)
            result.append(sub)
            return result
        }
        
        for char in raw.uppercased() {
            if char.isNumber || char == "." {
                var sub = AttributedString(String(char))
                sub.baselineOffset = -3
                sub.font = .system(size: 8)
                result.append(sub)
            } else {
                result.append(AttributedString(String(char)))
            }
        }
        return result
    }
}

// MARK: - Annotation Marker UI
struct MapBubbleView: View {
    let bubble: MapBubble
    let isUsAqi: Bool

    var body: some View {
        let color = mapAqiColor(bubble.aqi, isUsAqi: isUsAqi)

        ZStack {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle().stroke(
                        Color.white,
                        style: bubble.isModelled
                            ? StrokeStyle(lineWidth: 2.5, dash: [3, 2.5])
                            : StrokeStyle(lineWidth: 2.5)
                    )
                )
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)

            if let aqi = bubble.aqi {
                Text("\(aqi)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(mapAqiTextColor(aqi, isUsAqi: isUsAqi))
            } else if bubble.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            }

            if bubble.isLive {
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    .offset(x: 12, y: -12)
            }
        }
    }
}

// offline sensors and zones still loading have no number and stay grey
func mapAqiColor(_ value: Int?, isUsAqi: Bool) -> Color {
    guard let value = value else { return .gray }
    if isUsAqi {
        switch value {
        case ..<51:  return Color(red: 0/255, green: 228/255, blue: 0/255)
        case ..<101: return Color(red: 255/255, green: 255/255, blue: 0/255)
        case ..<151: return Color(red: 255/255, green: 126/255, blue: 0/255)
        case ..<201: return Color(red: 255/255, green: 0/255, blue: 0/255)
        case ..<301: return Color(red: 143/255, green: 63/255, blue: 151/255)
        default:     return Color(red: 126/255, green: 0/255, blue: 35/255)
        }
    } else {
        switch value {
        case ..<51:  return Color(red: 0/255, green: 176/255, blue: 80/255)
        case ..<101: return Color(red: 146/255, green: 208/255, blue: 80/255)
        case ..<201: return Color(red: 255/255, green: 255/255, blue: 0/255)
        case ..<301: return Color(red: 244/255, green: 145/255, blue: 28/255)
        case ..<401: return Color(red: 233/255, green: 63/255, blue: 51/255)
        default:     return Color(red: 175/255, green: 45/255, blue: 36/255)
        }
    }
}

// dark on the greens and yellows, white on the oranges and up
func mapAqiTextColor(_ value: Int, isUsAqi: Bool) -> Color {
    if isUsAqi {
        return value < 101 ? .black : .white
    }
    return value < 201 ? .black : .white
}
