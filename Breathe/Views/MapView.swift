import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject private var viewModel: BreatheViewModel
    
    // Default region covering J&K and Ladakh
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 34.75, longitude: 76.5),
        span: MKCoordinateSpan(latitudeDelta: 6.0, longitudeDelta: 9.0)
    )
    
    var body: some View {
        NavigationStack {
            Map(coordinateRegion: $region, annotationItems: viewModel.zones) { zone in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: zone.lat ?? 0, longitude: zone.lon ?? 0)) {
                    let aqiData = viewModel.allAqiData[zone.id]
                    let isSelected = viewModel.selectedMapZone?.id == zone.id
                    
                    AQIMarkerView(
                        zone: zone,
                        aqiData: aqiData,
                        isUsAqi: viewModel.isUsAqi,
                        isSelected: isSelected
                    )
                    .onTapGesture {
                        viewModel.selectedMapZone = zone
                    }
                }
            }
            .ignoresSafeArea(.container, edges: .top)
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await viewModel.fetchAllAqiData()
                }
            }
            .onChange(of: region.center.latitude) { _ in enforceBounds() }
            .onChange(of: region.center.longitude) { _ in enforceBounds() }
            .overlay(alignment: .bottom) {
                if viewModel.selectedMapZone != nil {
                    SelectedZoneCard()
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .padding(.bottom, 20)
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
    
    private func enforceBounds() {
        // Bounds roughly for North India / Himalayas
        let minLat: CLLocationDegrees = 26.0
        let maxLat: CLLocationDegrees = 38.0
        let minLon: CLLocationDegrees = 71.0
        let maxLon: CLLocationDegrees = 81.0
        
        var clampedLat = region.center.latitude
        var clampedLon = region.center.longitude
        var wasClamped = false
        
        if clampedLat < minLat { clampedLat = minLat; wasClamped = true }
        if clampedLat > maxLat { clampedLat = maxLat; wasClamped = true }
        if clampedLon < minLon { clampedLon = minLon; wasClamped = true }
        if clampedLon > maxLon { clampedLon = maxLon; wasClamped = true }
        
        if wasClamped {
            region.center = CLLocationCoordinate2D(latitude: clampedLat, longitude: clampedLon)
        }
    }
}

// MARK: - Selected Zone Quick Card
struct SelectedZoneCard: View {
    @EnvironmentObject private var viewModel: BreatheViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let provider = viewModel.selectedMapZone?.provider ?? ""
        let isOpenMeteo = provider.localizedCaseInsensitiveContains("open-meteo") || provider.localizedCaseInsensitiveContains("openmeteo")
        let isAirGradient = provider.localizedCaseInsensitiveContains("airgradient")
        
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(viewModel.selectedMapZone?.name ?? "")
                    .font(.headline)
                
                Spacer()
                
                if isAirGradient {
                    Link(destination: URL(string: "https://www.airgradient.com/")!) {
                        ProviderLogo(name: "air_gradient_logo", height: 16)
                    }
                } else if isOpenMeteo {
                    let assetName = colorScheme == .dark ? "open_meteo_logo" : "open_meteo_logo_light"
                    Link(destination: URL(string: "https://www.open-meteo.com/")!) {
                        ProviderLogo(name: assetName, height: 16)
                    }
                }
                
                Button(action: {
                    withAnimation {
                        viewModel.selectedMapZone = nil
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            }
            
            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 4)
            } else if let aqi = viewModel.displayAqi {
                HStack(alignment: .bottom) {
                    Text("\(aqi)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(aqiColor(aqi))
                    Text(viewModel.isUsAqi ? "US AQI" : "NAQI")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)
                    
                    Spacer()
                    if let p = viewModel.displayPollutant {
                        Text(p.uppercased())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            } else {
                Text("Waiting for data...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            
            // MARK: - Concentrations
            if let concentrations = viewModel.currentAqi?.concentrations, !concentrations.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(concentrations.sorted { $0.key < $1.key }, id: \.key) { key, value in
                            HStack(spacing: 4) {
                                Text(formatPollutant(key))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                
                                Text(String(format: "%.1f", value))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemFill).opacity(0.5))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 4)
                }
            }
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
struct AQIMarkerView: View {
    let zone: Zone
    let aqiData: AqiResponse?
    let isUsAqi: Bool
    let isSelected: Bool
    
    var body: some View {
        let aqiVal = getAqi()
        let color = getAqiColor(aqiVal)
        let isAirGradient = zone.provider?.localizedCaseInsensitiveContains("airgradient") == true
        
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
            
            if let aqiVal = aqiVal {
                Text("\(aqiVal)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(color == Color(red: 255/255, green: 255/255, blue: 0/255) ? .black : .white)
            } else {
                ProgressView()
                    .scaleEffect(0.6)
            }
            
            if isAirGradient {
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .offset(x: 12, y: -12)
            }
        }
    }
    
    private func getAqi() -> Int? {
        guard let data = aqiData else { return nil }
        return isUsAqi ? (data.usAqi ?? data.nAqi) : data.nAqi
    }
    
    private func getAqiColor(_ value: Int?) -> Color {
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
}
