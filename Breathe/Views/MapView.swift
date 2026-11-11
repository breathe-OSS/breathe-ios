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
    // modelled zones are drawn as a ring when they sit among real sensors
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        let allSensors = layer == .sensors ? sensorPoints : []
        let zonesWithSensors = Set(allSensors.filter { !$0.isOffline }.map(\.zoneId))
        let sensors = allSensors.filter { zonesWithSensors.contains($0.zoneId) }
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
                .floatingGlass()
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
#if DEBUG
            .task(id: viewModel.zones.count) {
                if ShotHooks.sheet == "zone",
                   let zone = viewModel.zones.first(where: { $0.id == ShotHooks.zone }) {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    viewModel.selectedMapZone = zone
                }
            }
#endif
            .sheet(item: $viewModel.selectedMapZone) { zone in
                ZoneSheet(zone: zone)
                    .presentationDetents([.medium, .large])
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
                        Task {
                            try? await Task.sleep(nanoseconds: 450_000_000)
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
            viewModel.selectedMapZone = zone
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
        if animated && !reduceMotion {
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

// MARK: - Zone Sheet
struct ZoneSheet: View {
    let zone: Zone

    @EnvironmentObject private var viewModel: BreatheViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var aqiData: AqiResponse? {
        viewModel.allAqiData[zone.id]
    }

    private var displayAqi: Int? {
        aqiData.map { viewModel.isUsAqi ? ($0.usAqi ?? $0.nAqi) : $0.nAqi }
    }

    private var pollutant: String? {
        aqiData.map { viewModel.isUsAqi ? ($0.usMainPollutant ?? $0.mainPollutant) : $0.mainPollutant }
    }

    private var isAirGradient: Bool {
        let provider = aqiData?.source ?? zone.provider ?? ""
        return provider.localizedCaseInsensitiveContains("airgradient")
    }

    private var trendText: String? {
        guard let history = aqiData?.history, history.count >= 2 else {
            return nil
        }
        let latest = history[history.count - 1]
        let previous = history[history.count - 2]
        let latestVal = viewModel.isUsAqi ? (latest.usAqi ?? latest.aqi) : latest.aqi
        let previousVal = viewModel.isUsAqi ? (previous.usAqi ?? previous.aqi) : previous.aqi
        let change = latestVal - previousVal
        if change > 0 {
            return "Up \(change)"
        }
        if change < 0 {
            return "Down \(-change)"
        }
        return "Steady"
    }

    private var updatedText: String? {
        guard let ts = aqiData?.timestampUnix else {
            return nil
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: Date(timeIntervalSince1970: ts), relativeTo: Date())
    }

    var body: some View {
        let isPinned = viewModel.pinnedZoneIds.contains(zone.id)

        NavigationStack {
            List {
                Section {
                    if let aqi = displayAqi {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(aqi)")
                                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                                    .monospacedDigit()
                                Text(AqiPalette.label(aqi, isUsAqi: viewModel.isUsAqi))
                                    .font(.headline)
                            }

                            Spacer()

                            Text(AqiPalette.standardName(isUsAqi: viewModel.isUsAqi))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .foregroundStyle(AqiPalette.onColor(aqi, isUsAqi: viewModel.isUsAqi))
                                .background(Capsule().fill(AqiPalette.color(aqi, isUsAqi: viewModel.isUsAqi)))
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(
                            ZStack {
                                Color(.secondarySystemGroupedBackground)
                                AqiPalette.color(aqi, isUsAqi: viewModel.isUsAqi)
                                    .opacity(colorScheme == .dark ? 0.22 : 0.16)
                            }
                        )
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }

                Section {
                    infoRow("Source", isAirGradient ? "Live ground sensors" : "Satellite and model data")
                    if let pollutant {
                        HStack {
                            Text("Primary pollutant")
                                .foregroundStyle(.secondary)
                            Spacer()
                            PollutantLabel(raw: pollutant, style: .body, weight: .medium)
                        }
                    }
                    if let trendText {
                        infoRow("Last hour", trendText)
                    }
                    if let updatedText {
                        infoRow("Updated", updatedText)
                    }
                }

                Section {
                    Button {
                        viewModel.selectedZone = zone
                        viewModel.selectedMapZone = nil
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
                    } label: {
                        Label("View Full Details", systemImage: "house")
                    }

                    Button {
                        viewModel.togglePin(for: zone)
                    } label: {
                        Label(isPinned ? "Unpin" : "Pin to Home", systemImage: isPinned ? "pin.slash" : "pin")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(zone.name)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Annotation Marker UI
struct MapBubbleView: View {
    let bubble: MapBubble
    let isUsAqi: Bool

    @Environment(\.colorScheme) private var colorScheme

    private let size: CGFloat = 34

    var body: some View {
        ZStack(alignment: .topTrailing) {
            bubbleBody
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)

            if bubble.count > 1 {
                Text("\(bubble.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 5)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Capsule().fill(Color(.systemBackground)))
                    .overlay(Capsule().stroke(Color.secondary.opacity(0.3), lineWidth: 0.5))
                    .offset(x: 8, y: -6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var bubbleBody: some View {
        if let aqi = bubble.aqi {
            let color = AqiPalette.color(aqi, isUsAqi: isUsAqi)
            if bubble.isModelled {
                Circle()
                    .fill(Color(.systemBackground))
                    .overlay(Circle().fill(color.opacity(colorScheme == .dark ? 0.3 : 0.2)))
                    .overlay(Circle().strokeBorder(color, lineWidth: 3))
                    .overlay(
                        Text("\(aqi)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    )
            } else {
                Circle()
                    .fill(color)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5))
                    .overlay(
                        Text("\(aqi)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(AqiPalette.onColor(aqi, isUsAqi: isUsAqi))
                    )
            }
        } else if bubble.isLoading {
            Circle()
                .fill(Color(.systemGray4))
                .overlay(ProgressView().scaleEffect(0.6))
        } else {
            Circle()
                .fill(Color(.systemGray))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5))
                .overlay(
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                )
        }
    }

    private var accessibilityText: String {
        var parts: [String] = []
        if let aqi = bubble.aqi {
            parts.append("AQI \(aqi), \(AqiPalette.label(aqi, isUsAqi: isUsAqi))")
        } else if bubble.isLoading {
            parts.append("Loading")
        } else {
            parts.append("Sensor offline")
        }
        if bubble.isModelled {
            parts.append("modelled")
        }
        if bubble.count > 1 {
            parts.append("\(bubble.count) places, tap to zoom in")
        }
        return parts.joined(separator: ", ")
    }
}
