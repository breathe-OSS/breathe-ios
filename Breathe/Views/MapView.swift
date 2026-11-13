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
import Charts

// one bubble on the map, either a whole zone or a single sensor
struct MapBubble: Identifiable {
    enum Target {
        case zone(Zone)
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
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var mapWidth: CGFloat = 390

    private var bubbles: [MapBubble] {
        var result: [MapBubble] = []
        for zone in viewModel.zones {
            guard let lat = zone.lat, let lon = zone.lon else {
                continue
            }
            let aqiData = viewModel.allAqiData[zone.id]
            let isLive = !zone.isEstimate && aqiData?.isSensorOffline != true
            result.append(
                MapBubble(
                    id: "zone/\(zone.id)",
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    aqi: viewModel.displayAqi(for: zone.id),
                    isLoading: aqiData == nil,
                    isLive: isLive,
                    isModelled: zone.isEstimate,
                    target: .zone(zone)
                )
            )
        }
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
        }
    }

    private func open(_ bubble: MapBubble) {
        switch bubble.target {
        case .zone(let zone):
            viewModel.selectedMapZone = zone
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
private struct PanelBar: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct ZoneSheet: View {
    let zone: Zone

    @EnvironmentObject private var viewModel: BreatheViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var range = 0
    @State private var daily: [PanelBar]? = nil
    @State private var grid: [HistoricalDataPoint]? = nil
    @State private var selectedBar: Date? = nil

    private let aboutURL = "https://about.breatheoss.app"
    private let whoLimit = 15.0

    private var aqiData: AqiResponse? {
        viewModel.allAqiData[zone.id]
    }

    private var displayAqi: Int? {
        aqiData.map { viewModel.isUsAqi ? ($0.usAqi ?? $0.nAqi) : $0.nAqi }
    }

    private var pollutant: String? {
        aqiData.map { viewModel.isUsAqi ? ($0.usMainPollutant ?? $0.mainPollutant) : $0.mainPollutant }
    }

    private var isLive: Bool {
        !zone.isEstimate
    }

    private var isOffline: Bool {
        aqiData?.isSensorOffline == true
    }

    private var showingRaw: Bool {
        aqiData?.showingRaw == true
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
            return "\(change) worse in 1h"
        }
        if change < 0 {
            return "\(-change) better in 1h"
        }
        return "Steady in 1h"
    }

    private var updatedText: String? {
        guard let ts = aqiData?.timestampUnix else {
            return nil
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: Date(timeIntervalSince1970: ts), relativeTo: Date())
    }

    private var sourceText: String {
        if !isLive {
            return "Satellite estimate, no sensor here yet"
        }
        if isOffline {
            return "Sensor offline, showing a satellite estimate"
        }
        return showingRaw ? "Live ground sensor · raw readings" : "Live ground sensor"
    }

    private var hourlyBars: [PanelBar] {
        (aqiData?.history ?? [])
            .sorted { $0.ts < $1.ts }
            .compactMap { point in
                point.pm25.map { PanelBar(date: Date(timeIntervalSince1970: TimeInterval(point.ts)), value: $0) }
            }
    }

    private var bars: [PanelBar] {
        range == 0 ? hourlyBars : (daily ?? [])
    }

    var body: some View {
        let isPinned = viewModel.pinnedZoneIds.contains(zone.id)

        NavigationStack {
            List {
                heroSection

                if let aqi = displayAqi {
                    Section {
                        let advice = healthAdviceFor(aqi, isUsAqi: viewModel.isUsAqi)
                        ContextRow(
                            systemImage: "heart.fill",
                            tint: AqiPalette.color(aqi, isUsAqi: viewModel.isUsAqi),
                            title: advice.title,
                            detail: advice.text
                        )
                    }
                }

                chartSection

                exposureSection

                if isLive {
                    Section {
                        if let grid {
                            if grid.isEmpty {
                                Text("No history yet.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ExtendedDotGrid(data: grid, showPm25: true, showPm10: true)
                            }
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }
                    } header: {
                        Text("Last 10 Days by Hour")
                    }
                }

                Section {
                    Text(sourceBody)
                        .font(.subheadline)
                    if !isLive {
                        Link("Host a sensor here", destination: URL(string: "\(aboutURL)/#help")!)
                    }
                } header: {
                    Text("Where This Comes From")
                }

                Section {
                    Text("Host a sensor for free, send code, or help fund the network. Every new sensor puts a real reading where there was only a model before.")
                        .font(.subheadline)
                    Link(destination: URL(string: "\(aboutURL)/#help")!) {
                        Label("Help expand the network", systemImage: "sensor")
                    }
                    Link(destination: URL(string: "\(aboutURL)/#contribute")!) {
                        Label("Other ways to help", systemImage: "person.2")
                    }
                } header: {
                    Text("Become a Contributor")
                }

                Section {
                    Button {
                        viewModel.selectedZone = zone
                        viewModel.selectedMapZone = nil
                        dismiss()
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
                ToolbarItem(placement: .topBarLeading) {
                    if let url = URL(string: "https://breatheoss.app/zone/\(zone.id)") {
                        ShareLink(item: url, subject: Text("\(zone.name) air quality | Breathe")) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task(id: "\(zone.id)-\(showingRaw)") {
                await loadGrid()
            }
            .task(id: "\(zone.id)-\(range)-\(showingRaw)") {
                await loadDaily()
            }
        }
    }

    @ViewBuilder
    private var heroSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                let line = placeLine(district: aqiData?.district ?? zone.district, division: aqiData?.division ?? zone.division)
                if !line.isEmpty {
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    if isLive && !isOffline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                    }
                    Text(sourceText)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            if let aqi = displayAqi {
                let tint = AqiPalette.color(aqi, isUsAqi: viewModel.isUsAqi)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(aqi)")
                                .font(.system(size: 56, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                            Text(AqiPalette.label(aqi, isUsAqi: viewModel.isUsAqi))
                                .font(.headline)
                        }

                        Spacer()

                        Text(showingRaw ? "Raw \(AqiPalette.standardName(isUsAqi: viewModel.isUsAqi))" : AqiPalette.standardName(isUsAqi: viewModel.isUsAqi))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .foregroundStyle(AqiPalette.onColor(aqi, isUsAqi: viewModel.isUsAqi))
                            .background(Capsule().fill(tint))
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            heroPills
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            heroPills
                        }
                    }

                    if let updatedText {
                        Label(updatedText, systemImage: "clock")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(
                    ZStack {
                        Color(.secondarySystemGroupedBackground)
                        tint.opacity(colorScheme == .dark ? 0.22 : 0.16)
                    }
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var heroPills: some View {
        if let pollutant {
            HStack(spacing: 4) {
                Text("Main")
                    .foregroundStyle(.secondary)
                PollutantLabel(raw: pollutant, style: .subheadline, weight: .semibold)
            }
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color(.tertiarySystemFill)))
        }
        if let pm25 = aqiData?.concentrations?["pm2_5"] ?? aqiData?.concentrations?["pm2.5"] {
            Text(String(format: "PM2.5 %.1f µg/m³", pm25))
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color(.tertiarySystemFill)))
        }
        if let trendText {
            Text(trendText)
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color(.tertiarySystemFill)))
        }
    }

    @ViewBuilder
    private var chartSection: some View {
        Section {
            if isLive {
                Picker("Range", selection: $range) {
                    Text("24h").tag(0)
                    Text("30d").tag(1)
                    Text("180d").tag(2)
                }
                .pickerStyle(.segmented)
            }

            if range != 0 && daily == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else if bars.isEmpty {
                Text("No readings yet.")
                    .foregroundStyle(.secondary)
            } else {
                barChart
                averageRows
            }
        } header: {
            Text(range == 0 ? "PM2.5, hourly" : "PM2.5, daily average")
        } footer: {
            Text("µg/m³, coloured by the \(AqiPalette.standardName(isUsAqi: viewModel.isUsAqi)) band each value falls in")
        }
    }

    private var barChart: some View {
        let isUs = viewModel.isUsAqi
        let unit: Calendar.Component = range == 0 ? .hour : .day
        let selected = selectedBar.flatMap { date in
            bars.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
        }

        return VStack(alignment: .leading, spacing: 8) {
            if let selected {
                Text("\(barLabel(selected.date)) · \(String(format: "%.1f", selected.value)) µg/m³ · \(AqiPalette.label(aqiFromPm25(selected.value, isUsAqi: isUs), isUsAqi: isUs))")
                    .font(.footnote)
                    .fontWeight(.semibold)
            } else {
                Text("Touch a bar for its reading")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Chart(bars) { bar in
                BarMark(
                    x: .value("Time", bar.date, unit: unit),
                    y: .value("PM2.5", bar.value)
                )
                .foregroundStyle(AqiPalette.color(aqiFromPm25(bar.value, isUsAqi: isUs), isUsAqi: isUs))
                .opacity(selected == nil || selected?.date == bar.date ? 1 : 0.4)
                .cornerRadius(3)
            }
            .chartXSelection(value: $selectedBar)
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .frame(height: 170)
        }
    }

    private func barLabel(_ date: Date) -> String {
        if range == 0 {
            return date.formatted(.dateTime.hour())
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    @ViewBuilder
    private var averageRows: some View {
        let values = bars.map(\.value)
        let mean = values.reduce(0, +) / Double(max(values.count, 1))
        if range == 0 {
            let recent = Array(values.suffix(12))
            averageRow("Last 24 hours", value: mean)
            if !recent.isEmpty {
                averageRow("Last 12 hours", value: recent.reduce(0, +) / Double(recent.count))
            }
        } else {
            averageRow(range == 1 ? "30 day average" : "180 day average", value: mean)
            if let worst = values.max() {
                averageRow("Worst day", value: worst)
            }
        }
    }

    private func averageRow(_ label: String, value: Double) -> some View {
        let aqi = aqiFromPm25(value, isUsAqi: viewModel.isUsAqi)
        return HStack {
            Circle()
                .fill(AqiPalette.color(aqi, isUsAqi: viewModel.isUsAqi))
                .frame(width: 10, height: 10)
            Text(label)
            Spacer()
            Text(String(format: "%.1f µg/m³", value))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var exposureSection: some View {
        let pm25 = aqiData?.averages24h?["pm2_5"] ?? aqiData?.concentrations?["pm2_5"] ?? 0
        if pm25 > 0 {
            let ratio = pm25 / whoLimit
            Section {
                LabeledContent("Cigarettes today", value: String(format: "%.1f", (pm25 / 22 * 10).rounded() / 10))
                LabeledContent("WHO guideline") {
                    Text(ratio <= 1 ? "Within" : String(format: "%.1f× the limit", ratio))
                        .fontWeight(.semibold)
                        .foregroundStyle(ratio <= 1 ? Color.green : (ratio <= 2.5 ? Color.orange : Color.red))
                }
            } footer: {
                Text(String(format: "From the 24 hour PM2.5 average of %.1f µg/m³, against the WHO limit of 15 µg/m³.", pm25))
            }
        }
    }

    private var sourceBody: String {
        if !isLive {
            return "There's no ground sensor in \(zone.name) yet. These numbers are modelled by CAMS and served through Open-Meteo, so they can miss local smoke and dust."
        }
        if isOffline {
            return "This BreatheOSS AirGradient sensor isn't reporting right now, so these numbers are a CAMS estimate for its location, served through Open-Meteo."
        }
        let district = (aqiData?.district ?? zone.district).map { " in the \($0) district" } ?? ""
        let raw = showingRaw ? " You are seeing its raw readings, before AirGradient's correction." : ""
        return "PM2.5 and PM10 come from this BreatheOSS AirGradient sensor\(district). Gases come from CAMS through Open-Meteo.\(raw)"
    }

    private func loadGrid() async {
        guard isLive else {
            return
        }
        grid = nil
        let raw = showingRaw
        let metrics = raw ? "pm2.5,pm10,pm2.5_raw,pm10_raw" : "pm2.5,pm10"
        let rows = (try? await BreatheAPI.shared.getHistoricalData(location: zone.id, timeRange: "9d", interval: "1h", metrics: metrics).data) ?? []
        grid = rows.map { point -> HistoricalDataPoint in
            var copy = point
            if raw {
                copy.pm25 = point.pm25Raw
                copy.pm10 = point.pm10Raw
            }
            return copy
        }.filter { $0.pm25 != nil || $0.pm10 != nil }
    }

    private func loadDaily() async {
        guard range != 0 else {
            return
        }
        daily = nil
        let raw = showingRaw
        let token = range == 1 ? "30d" : "180d"
        let rows = (try? await BreatheAPI.shared.getHistoricalData(location: zone.id, timeRange: token, interval: "1d", metrics: raw ? "pm2.5_raw" : "pm2.5").data) ?? []
        daily = rows.sorted { $0.ts < $1.ts }.compactMap { row in
            (raw ? row.pm25Raw : row.pm25).map { PanelBar(date: Date(timeIntervalSince1970: TimeInterval(row.ts)), value: $0) }
        }
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
