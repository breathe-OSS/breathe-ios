import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct HomeView: View {
    
    @EnvironmentObject private var viewModel: BreatheViewModel
    @AppStorage("animationsEnabled") private var animationsEnabled = true
    @Environment(\.colorScheme) var colorScheme
    
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
            ScrollView {
                content
            }
            .navigationTitle("Breathe")
#if os(iOS)
            .navigationBarTitleDisplayMode(.automatic)
#endif
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            loadingOrPinnedSection()

            if let aqi = viewModel.displayAqi,
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
        Text("Pinned Locations")
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(.secondary)

        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.pinnedZones) { zone in
                        PinnedZoneChip(
                            zone: zone,
                            isSelected: zone.id == viewModel.selectedZone?.id,
                            animationsEnabled: animationsEnabled
                        ) {
                            selectZone(zone, proxy: proxy)
                        }
                        .id(zone.id)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.primary.opacity(0.05))
                )
                .padding(.bottom, 10)
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.05),
                        .init(color: .black, location: 0.95),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }

    private func selectZone(_ zone: Zone, proxy: ScrollViewProxy) {
        if animationsEnabled {
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
        let position = min(max(Double(aqi) / 500.0, 0), 1)
        let provider = response.source ?? viewModel.selectedZone?.provider ?? ""
        let isOpenMeteo = provider.localizedCaseInsensitiveContains("open-meteo") || provider.localizedCaseInsensitiveContains("openmeteo")
        let isAirGradient = provider.localizedCaseInsensitiveContains("airgradient")
        let pm25 = response.concentrations?["pm2.5"]
            ?? response.concentrations?["pm2_5"]
            ?? 0.0
        let cigarettes = calculateCigarettes(pm25: pm25)

        aqiHeader(isAirGradient: isAirGradient, isOpenMeteo: isOpenMeteo)
        aqiTitle(isAirGradient: isAirGradient, isOpenMeteo: isOpenMeteo)
        aqiCard(aqi: aqi, response: response)
        setGaugeSpectrum(position: position)
        cigarettesCard(cigarettes: cigarettes)
        concentrationsSection(concentrations: response.concentrations)
        historySection(history: response.history)
    }

    @ViewBuilder
    private func aqiHeader(isAirGradient: Bool, isOpenMeteo: Bool) -> some View {
        HStack(spacing: 8) {
            Label("Now Viewing", systemImage: "location.fill")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(.ultraThinMaterial))
                .foregroundStyle(.secondary)

            Spacer()

            if isAirGradient {
                Link(destination: URL(string: "https://www.airgradient.com/")!) {
                    ProviderLogo(name: "air_gradient_logo", height: 20)
                }
            } else if isOpenMeteo {
                let assetName = colorScheme == .dark ? "open_meteo_logo" : "open_meteo_logo_light"
                Link(destination: URL(string: "https://www.open-meteo.com/")!) {
                    ProviderLogo(name: assetName, height: 20)
                }
            }
        }
    }

    @ViewBuilder
    private func aqiTitle(isAirGradient: Bool, isOpenMeteo: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.selectedZone?.name ?? "Air Quality")
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.bold)
                .fontWidth(.expanded)

            if isAirGradient {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Live Ground Sensors")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            } else if isOpenMeteo {
                Text("Satellite & Model Data")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func aqiCard(aqi: Int, response: AqiResponse) -> some View {
        let aqiTextColor = aqiDisplayTextColor(aqi)

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(aqiLabel(aqi))
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(aqiTextColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                Spacer()

                Text(viewModel.isUsAqi ? "US AQI" : "NAQI")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .foregroundStyle(.background)
                    .background(
                        Capsule()
                            .fill(aqiColor(aqi))
                    )
            }

            HStack(alignment: .lastTextBaseline, spacing: 14) {
                Text("\(aqi)")
                    .font(.system(size: 72, weight: .heavy, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(aqiTextColor)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Primary")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)

                    if let pollutant = viewModel.displayPollutant {
                        Text(formatPollutant(pollutant))
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Divider()
                .background(aqiColor(aqi).opacity(0.3))
                .padding(.vertical, 4)

            HStack {
                if let h = viewModel.display1hTrend {
                    trendItem(label: "1h", value: h)
                }

                Spacer()

                if let ts = viewModel.formattedLastUpdated {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(ts)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let warning = response.warning, !warning.isEmpty {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(.footnote, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundStyle(Color.red)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(12)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(aqiColor(aqi).opacity(0.15))
        )
        .padding(.vertical, 6)
        .animation(animationsEnabled ? .snappy : .none, value: aqi)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func cigarettesCard(cigarettes: Double) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: "lungs.fill")
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "Approx. %.1f cigarettes", cigarettes))
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)

                Text("Equivalent PM2.5 inhalation today")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func concentrationsSection(concentrations: [String: Double]?) -> some View {
        Text("Concentrations")
            .font(.system(.title, design: .rounded))
            .fontWeight(.semibold)
            .padding(.top, 10)

        if let concentrations, !concentrations.isEmpty {
            pollutantGrid(concentrations: concentrations)
        }
    }

    @ViewBuilder
    private func historySection(history: [HistoryPoint]?) -> some View {
        if let history, !history.isEmpty {
            GraphView(history: history, isUsAqi: viewModel.isUsAqi)
                .padding(.vertical, 10)
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
                        Text(formatPollutant(key))
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary.opacity(0.6))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.2f", value))
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .foregroundStyle(.primary)

                            let unit = (key.lowercased() == "ch4" || key.lowercased() == "co") ? "mg/m³" : "µg/m³"

                            Text(unit)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
                .aspectRatio(16/6.5, contentMode: .fit)
                .onTapGesture { }
                .padding(.bottom, 6)
            }
        }
        .animation(animationsEnabled ? .easeInOut : .none, value: concentrations.count)
    }
    
    // MARK: - Spectrum Helper
    @ViewBuilder
    private func setGaugeSpectrum(position: Double) -> some View {
        ZStack(alignment: .leading) {
            if viewModel.isUsAqi {
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(stops: [
                            .init(color: Color(red: 0/255, green: 228/255, blue: 0/255), location: 0.0),      // Good
                            .init(color: Color(red: 255/255, green: 255/255, blue: 0/255), location: 0.10),   // Moderate
                            .init(color: Color(red: 255/255, green: 126/255, blue: 0/255), location: 0.20),   // Sensitive
                            .init(color: Color(red: 255/255, green: 0/255, blue: 0/255), location: 0.30),     // Unhealthy
                            .init(color: Color(red: 143/255, green: 63/255, blue: 151/255), location: 0.40),  // Very Unhealthy
                            .init(color: Color(red: 126/255, green: 0/255, blue: 35/255), location: 0.60)     // Hazardous
                        ], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(height: 8)
                    .padding(.horizontal, 5)
            } else {
                RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(stops: [
                        .init(color: Color(red: 0/255, green: 176/255, blue: 80/255), location: 0.0),      // Good
                        .init(color: Color(red: 146/255, green: 208/255, blue: 80/255), location: 0.10),   // Satisfactory
                        .init(color: Color(red: 255/255, green: 255/255, blue: 0/255), location: 0.20),   // Moderate
                        .init(color: Color(red: 244/255, green: 145/255, blue: 28/255), location: 0.40),   // Poor
                        .init(color: Color(red: 233/255, green: 63/255, blue: 51/255), location: 0.60),    // Very Poor
                        .init(color: Color(red: 175/255, green: 45/255, blue: 36/255), location: 0.80)     // Severe
                    ], startPoint: .leading, endPoint: .trailing)
                )
                    .frame(height: 8)
                    .padding(.horizontal, 5)
            }
            GeometryReader { geo in
                let xOffset = geo.size.width * position - 8
                ZStack(alignment: .top) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(radius: 2)
                        .offset(x: xOffset)
                        .animation(animationsEnabled ? .spring(response: 0.6, dampingFraction: 0.7) : .none, value: xOffset)
                }
            }
            .frame(height: 16)
        }
        .padding(.top, 10)
        .padding(.bottom, 40)
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
            return Color(red: 92/255, green: 67/255, blue: 0/255)
        }
        return aqiColor(value)
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
    
    private func formatPollutant(_ raw: String) -> AttributedString {
    let input = raw.lowercased().replacingOccurrences(of: "_", with: "")
    var result = AttributedString()
    
    if input == "pm2.5" || input == "pm25" {
        result.append(AttributedString("PM"))
        var sub = AttributedString("2.5")
        sub.baselineOffset = -2
        sub.font = .system(size: 12, weight: .bold)
        result.append(sub)
        return result
    } else if input == "pm10" {
        result.append(AttributedString("PM"))
        var sub = AttributedString("10")
        sub.baselineOffset = -2
        sub.font = .system(size: 12, weight: .bold)
        result.append(sub)
        return result
    }
    
    for char in raw.uppercased() {
        if char.isNumber || char == "." {
            var sub = AttributedString(String(char))
            sub.baselineOffset = -4
            sub.font = .system(size: 11)
            result.append(sub)
        } else {
            result.append(AttributedString(String(char)))
        }
    }
        return result
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

struct PinnedZoneChip: View {
    let zone: Zone
    let isSelected: Bool
    let animationsEnabled: Bool
    let onSelect: () -> Void

    var body: some View {
        Text(zone.name)
            .font(.system(.body, design: .rounded))
            .fontWeight(.semibold)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : chipBackground)
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .scaleEffect(isSelected ? 1.05 : 1)
            .animation(animationsEnabled ? .easeInOut(duration: 0.15) : .none, value: isSelected)
            .onTapGesture {
                onSelect()
            }
    }

    private var chipBackground: Color {
#if os(iOS)
        return Color(.tertiaryLabel).opacity(0.35)
#elseif os(macOS)
        return Color(nsColor: .tertiaryLabelColor).opacity(0.35)
#else
        return Color.gray.opacity(0.35)
#endif
    }
}