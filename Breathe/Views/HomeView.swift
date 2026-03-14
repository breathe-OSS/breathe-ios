import SwiftUI

struct HomeView: View {

    @EnvironmentObject private var viewModel: BreatheViewModel
    @AppStorage("animationsEnabled") private var animationsEnabled = true

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
                VStack(alignment: .leading, spacing: 22) {

                    Text("Pinned Location")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.semibold)
                        .fontWidth(.condensed)
                        .foregroundStyle(.primary)

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
                                .font(.headline)

                            Text("Go to the Search tab and pin some locations to monitor them here.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 40)
                    } else {

                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {

                                    ForEach(viewModel.pinnedZones) { zone in

                                        let isSelected = zone.id == viewModel.selectedZone?.id

                                        Text(zone.name)
                                            .font(.system(.body, design: .rounded))
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(
                                                        isSelected
                                                        ? Color.accentColor
                                                        : Color(.tertiaryLabel).opacity(0.35)
                                                    )
                                            )
                                            .foregroundStyle(isSelected ? .white : .primary)
                                            .scaleEffect(isSelected ? 1.1 : 1)
                                            .animation(animationsEnabled ? .easeInOut(duration: 0.15) : .none, value: viewModel.selectedZone)
                                            .id(zone.id)
                                            .onTapGesture {
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
                                    }
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    if let aqi = viewModel.displayAqi,
                       let response = viewModel.currentAqi {

                        let position = min(max(Double(aqi) / 500.0, 0), 1)

                        // --- provider detection
                        let provider = response.source ?? viewModel.selectedZone?.provider ?? ""
                        let isOpenMeteo = provider.localizedCaseInsensitiveContains("open-meteo") || provider.localizedCaseInsensitiveContains("openmeteo")
                        let isAirGradient = provider.localizedCaseInsensitiveContains("airgradient")
                        
                        // --- provider logo
                        HStack(spacing: 8) {

                            Label("Now Viewing", systemImage:"location.fill")
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.medium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(.ultraThinMaterial))
                                .foregroundStyle(.secondary)
                                
                            
                            
                            Spacer()

                            if isAirGradient {
                                Image("airgradient_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 20)
                            }

                            if isOpenMeteo {
                                Image("openmeteo_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 20)
                            }
                        }

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
                        VStack(alignment: .leading, spacing: 14) {
                        
                            HStack {
                                Text(aqiLabel(aqi))
                                    .font(.system(.title3, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundStyle(aqiColor(aqi))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                Spacer()
                                
                                Text(viewModel.isUsAqi ? "US AQI" : "Indian NAQI")
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
                                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(aqiColor(aqi))

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

                                    if let ts = response.lastUpdateStr {
                                        Text(ts)
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            
                            if let trends = response.trends {
                                Divider()
                                    .background(aqiColor(aqi).opacity(0.3))
                                    .padding(.vertical, 4)

                                HStack {
                                    if let h = trends.change1h {
                                        trendItem(label: "1h", value: h)
                                    }
                                    
                                    Spacer()

                                    if let d = trends.change24h {
                                        trendItem(label: "24h", value: d)
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

                            if let ts = response.lastUpdateStr {
                                Text("Updated \(ts)")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(22)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(aqiColor(aqi).opacity(0.15))
                        )
                        .padding(.vertical, 6)
                        .animation(animationsEnabled ? .snappy : .none, value: aqi)

                        ZStack(alignment: .leading) {

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color(red: 0/255, green: 228/255, blue: 0/255), location: 0.0),
                                            .init(color: Color(red: 255/255, green: 255/255, blue: 0/255), location: 0.16),
                                            .init(color: Color(red: 255/255, green: 126/255, blue: 0/255), location: 0.33),
                                            .init(color: Color(red: 255/255, green: 0/255, blue: 0/255), location: 0.50),
                                            .init(color: Color(red: 143/255, green: 63/255, blue: 151/255), location: 0.66),
                                            .init(color: Color(red: 126/255, green: 0/255, blue: 35/255), location: 1.0)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 8)

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
                        .padding(.bottom, 20)

                        // --- PM2.5 extraction
                        let pm25 =
                        response.concentrations?["pm2.5"]
                        ?? response.concentrations?["pm2_5"]
                        ?? 0.0

                        let cigarettes = calculateCigarettes(pm25: pm25)

                        HStack(spacing: 12) {

                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.2))
                                    .frame(width: 44, height: 44)

                                Image(systemName: "lungs.fill")
                                    .foregroundStyle(.red)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("≈ \(cigarettes, specifier: "%.1f") cigarettes")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.bold)

                                Text("Equivalent PM2.5 inhalation today")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("Concentrations")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.semibold)
                            .padding(.top, 10)

                        if let breakdown = response.aqiBreakdown,
                           !breakdown.isEmpty {

                            LazyVGrid(columns: columns, spacing: 12) {

                                ForEach(
                                    breakdown.sorted { $0.value > $1.value },
                                    id: \.key
                                ) { key, value in

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

                                                Text("\(value)")
                                                    .font(.system(.title2, design: .rounded))
                                                    .fontWeight(.bold)
                                                    .monospacedDigit()
                                                    .foregroundStyle(aqiColor(value))

                                                Text("µg/m³")
                                                    .font(.system(.caption2, design: .rounded))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding()
                                    }
                                    .aspectRatio(16/6.5, contentMode: .fit)
                                    .onTapGesture {
                                        // Empty tap handler to make the card react to taps visually (SwiftUI default highlight behavior)
                                    }
                                }
                            }
                            .animation(animationsEnabled ? .easeInOut : .none, value: breakdown)
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                if animationsEnabled {
                    await viewModel.refresh()
                } else {
                    await viewModel.refresh()
                }
            }
        }
        .navigationTitle("Breathe")
        .navigationBarTitleDisplayMode(.large)
    }

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
        switch value {
        case ..<51:  return .green
        case ..<101: return Color(red: 0.8, green: 0.7, blue: 0)
        case ..<151: return .orange
        case ..<201: return .red
        case ..<301: return .purple
        default:     return Color(red: 0.5, green: 0, blue: 0.1)
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

    private func formatPollutant(_ raw: String) -> AttributedString {

        let cleaned = raw.replacingOccurrences(of: "_", with: ".")
        var result = AttributedString()

        for char in cleaned.uppercased() {

            if char.isNumber {
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
