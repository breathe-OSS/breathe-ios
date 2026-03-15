import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject private var viewModel: BreatheViewModel
    
    @State private var jkPolygons: [[CLLocationCoordinate2D]] = []
    @State private var ladakhPolygons: [[CLLocationCoordinate2D]] = []
    @State private var selectedZoneId: String?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                MapViewRepresentable(
                    zones: viewModel.zones,
                    allAqiData: viewModel.allAqiData,
                    isUsAqi: viewModel.isUsAqi,
                    jkPolygons: jkPolygons,
                    ladakhPolygons: ladakhPolygons,
                    selectedZoneId: $selectedZoneId,
                    onZoneSelected: { zone in
                        viewModel.selectedZone = zone
                    }
                )
                .ignoresSafeArea(edges: .all)
                
                if selectedZoneId != nil && viewModel.currentAqi != nil {
                    SelectedZoneCard(selectedZoneId: $selectedZoneId)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .padding(.bottom, 20)
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadGeoJSON()
                Task {
                    await viewModel.fetchAllAqiData()
                }
            }
        }
    }
    
    private func loadGeoJSON() {
        if jkPolygons.isEmpty {
            jkPolygons = GeoJSONParser.parseFeatures(from: "jammu-and-kashmir")
        }
        if ladakhPolygons.isEmpty {
            ladakhPolygons = GeoJSONParser.parseFeatures(from: "ladakh")
        }
    }
}

// MARK: - Selected Zone Quick Card
struct SelectedZoneCard: View {
    @EnvironmentObject private var viewModel: BreatheViewModel
    @Binding var selectedZoneId: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(viewModel.selectedZone?.name ?? "")
                    .font(.headline)
                Spacer()
                Button(action: {
                    withAnimation {
                        selectedZoneId = nil
                        viewModel.selectedZone = nil
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            }
            if let aqi = viewModel.displayAqi, viewModel.currentAqi != nil {
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
                .overlay(Circle().stroke(Color.white, lineWidth: 2.5)) // White outline
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
                    .frame(width: 12, height: 12) // Slightly bigger indicator
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

// MARK: - UIKit Wrapper
class ZoneAnnotation: NSObject, MKAnnotation {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String?
    
    init(zone: Zone) {
        self.id = zone.id
        self.coordinate = CLLocationCoordinate2D(latitude: zone.lat ?? 0, longitude: zone.lon ?? 0)
        self.title = zone.name
    }
}

class HostingAnnotationView: MKAnnotationView {
    private var hostingController: UIHostingController<AnyView>?
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        self.frame = CGRect(x: 0, y: 0, width: 44, height: 44) // Generous frame for scaling bounds
        self.backgroundColor = .clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup<Content: View>(with content: Content) {
        if let hc = hostingController {
            hc.rootView = AnyView(content)
        } else {
            let hc = UIHostingController(rootView: AnyView(content))
            hc.view.backgroundColor = .clear
            addSubview(hc.view)
            
            hc.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hc.view.centerXAnchor.constraint(equalTo: centerXAnchor),
                hc.view.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
            
            self.hostingController = hc
        }
    }
}

struct MapViewRepresentable: UIViewRepresentable {
    var zones: [Zone]
    var allAqiData: [String: AqiResponse]
    var isUsAqi: Bool
    var jkPolygons: [[CLLocationCoordinate2D]]
    var ladakhPolygons: [[CLLocationCoordinate2D]]
    
    @Binding var selectedZoneId: String?
    var onZoneSelected: ((Zone) -> Void)?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.isPitchEnabled = false
        
        // Locking Camera Bounds to J&K/Ladakh region
        let center = CLLocationCoordinate2D(latitude: 34.75, longitude: 76.5)
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 6.0, longitudeDelta: 9.0))
        mapView.cameraBoundary = MKMapView.CameraBoundary(coordinateRegion: region)
        mapView.cameraZoomRange = MKMapView.CameraZoomRange(minCenterCoordinateDistance: 30_000, maxCenterCoordinateDistance: 2_000_000)
        mapView.setRegion(region, animated: false)
        
        mapView.register(HostingAnnotationView.self, forAnnotationViewWithReuseIdentifier: "ZoneAnnotation")
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Draw Borders
        if mapView.overlays.isEmpty && (!jkPolygons.isEmpty || !ladakhPolygons.isEmpty) {
            for coords in jkPolygons {
                let poly = MKPolygon(coordinates: coords, count: coords.count)
                mapView.addOverlay(poly)
            }
            for coords in ladakhPolygons {
                let poly = MKPolygon(coordinates: coords, count: coords.count)
                mapView.addOverlay(poly)
            }
        }
        
        // Update Annotations
        let currentIds = Set(mapView.annotations.compactMap { ($0 as? ZoneAnnotation)?.id })
        let newIds = Set(zones.map { $0.id })
        
        var added: [Zone] = []
        var removed: [MKAnnotation] = []
        
        for zone in zones where !currentIds.contains(zone.id) {
            added.append(zone)
        }
        for ann in mapView.annotations {
            if let zAnn = ann as? ZoneAnnotation, !newIds.contains(zAnn.id) {
                removed.append(zAnn)
            }
        }
        
        if !removed.isEmpty { mapView.removeAnnotations(removed) }
        if !added.isEmpty {
            mapView.addAnnotations(added.map { ZoneAnnotation(zone: $0) })
        }
        
        // Refresh visible annotations to apply styling changes dynamically
        for annotation in mapView.annotations {
            if let zoneAnn = annotation as? ZoneAnnotation,
               let view = mapView.view(for: zoneAnn) as? HostingAnnotationView,
               let zone = zones.first(where: { $0.id == zoneAnn.id }) {
                
                let isSelected = selectedZoneId == zone.id
                let content = AQIMarkerView(
                    zone: zone,
                    aqiData: allAqiData[zone.id],
                    isUsAqi: isUsAqi,
                    isSelected: isSelected
                )
                // Need to dispatch update to avoid state modification during redraw loop warnings
                DispatchQueue.main.async { view.setup(with: content) }
                
                // Adjust z-index natively so the selected one comes to the very top in map hierarchy!
                view.layer.zPosition = isSelected ? 1 : 0
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            guard let zoneAnn = annotation as? ZoneAnnotation else { return nil }
            
            let identifier = "ZoneAnnotation"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? HostingAnnotationView
            if view == nil {
                view = HostingAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            }
            view?.annotation = annotation
            
            if let zone = parent.zones.first(where: { $0.id == zoneAnn.id }) {
                let content = AQIMarkerView(
                    zone: zone,
                    aqiData: parent.allAqiData[zone.id],
                    isUsAqi: parent.isUsAqi,
                    isSelected: parent.selectedZoneId == zone.id
                )
                view?.setup(with: content)
            }
            return view
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.4)
                renderer.lineWidth = 1.5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let zoneAnn = view.annotation as? ZoneAnnotation else { return }
            guard let zone = parent.zones.first(where: { $0.id == zoneAnn.id }) else { return }
            
            parent.selectedZoneId = zone.id
            parent.onZoneSelected?(zone)
            
            // Animation
            let currentSpan = mapView.region.span
            let newRegion = MKCoordinateRegion(center: zoneAnn.coordinate, span: currentSpan)
            mapView.setRegion(newRegion, animated: true)
            
            // Since we are using strictly custom styling in our SwiftUI layers to denote "selection",
            // we immediately gracefully deselect from MKMapView's inherent selection state tracking to prevent bugs.
            DispatchQueue.main.async {
                mapView.deselectAnnotation(zoneAnn, animated: false)
            }
        }
    }
}
