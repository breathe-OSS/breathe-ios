// SPDX-License-Identifier: MIT
/*
 * HomeView.swift
 *
 * Copyright (C) 2026 The Breathe Open Source Project
 * Copyright (C) 2026 sidharthify <wednisegit@gmail.com>
 * Copyright (C) 2026 SleeperOfSaturn <sanidhya1998@icloud.com>
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
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct HomeView: View {
    
    @EnvironmentObject private var viewModel: BreatheViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
#if DEBUG
    @State private var historyPage = ShotHooks.history == "hourly" ? 1 : 0
#else
    @State private var historyPage = 0
#endif
    @State private var showReorderSheet = false
    @State private var showScaleSheet = false
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.35, dampingFraction: 0.8)))
    private var heroDrag: CGFloat = 0
    @AppStorage("pinnedOverview") private var pinnedOverview = false
    @State private var isOverviewExpanded = false
    @State private var showPinnedHint = false
    @State private var isWelcomeDeferred = false
    @ScaledMetric(relativeTo: .largeTitle) private var heroNumberSize: CGFloat = 72
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
#if DEBUG
    @State private var shotExtendedHistory = false
#endif
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    func calculateCigarettes(pm25: Double) -> Double {
        let cigs = pm25 / 22.0
        return (cigs * 10).rounded() / 10
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    content
                }
                .background(Color(.systemGroupedBackground))
                .sensoryFeedback(.selection, trigger: viewModel.selectedZone?.id)
#if DEBUG
                .task(id: viewModel.currentAqi?.zoneId) {
                    guard viewModel.currentAqi != nil else {
                        return
                    }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if let anchor = ShotHooks.scroll {
                        proxy.scrollTo(anchor, anchor: .top)
                    } else if ShotHooks.sheet != nil {
                        proxy.scrollTo("nodes", anchor: .top)
                    }
                    if ShotHooks.screen == "extendedHistory" {
                        shotExtendedHistory = true
                    }
                }
#endif
            }
#if DEBUG
            .navigationDestination(isPresented: $shotExtendedHistory) {
                extendedHistoryView()
            }
#endif
            .navigationTitle(homeTitle)
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
            .toolbar {
                if viewModel.pinnedZones.count > 1 {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showReorderSheet = true
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .accessibilityLabel("Reorder pinned locations")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showReorderSheet) {
                ReorderPinnedView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $showScaleSheet) {
                AqiScaleSheet(aqi: viewModel.displayAqi ?? 0, isUsAqi: viewModel.isUsAqi)
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: welcomeBinding) {
            WelcomeView(
                worstEntries: Array(rankedLiveEntries.prefix(3)),
                bestEntries: Array(rankedLiveEntries.reversed().prefix(3)),
                isUsAqi: viewModel.isUsAqi,
                onSelect: { zone in
                    viewModel.togglePin(for: zone)
                    withAnimation(reduceMotion ? .none : .spring(response: 0.45, dampingFraction: 0.8)) {
                        showPinnedHint = true
                    }
                },
                onBrowse: {
                    isWelcomeDeferred = true
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToSearchTab"), object: nil)
                }
            )
        }
    }

    private var rankedLiveEntries: [SnapshotEntry] {
        viewModel.liveZones
            .compactMap { zone in
                viewModel.displayAqi(for: zone.id).map { SnapshotEntry(zone: zone, aqi: $0) }
            }
            .filter { $0.aqi > 0 }
            .sorted { $0.aqi > $1.aqi }
    }

    private var welcomeBinding: Binding<Bool> {
        Binding(
            get: {
                !viewModel.hasOnboarded
                    && viewModel.pinnedZones.isEmpty
                    && !isWelcomeDeferred
                    && rankedLiveEntries.count >= 2
            },
            set: { _ in }
        )
    }

    private var homeTitle: String {
        if showOverviewGrid {
            return "Pinned"
        }
        if viewModel.pinnedZones.isEmpty {
            return "Home"
        }
        return viewModel.selectedZone?.name ?? "Home"
    }

    private var showOverviewGrid: Bool {
        pinnedOverview && !viewModel.pinnedZones.isEmpty && !isOverviewExpanded
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            loadingOrPinnedSection()

            if showPinnedHint && !viewModel.pinnedZones.isEmpty {
                PinnedHintCard {
                    withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.85)) {
                        showPinnedHint = false
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if !showOverviewGrid {
                if let aqi = viewModel.displayAqi,
                   let response = viewModel.currentAqi,
                   response.zoneId == viewModel.selectedZone?.id {
                    aqiSection(aqi: aqi, response: response)
                } else if let error = viewModel.error {
                    errorCard(error)
                } else if let zone = viewModel.selectedZone {
                    loadingCard(zone)
                }
            }
        }
        .padding()
    }

    private func loadingCard(_ zone: Zone) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading \(zone.name)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .card()
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Couldn't load air quality", systemImage: "wifi.exclamationmark")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                viewModel.dismissError()
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Text("Try Again")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
        }
        .card()
    }

    @ViewBuilder
    private func loadingOrPinnedSection() -> some View {
        if viewModel.zones.isEmpty && viewModel.isLoading {
            HStack {
                ProgressView()
                Text("Loading zones…")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        } else if viewModel.pinnedZones.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "pin.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("No locations pinned")
                    .font(.subheadline)

                Text("Go to the Search tab and pin some locations to monitor them here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical, 40)
        } else {
            pinnedLocationsSection()
        }
    }

    @ViewBuilder
    private func pinnedLocationsSection() -> some View {
        if pinnedOverview {
            pinnedOverviewSection()
        } else {
            pinnedChipsSection()
        }
    }

    @ViewBuilder
    private func pinnedOverviewSection() -> some View {
        if isOverviewExpanded {
            Button {
                withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.85)) {
                    isOverviewExpanded = false
                }
            } label: {
                Label("All Pinned Locations", systemImage: "chevron.left")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
            }
            .padding(.bottom, 6)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(viewModel.pinnedZones) { zone in
                    Button {
                        viewModel.selectedZone = zone
                        withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.85)) {
                            isOverviewExpanded = true
                        }
                    } label: {
                        PinnedOverviewCard(
                            zone: zone,
                            aqi: viewModel.displayAqi(for: zone.id),
                            isUsAqi: viewModel.isUsAqi
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private func pinnedChipsSection() -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(viewModel.pinnedZones) { zone in
                        pinnedChip(zone, proxy: proxy)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -16)
            .onChange(of: viewModel.selectedZone?.id) { _, id in
                guard let id else {
                    return
                }
                if reduceMotion {
                    proxy.scrollTo(id, anchor: .center)
                } else {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    private func pinnedChip(_ zone: Zone, proxy: ScrollViewProxy) -> some View {
        let isSelected = zone.id == viewModel.selectedZone?.id

        return Button {
            selectZone(zone, proxy: proxy)
        } label: {
            Text(zone.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .contextMenu {
            Button(role: .destructive) {
                viewModel.togglePin(for: zone)
            } label: {
                Label("Unpin", systemImage: "pin.slash")
            }
            if viewModel.pinnedZones.count > 1 {
                Button {
                    showReorderSheet = true
                } label: {
                    Label("Reorder Pinned", systemImage: "arrow.up.arrow.down")
                }
            }
        }
        .id(zone.id)
    }

    private func selectZone(_ zone: Zone, proxy: ScrollViewProxy) {
        if !reduceMotion {
            withAnimation {
                viewModel.selectedZone = zone
                proxy.scrollTo(zone.id, anchor: .center)
            }
        } else {
            viewModel.selectedZone = zone
            proxy.scrollTo(zone.id, anchor: .center)
        }
    }

    @ViewBuilder
    private func aqiSection(aqi: Int, response: AqiResponse) -> some View {
        let isAirGradient = !response.isEstimate
        sourceRow(response: response)
        if isAirGradient {
            Picker("Readings", selection: $viewModel.rawMode) {
                Text("Calibrated").tag(false)
                Text("Raw").tag(true)
            }
            .pickerStyle(.segmented)
            .disabled(response.raw == nil && !viewModel.rawMode)
        }
        rawNotice(response: response)
        dashboardLayout(aqi: aqi, response: response, isAirGradient: isAirGradient)
    }

    @ViewBuilder
    private func rawNotice(response: AqiResponse) -> some View {
        if response.showingRaw && !viewModel.rawHintHidden {
            VStack(alignment: .leading, spacing: 10) {
                Label("Showing this sensor's uncorrected readings.", systemImage: "info.circle")
                    .font(.subheadline)
                HStack {
                    NavigationLink("What changes") {
                        RawExplainerView()
                    }
                    Spacer()
                    Button("Don't show again") {
                        viewModel.rawHintHidden = true
                    }
                }
                .font(.subheadline)
            }
            .card()
        } else if viewModel.rawMode && response.isEstimate {
            Text("Raw readings are switched on, but there is no sensor here, so nothing changes.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if viewModel.rawMode && response.raw == nil {
            Text("Raw readings are switched on, but this sensor has no live reading to show raw, so these are the calibrated satellite numbers.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func dashboardLayout(aqi: Int, response: AqiResponse, isAirGradient: Bool) -> some View {
        // Use 24h average PM2.5 if available, otherwise fall back to current concentration.
        // This mirrors Android's: val pm25For24h = zone.averages24h?.get("pm2_5") ?: pm25
        let pm25Instant = response.concentrations?["pm2.5"]
            ?? response.concentrations?["pm2_5"]
            ?? 0.0
        let pm25 = response.averages24h?["pm2_5"]
            ?? response.averages24h?["pm2.5"]
            ?? pm25Instant
        let cigarettes = calculateCigarettes(pm25: pm25)

        let advice = healthAdviceFor(aqi, isUsAqi: viewModel.isUsAqi)

        if sizeClass == .regular {
            Grid(alignment: .top, horizontalSpacing: 16, verticalSpacing: 16) {
                GridRow {
                    aqiCard(aqi: aqi, response: response, fillsHeight: true)

                    VStack(spacing: 16) {
                        ContextRow(systemImage: "heart.fill", tint: aqiColor(aqi), title: advice.title, detail: advice.text)
                            .card()

                        if let weather = response.weather,
                           !weather.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            WeatherContextCard(weather: weather)
                                .card()
                        }

                        cigarettesCard(cigarettes: cigarettes)
                            .card()
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }

                GridRow {
                    VStack(alignment: .leading, spacing: 10) {
                        concentrationsSection(concentrations: response.concentrations)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)

                    VStack(alignment: .leading, spacing: 10) {
                        nodesSection(response: response)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }

                GridRow {
                    VStack(alignment: .leading, spacing: 10) {
                        historySection(history: response.history,
                                       nodes: response.nodes,
                                       isAirGradient: isAirGradient)
                    }
                    .gridCellColumns(2)
                }
            }
        } else {
            aqiCard(aqi: aqi, response: response)
            ContextRow(systemImage: "heart.fill", tint: aqiColor(aqi), title: advice.title, detail: advice.text)
                .card()
            if let weather = response.weather,
               !weather.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                WeatherContextCard(weather: weather)
                    .card()
            }
            cigarettesCard(cigarettes: cigarettes)
                .card()
            concentrationsSection(concentrations: response.concentrations)
            nodesSection(response: response)
            historySection(history: response.history, nodes: response.nodes, isAirGradient: isAirGradient)
        }
    }

    @ViewBuilder
    private func sourceRow(response: AqiResponse) -> some View {
        let line = placeLine(district: response.district, division: response.division)
        VStack(alignment: .leading, spacing: 4) {
            if !line.isEmpty {
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                if response.isEstimate {
                    Image(systemName: "cloud.sun")
                    Text("Satellite estimate, no sensor here yet")
                } else if response.isSensorOffline {
                    Image(systemName: "wifi.slash")
                    Text("Sensor offline, showing a satellite estimate")
                } else {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text(response.showingRaw ? "Live ground sensor · raw readings" : "Live ground sensor")
                }

                Spacer()

                if response.isEstimate {
                    let assetName = colorScheme == .dark ? "open_meteo_logo" : "open_meteo_logo_light"
                    Link(destination: URL(string: "https://www.open-meteo.com/")!) {
                        ProviderLogo(name: assetName, height: 18)
                    }
                } else {
                    Link(destination: URL(string: "https://www.airgradient.com/")!) {
                        ProviderLogo(name: "air_gradient_logo", height: 18)
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func aqiCard(aqi: Int, response: AqiResponse, fillsHeight: Bool = false) -> some View {
        let tint = aqiColor(aqi)
        let aqiTextColor = aqiDisplayTextColor(aqi)
        let label = AqiPalette.label(aqi, isUsAqi: viewModel.isUsAqi)
        let standard = AqiPalette.standardName(isUsAqi: viewModel.isUsAqi)
        let rowLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .lastTextBaseline))
        let footerLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout())

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(.title3))
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(response.showingRaw ? "Raw \(standard)" : standard)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .foregroundStyle(
                        AqiPalette.onColor(
                            aqi, isUsAqi: viewModel.isUsAqi
                        )
                    )
                    .background(
                        Capsule()
                            .fill(tint)
                    )
            }

            rowLayout {
                Text("\(aqi)")
                    .font(.system(size: heroNumberSize, weight: .heavy, design: .monospaced))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(aqi)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(aqiTextColor)

                Spacer()

                if let pollutant = viewModel.displayPollutant {
                    VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
                        Text("Primary")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        PollutantLabel(raw: pollutant, style: .title, weight: .bold)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            AqiGauge(aqi: aqi, isUsAqi: viewModel.isUsAqi)
                .padding(.vertical, 0)
                .onTapGesture {
                    showScaleSheet = true
                }

            Divider()
                .background(aqiColor(aqi).opacity(0.3))
                .padding(.vertical, 0)

            footerLayout {
                if let h = viewModel.display1hTrend {
                    trendItem(label: "1h", value: h)
                }

                Spacer()

                if let ts = viewModel.formattedLastUpdated {
                    Label(ts, systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let warning = response.warning, !warning.isEmpty {
                Label {
                    Text(warning)
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .font(.footnote)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        .modifier(AqiGlassBackground(tint: tint, isDark: colorScheme == .dark))
        .offset(x: heroDrag)
        .simultaneousGesture(heroSwipe)
        .accessibilityAction(named: "Next pinned location") {
            stepZone(by: 1)
        }
        .accessibilityAction(named: "Previous pinned location") {
            stepZone(by: -1)
        }
    }

    private var heroSwipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .updating($heroDrag) { value, state, _ in
                let dx = value.translation.width
                guard abs(dx) > abs(value.translation.height), viewModel.pinnedZones.count > 1 else {
                    return
                }
                state = dx / 4
            }
            .onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > 70, abs(dx) > abs(value.translation.height) * 1.5 else {
                    return
                }
                stepZone(by: dx < 0 ? 1 : -1)
            }
    }

    private func stepZone(by step: Int) {
        let zones = viewModel.pinnedZones
        guard let current = zones.firstIndex(where: { $0.id == viewModel.selectedZone?.id }) else {
            return
        }
        let next = current + step
        guard zones.indices.contains(next) else {
            return
        }
        viewModel.selectedZone = zones[next]
    }

    private func cigarettesCard(cigarettes: Double) -> some View {
        ContextRow(
            systemImage: "lungs.fill",
            tint: .pink,
            title: String(format: "Approx. %.1f cigarettes", cigarettes),
            detail: "Equivalent PM2.5 inhalation today"
        )
    }

    @ViewBuilder
    private func concentrationsSection(concentrations: [String: Double]?) -> some View {
        SectionHeader(title: "Concentrations")
            .padding(.top, 8)
            .id("concentrations")

        if let concentrations, !concentrations.isEmpty {
            pollutantGrid(concentrations: concentrations)
        }
    }

    @ViewBuilder
    private func nodesSection(response: AqiResponse) -> some View {
        if let nodes = response.nodes, !nodes.isEmpty {
            SectionHeader(title: "Sensors")
                .padding(.top, 8)
                .id("nodes")

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(nodes.sorted { $0.key < $1.key }, id: \.key) { key, value in
                    NodeReadingCard(nodeName: key, reading: value, isUsAqi: viewModel.isUsAqi)
                }
            }
        } else if !response.isEstimate {
            SectionHeader(title: "About this Sensor")
                .padding(.top, 8)
                .id("nodes")
            aboutSensorCard(response: response)
        }
    }

    private func aboutSensorCard(response: AqiResponse) -> some View {
        let info = viewModel.sensorInfos.first { $0.locationId == response.locationId }
        let suffix = response.showingRaw ? " (raw)" : ""
        let readings = response.readings
        let rows: [(String, String)] = [
            ("Temperature\(suffix)", readingText(readings?.temp, unit: " °C")),
            ("Humidity\(suffix)", readingText(readings?.humidity, unit: "%")),
            ("PM2.5\(suffix)", readingText(readings?.pm25, unit: " µg/m³")),
            ("PM10\(suffix)", readingText(readings?.pm10, unit: " µg/m³")),
        ]
        let locationText = (response.locationId ?? info?.locationId).map { String($0) } ?? "--"
        let facts: [(String, String)] = [
            ("Provider", info?.provider ?? "AirGradient"),
            ("Model", info?.model ?? "--"),
            ("Location ID", locationText),
            ("Installed", info?.installationDate ?? "--"),
        ]
        return VStack(alignment: .leading, spacing: 12) {
            if readings != nil {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(rows, id: \.0) { label, value in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(value)
                                .font(.headline)
                                .monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Divider()
            }
            ForEach(facts, id: \.0) { label, value in
                LabeledContent(label, value: value)
                    .font(.subheadline)
            }
        }
        .card()
    }

    private func readingText(_ value: Double?, unit: String) -> String {
        guard let value else {
            return "--"
        }
        return String(format: "%.1f", value) + unit
    }

    @ViewBuilder
    private func historySection(history: [HistoryPoint]?, nodes: [String: NodeReading]? = nil, isAirGradient: Bool = false) -> some View {
        if let history, !history.isEmpty {
            HStack {
                SectionHeader(title: "Last 24 Hours")

                Picker("History style", selection: $historyPage) {
                    Text("Trend").tag(0)
                    Text("Hourly").tag(1)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            .padding(.top, 8)
            .id("history")

            Group {
                if historyPage == 0 {
                    GraphView(history: history, isUsAqi: viewModel.isUsAqi)
                } else {
                    DotHistoryView(history: history, isUsAqi: viewModel.isUsAqi)
                }
            }
            .animation(reduceMotion ? .none : .snappy, value: historyPage)

            if isAirGradient {
                NavigationLink {
                    extendedHistoryView()
                } label: {
                    HStack {
                        Label("Extended History", systemImage: "clock.arrow.circlepath")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.tertiary)
                    }
                    .card()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func extendedHistoryView() -> some View {
        ExtendedHistoryView(
            zoneName: viewModel.selectedZone?.name ?? "Zone",
            placeText: placeLine(district: viewModel.currentAqi?.district, division: viewModel.currentAqi?.division),
            district: viewModel.currentAqi?.district
        )
        .environmentObject(viewModel)
        .onAppear {
            if let zoneId = viewModel.selectedZone?.id {
                viewModel.openHistory(zoneId: zoneId)
            }
        }
    }

    @ViewBuilder
    private func pollutantGrid(concentrations: [String: Double]) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(concentrations.sorted { $0.key < $1.key }, id: \.key) { key, value in
                VStack(alignment: .leading, spacing: 6) {
                    PollutantLabel(raw: key, style: .subheadline, weight: .medium)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formatConcentration(value))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text(concentrationUnit(key))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .card(padding: 14)
                .accessibilityElement(children: .combine)
            }
        }
        .animation(reduceMotion ? .none : .easeInOut, value: concentrations.count)
    }

    private func formatConcentration(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        }
        if value >= 10 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }

    private func concentrationUnit(_ key: String) -> String {
        let lower = key.lowercased()
        if lower == "ch4" || lower == "co" {
            return "mg/m³"
        }
        return "µg/m³"
    }

    // MARK: - Subviews & Formatting Logic
    @ViewBuilder
    private func trendItem(label: String, value: Int) -> some View {
        HStack(spacing: 6) {
            Text("\(label) Trend:")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 2) {
                Image(systemName: value == 0 ? "minus" : (value > 0 ? "arrow.up.right" : "arrow.down.right"))
                Text("\(abs(value))")
                    .monospacedDigit()
            }
            .font(.system(.subheadline, design: .rounded))
            .fontWeight(.bold)
            .foregroundStyle(value == 0 ? Color.secondary : (value < 0 ? Color.green : Color.red))
        }
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

    private func aqiBadgeTextColor(_ value: Int) -> Color {
        if viewModel.isUsAqi {
            return value < 101 ? .black : .white
        } else {
            return value < 201 ? .black : .white
        }
    }

    private func aqiLabel(_ value: Int) -> String {
        switch value {
        case ..<51:  return "Good"
        case ..<101: return "Moderate"
        case ..<151: return "Unhealthy for Sensitive Groups"
        case ..<201: return "Unhealthy"
        case ..<301: return "Very Unhealthy"
        default:     return "Hazardous"
        }
    }
}

private struct AqiGlassBackground: ViewModifier {
    let tint: Color
    let isDark: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        if #available(iOS 26, macOS 26, *) {
            content.glassEffect(
                .regular.tint(tint.opacity(isDark ? 0.22 : 0.16)).interactive(),
                in: shape
            )
        } else {
            content.background(
                shape
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(shape.fill(tint.opacity(isDark ? 0.22 : 0.16)))
            )
        }
    }
}

struct PollutantLabel: View {
    let raw: String
    var style: Font.TextStyle = .subheadline
    var weight: Font.Weight = .semibold
    @ScaledMetric(relativeTo: .caption) private var baselineShift: CGFloat = -1
    @ScaledMetric(relativeTo: .caption) private var digitShift: CGFloat = -2

    private var subscriptStyle: Font.TextStyle {
        switch style {
        case .largeTitle, .title: return .title3
        case .title2: return .headline
        case .title3: return .subheadline
        case .headline: return .footnote
        case .subheadline: return .caption
        default: return .caption2
        }
    }

    var body: some View {
        Text(formatted)
            .font(.system(style, design: .rounded).weight(weight))
    }

    private var formatted: AttributedString {
        let input = raw.lowercased().replacingOccurrences(of: "_", with: "")
        let subFont = Font.system(subscriptStyle, design: .rounded).weight(weight)
        var result = AttributedString()

        if input == "pm2.5" || input == "pm25" {
            result.append(AttributedString("PM"))
            var sub = AttributedString("2.5")
            sub.baselineOffset = baselineShift
            sub.font = subFont
            result.append(sub)
            return result
        } else if input == "pm10" {
            result.append(AttributedString("PM"))
            var sub = AttributedString("10")
            sub.baselineOffset = baselineShift
            sub.font = subFont
            result.append(sub)
            return result
        }

        for char in raw.uppercased() {
            if char.isNumber || char == "." {
                var sub = AttributedString(String(char))
                sub.baselineOffset = digitShift
                sub.font = subFont
                result.append(sub)
            } else {
                result.append(AttributedString(String(char)))
            }
        }
        return result
    }
}

struct WeatherContextCard: View {
    let weather: WeatherInfo

    private var conditionLabel: String {
        weather.condition.localizedCapitalized
    }

    private var seasonLabel: String {
        weather.season.localizedCapitalized
    }

    var body: some View {
        ContextRow(
            systemImage: weatherConditionSymbol(weather.condition),
            tint: .accentColor,
            title: "\(conditionLabel) · \(seasonLabel)",
            detail: weather.text
        )
    }
}

struct ContextRow: View {
    let systemImage: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Helper Views
struct ProviderLogo: View {
    let name: String
    let height: CGFloat
    
    var body: some View {
        if let path = Bundle.main.path(forResource: name, ofType: "png") {
#if os(iOS)
            if let uiImage = UIImage(contentsOfFile: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
            }
#elseif os(macOS)
            if let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
            }
#endif
        }
    }
}

#Preview {
    HomeView()
}
