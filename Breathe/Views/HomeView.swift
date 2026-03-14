import SwiftUI

struct HomeView: View {

    @StateObject private var viewModel = BreatheViewModel()
    let columns = [
    GridItem(.flexible()),
    GridItem(.flexible())
    ]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Zone picker
                    Text("Location")
                        .font(.headline)

                    if viewModel.zones.isEmpty && viewModel.isLoading {
                        HStack {
                            ProgressView()
                            Text("Loading zones…")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Picker("Zone", selection: $viewModel.selectedZone) {
                            ForEach(viewModel.zones) { zone in
                                Text(zone.name).tag(Optional(zone))
                            }
                        }
                    }
                    
                    if let aqi = viewModel.displayAqi,
                       let response = viewModel.currentAqi {
                        let position = min(max(Double(aqi) / 500.0, 0), 1)
                        Label("Now Viewing", systemImage:"location.fill")
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .foregroundStyle(.secondary)
                            )
                        Text(viewModel.selectedZone?.name ?? "Air Quality")
                            .font(.title.bold())
                        // AQI card
                        VStack(alignment: .leading, spacing: 12) {

                            HStack(alignment: .lastTextBaseline, spacing: 12) {

                                Text("\(aqi)")
                                    .font(.system(size: 72, weight: .bold, design: .rounded))
                                    .foregroundStyle(aqiColor(aqi))

                                Spacer()
                                VStack(alignment: .leading, spacing: 2) {

                                    Text(aqiLabel(aqi))
                                        .font(.headline)
                                        .foregroundStyle(aqiColor(aqi))

                                    if let pollutant = viewModel.displayPollutant {
                                        Label(pollutant, systemImage: "aqi.medium")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            // Standard badge
                            Text(viewModel.isUsAqi ? "US AQI" : "Indian NAQI")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.ultraThinMaterial, in: Capsule())

                            // Warnings
                            if let warning = response.warning {
                                Label(warning, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }

                            // Last updated
                            if let ts = response.lastUpdateStr {
                                Text("Updated \(ts)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(aqiColor(aqi).opacity(0.15))
                        )
                        .padding(.vertical, 6)
                        ZStack(alignment: .leading) {

    RoundedRectangle(cornerRadius: 4)
        .fill(
            LinearGradient(
                colors: [
                    Color(red: 0/255, green: 228/255, blue: 0/255),
                    Color(red: 255/255, green: 255/255, blue: 0/255),
                    Color(red: 255/255, green: 126/255, blue: 0/255),
                    Color(red: 255/255, green: 0/255, blue: 0/255),
                    Color(red: 143/255, green: 63/255, blue: 151/255),
                    Color(red: 126/255, green: 0/255, blue: 35/255)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .frame(height: 8)

    GeometryReader { geo in
        Circle()
            .fill(Color.white)
            .frame(width: 16, height: 16)
            .shadow(radius: 2)
            .offset(x: geo.size.width * position - 8)
    }
    .frame(height: 16)
}
HStack(spacing: 12){
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.2))
                .frame(width: 44, height: 44)

            Image(systemName: "lungs.fill")
                .foregroundStyle(.red)
        }
        VStack(alignment: .leading) {
            Text("≈ \(Int(Double(aqi) / 22)) cigarettes")
                .font(.headline)
            Text("Equivalent PM2.5 inhalation today")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
                        // Pollutant breakdown
                    Text("Concentrations")
    .font(.headline)

if let breakdown = response.aqiBreakdown, !breakdown.isEmpty {

    LazyVGrid(columns: columns, spacing: 12) {

        ForEach(
            breakdown.sorted { $0.value > $1.value },
            id: \.key
        ) { key, value in

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemFill).opacity(0.5))

                HStack {
                    Text(key.uppercased())
                        .font(.subheadline.monospaced().bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(value)")
                            .font(.title3.bold())
                            .foregroundStyle(aqiColor(value))

                        Text("µg/m³")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .aspectRatio(16/6, contentMode: .fit)

        }
    }
}
                        // Trends
                        if let trends = response.trends {

                            Text("Trends")
                                .font(.headline)

                            if let h = trends.change1h {
                                trendRow(label: "Last 1 hour", value: h)
                            }

                            if let h = trends.change24h {
                                trendRow(label: "Last 24 hours", value: h)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Breathe")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {

            // AQI standard toggle
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.isUsAqi.toggle()
                } label: {
                    Text(viewModel.isUsAqi ? "US AQI" : "NAQI")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            // Loading spinner
            ToolbarItem(placement: .topBarLeading) {
                if viewModel.isLoading && viewModel.currentAqi != nil {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("Retry") { Task { await viewModel.refresh() } }
            Button("Dismiss", role: .cancel) { viewModel.dismissError() }
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    @ViewBuilder
    private func trendRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)

            Spacer()

            HStack(spacing: 3) {
                Image(systemName: value >= 0 ? "arrow.up" : "arrow.down")
                Text("\(abs(value))")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(value <= 0 ? .green : .red)
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
}