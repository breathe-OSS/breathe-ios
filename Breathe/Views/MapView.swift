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
                    let isSelected = viewModel.selectedZone?.id == zone.id
                    
                    AQIMarkerView(
                        zone: zone,
                        aqiData: aqiData,
                        isUsAqi: viewModel.isUsAqi,
                        isSelected: isSelected
                    )
                    .onTapGesture {
                        withAnimation(.spring) {
                            viewModel.selectedZone = zone
                            region.center = CLLocationCoordinate2D(latitude: zone.lat ?? 0, longitude: zone.lon ?? 0)
                        }
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
            .overlay(alignment: .bottom) {
                if viewModel.selectedZone != nil {
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
}

// MARK: - Selected Zone Quick Card
struct SelectedZoneCard: View {
    @EnvironmentObject private var viewModel: BreatheViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(viewModel.selectedZone?.name ?? "")
                    .font(.headline)
                Spacer()
                Button(action: {
                    withAnimation {
                        viewModel.selectedZone = nil
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
                .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
            
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
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    .offset(x: 12, y: -12)
            }
        }
        .scaleEffect(isSelected ? 1.3 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
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
