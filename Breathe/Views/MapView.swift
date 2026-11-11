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
        case cluster([CLLocationCoordinate2D])
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
    // how many bubbles were folded into this one, shown as a badge above 1
    var count: Int = 1
}

@available(iOS 17.0, *)
struct MapView: View {
    @EnvironmentObject private var viewModel: BreatheViewModel

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasFramedZones = false
#if DEBUG
    @State private var layer: MapLayer = ShotHooks.mapLayer == "districts" ? .districts : .sensors
#else
    @State private var layer: MapLayer = .sensors
#endif
    @State private var selectedSensor: SensorPoint?
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var mapWidth: CGFloat = 390

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
                ForEach(clusterBubbles(bubbles, region: visibleRegion, mapWidth: mapWidth)) { bubble in
                    Annotation("", coordinate: bubble.coordinate, anchor: .center) {
                        MapBubbleView(bubble: bubble, isUsAqi: viewModel.isUsAqi)
                            .onTapGesture {
                                open(bubble)
                            }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
            }
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { mapWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, width in
                            mapWidth = width
                        }
                }
            )
            .ignoresSafeArea()
            .toolbar(.hidden, for: .navigationBar)
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
                frameZonesOnce()
                Task {
                    await viewModel.fetchAllAqiData()
                }
            }
            .onChange(of: viewModel.zones.count) { _, _ in
                frameZonesOnce()
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
        case .cluster(let coordinates):
            zoomToFit(coordinates)
        }
    }

    private func frameZonesOnce() {
        guard !hasFramedZones else {
            return
        }
        let coordinates = viewModel.zones.compactMap { zone -> CLLocationCoordinate2D? in
            guard let lat = zone.lat, let lon = zone.lon else {
                return nil
            }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        guard !coordinates.isEmpty else {
            return
        }
        hasFramedZones = true
        zoomToFit(coordinates, margin: 1.25, animated: false)
    }

    // frames every member with some room around it, which is enough zoom to
    // pull the group apart
    private func zoomToFit(_ coordinates: [CLLocationCoordinate2D], margin: Double = 1.8, animated: Bool = true) {
        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else {
            return
        }
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * margin, 0.05),
                longitudeDelta: max((maxLon - minLon) * margin, 0.05)
            )
        )
        if animated {
            withAnimation(.snappy(duration: 0.5)) {
                cameraPosition = .region(region)
            }
        } else {
            cameraPosition = .region(region)
        }
    }
}

// zoomed out, a dozen Srinagar and Jammu sensors land in the same few points
// and turn into a pile of half hidden numbers. walking from the worst reading
// down, each bubble joins the first group whose seed is closer than
// minDistance on screen, or starts its own. a group shows its worst reading
// with a count badge. distances are on the web mercator plane MapKit draws
// on, scaled to the map's width, so panning doesn't change the groups
func clusterBubbles(
    _ bubbles: [MapBubble],
    region: MKCoordinateRegion?,
    mapWidth: CGFloat,
    minDistance: CGFloat = 40
) -> [MapBubble] {
    guard let region, region.span.longitudeDelta > 0, mapWidth > 0 else {
        return bubbles
    }
    let worldWidth = Double(mapWidth) * 360 / region.span.longitudeDelta

    func toPoint(_ c: CLLocationCoordinate2D) -> CGPoint {
        let x = (c.longitude + 180) / 360 * worldWidth
        let latRad = c.latitude * .pi / 180
        let y = (1 - log(tan(latRad) + 1 / cos(latRad)) / .pi) / 2 * worldWidth
        return CGPoint(x: x, y: y)
    }

    var seeds: [CGPoint] = []
    var groups: [[MapBubble]] = []
    for bubble in bubbles.sorted(by: { ($0.aqi ?? -1) > ($1.aqi ?? -1) }) {
        let p = toPoint(bubble.coordinate)
        if let index = seeds.firstIndex(where: { hypot($0.x - p.x, $0.y - p.y) < minDistance }) {
            groups[index].append(bubble)
        } else {
            seeds.append(p)
            groups.append([bubble])
        }
    }

    let merged: [MapBubble] = groups.map { members in
        if members.count == 1 {
            return members[0]
        }
        let lat = members.map(\.coordinate.latitude).reduce(0, +) / Double(members.count)
        let lon = members.map(\.coordinate.longitude).reduce(0, +) / Double(members.count)
        return MapBubble(
            id: "cluster/\(members[0].id)",
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            aqi: members.compactMap(\.aqi).max(),
            isLoading: members.allSatisfy(\.isLoading),
            isLive: members.contains(where: \.isLive),
            isModelled: members.allSatisfy(\.isModelled),
            target: .cluster(members.map(\.coordinate)),
            count: members.count
        )
    }
    // MapKit draws later annotations on top, so the worst air wins overlaps
    return merged.sorted { ($0.aqi ?? -1) < ($1.aqi ?? -1) }
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
                            .foregroundStyle(AqiPalette.onColor(aqi, isUsAqi: viewModel.isUsAqi))
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
        AqiPalette.color(value, isUsAqi: viewModel.isUsAqi)
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

            if bubble.count > 1 {
                Text("\(bubble.count)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(minWidth: 14, minHeight: 14)
                    .background(Circle().fill(Color.white))
                    .offset(x: 12, y: 12)
            }
        }
    }
}

func mapAqiColor(_ value: Int?, isUsAqi: Bool) -> Color {
    guard let value = value else {
        return .gray
    }
    return AqiPalette.color(value, isUsAqi: isUsAqi)
}

func mapAqiTextColor(_ value: Int, isUsAqi: Bool) -> Color {
    AqiPalette.onColor(value, isUsAqi: isUsAqi)
}
