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
        GridItem(.flexible()),
        GridItem(.flexible())
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
                extendedHistoryView(nodes: viewModel.currentAqi?.nodes)
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

            if !showOverviewGrid,
               let aqi = viewModel.displayAqi,
               let response = viewModel.currentAqi {
                aqiSection(aqi: aqi, response: response)
            }
        }
        .padding()
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
        let provider = response.source ?? viewModel.selectedZone?.provider ?? ""
        let isOpenMeteo = provider.localizedCaseInsensitiveContains("open-meteo") || provider.localizedCaseInsensitiveContains("openmeteo")
        let isAirGradient = provider.localizedCaseInsensitiveContains("airgradient")
        sourceRow(isAirGradient: isAirGradient, isOpenMeteo: isOpenMeteo)
        dashboardLayout(aqi: aqi, response: response, isAirGradient: isAirGradient)
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

        if sizeClass == .regular {
            Grid(alignment: .top, horizontalSpacing: 16, verticalSpacing: 16) {
                GridRow {
                    aqiCard(aqi: aqi, response: response, fillsHeight: true)

                    VStack(spacing: 16) {
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
                        nodesSection(nodes: response.nodes)
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
            if let weather = response.weather,
               !weather.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                WeatherContextCard(weather: weather)
                    .card()
            }
            cigarettesCard(cigarettes: cigarettes)
                .card()
            concentrationsSection(concentrations: response.concentrations)
            nodesSection(nodes: response.nodes)
            historySection(history: response.history, nodes: response.nodes, isAirGradient: isAirGradient)
        }
    }

    @ViewBuilder
    private func sourceRow(isAirGradient: Bool, isOpenMeteo: Bool) -> some View {
        HStack(spacing: 6) {
            if isAirGradient {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                Text("Live Ground Sensors")
            } else if isOpenMeteo {
                Image(systemName: "cloud.sun")
                Text("Satellite & Model Data")
            }

            Spacer()

            if isAirGradient {
                Link(destination: URL(string: "https://www.airgradient.com/")!) {
                    ProviderLogo(name: "air_gradient_logo", height: 18)
                }
            } else if isOpenMeteo {
                let assetName = colorScheme == .dark ? "open_meteo_logo" : "open_meteo_logo_light"
                Link(destination: URL(string: "https://www.open-meteo.com/")!) {
                    ProviderLogo(name: assetName, height: 18)
                }
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func aqiCard(aqi: Int, response: AqiResponse, fillsHeight: Bool = false) -> some View {
        let tint = aqiColor(aqi)
        let rowLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .lastTextBaseline))
        let footerLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout())

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(AqiPalette.label(aqi, isUsAqi: viewModel.isUsAqi))
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text(AqiPalette.standardName(isUsAqi: viewModel.isUsAqi))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .foregroundStyle(AqiPalette.onColor(aqi, isUsAqi: viewModel.isUsAqi))
                    .background(Capsule().fill(tint))
            }

            rowLayout {
                Text("\(aqi)")
                    .font(.system(size: heroNumberSize, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(aqi)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.primary)

                Spacer()

                if let pollutant = viewModel.displayPollutant {
                    VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
                        Text("Primary")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        PollutantLabel(raw: pollutant, style: .title3, weight: .semibold)
                            .foregroundStyle(.primary)
                    }
                }
            }

            setGaugeSpectrum(position: min(max(Double(aqi) / 500.0, 0), 1))
                .padding(.vertical, 4)

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
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(tint.opacity(colorScheme == .dark ? 0.22 : 0.16))
                )
        )
        .animation(reduceMotion ? .none : .snappy, value: aqi)
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
        Text("Concentrations")
            .font(.system(.title, design: .rounded))
            .fontWeight(.semibold)
            .padding(.top, 10)
            .id("concentrations")

        if let concentrations, !concentrations.isEmpty {
            pollutantGrid(concentrations: concentrations)
        }
    }

    @ViewBuilder
    private func nodesSection(nodes: [String: NodeReading]?) -> some View {
        if let nodes, !nodes.isEmpty {
            Text("Individual Node Readings")
                .font(.system(.title, design: .rounded))
                .fontWeight(.semibold)
                .padding(.top, 10)
                .id("nodes")
            
            VStack(spacing: 8) {
                // Determine layout: paired down similar to DashboardComponents.kt
                let sortedNodes = nodes.sorted { $0.key < $1.key }
                
                // Group by 2 for a compact grid or just a VStack
                // In iOS, a LazyVGrid with 2 columns or simply a VStack works.
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(sortedNodes, id: \.key) { key, value in
                        NodeReadingCard(nodeName: key, reading: value, isUsAqi: viewModel.isUsAqi)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func historySection(history: [HistoryPoint]?, nodes: [String: NodeReading]? = nil, isAirGradient: Bool = false) -> some View {
        if let history, !history.isEmpty {
            TabView(selection: $historyPage) {
                GraphView(history: history, isUsAqi: viewModel.isUsAqi, nodes: nodes)
                    .padding(.horizontal, 8)
                    .tag(0)
                DotHistoryView(history: history, isUsAqi: viewModel.isUsAqi)
                    .padding(.horizontal, 8)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 300)
            .id("history")
            .padding(.vertical, 10)
            .padding(.horizontal, -8)

            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .fill(index == historyPage ? Color.primary : Color.secondary.opacity(0.4))
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.2), value: historyPage)

            Text("Swipe for Dots History")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)

            // Extended History is backed by AirGradient ground sensor data, so it is
            // redundant on Open-Meteo only zones.
            if isAirGradient {
                NavigationLink {
                    extendedHistoryView(nodes: nodes)
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("View Extended History")
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.accentColor, lineWidth: 1)
                    )
                }
            }
        }
    }

    private func extendedHistoryView(nodes: [String: NodeReading]?) -> some View {
        ExtendedHistoryView(
            zoneName: viewModel.selectedZone?.name ?? "Zone",
            nodeKeys: nodes?.keys.sorted() ?? []
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
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(concentrations.sorted { $0.key < $1.key }, id: \.key) { key, value in
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.systemFill).opacity(0.4))

                    HStack {
                        PollutantLabel(raw: key, style: .headline)
                            .foregroundStyle(.primary.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .allowsTightening(true)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.2f", value))
                                .font(.system(.title, design: .rounded))
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .foregroundStyle(.primary)

                            let unit = (key.lowercased() == "ch4" || key.lowercased() == "co") ? "mg/m³" : "µg/m³"

                            Text(unit)
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, minHeight: 72)
                .onTapGesture { }
                .padding(.bottom, 6)
            }
        }
        .animation(reduceMotion ? .none : .easeInOut, value: concentrations.count)
    }
    
    // MARK: - Spectrum Helper
    @ViewBuilder
    private func setGaugeSpectrum(position: Double) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        stops: AqiPalette.gradientStops(isUsAqi: viewModel.isUsAqi),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 8)
                .padding(.horizontal, 5)
            GeometryReader { geo in
                let xOffset = geo.size.width * position - 8
                ZStack(alignment: .top) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(radius: 2)
                        .offset(x: xOffset)
                        .animation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.7), value: xOffset)
                }
            }
            .frame(height: 16)
        }
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
