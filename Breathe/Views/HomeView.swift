import SwiftUI

struct HomeView: View {

    @StateObject private var viewModel = BreatheViewModel()

    var body: some View {
        NavigationStack {
            List {

                // Zone picker
                Section("Location") {
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
                }

                // AQI card
                if let aqi = viewModel.displayAqi, let response = viewModel.currentAqi {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {

                            HStack(alignment: .lastTextBaseline, spacing: 12) {
                                Text("\(aqi)")
                                    .font(.system(size: 72, weight: .bold, design: .rounded))
                                    .foregroundStyle(aqiColor(aqi))

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

                                Spacer()
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
                        .padding(.vertical, 6)
                    } header: {
                        Text("Air Quality")
                    }

                    // Pollutant breakdown
                    if let breakdown = response.aqiBreakdown, !breakdown.isEmpty {
                        Section("Breakdown") {
                            ForEach(breakdown.sorted { $0.value > $1.value }, id: \.key) { key, value in
                                HStack {
                                    Text(key.uppercased())
                                        .font(.subheadline.monospaced())
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(value)")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(aqiColor(value))
                                }
                            }
                        }
                    }

                    // Trends
                    if let trends = response.trends {
                        Section("Trends") {
                            if let h = trends.change1h {
                                trendRow(label: "Last 1 hour", value: h)
                            }
                            if let h = trends.change24h {
                                trendRow(label: "Last 24 hours", value: h)
                            }
                        }
                    }
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

                // Loading spinner in nav bar during background refresh
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
                Button("Retry")   { Task { await viewModel.refresh() } }
                Button("Dismiss", role: .cancel) { viewModel.dismissError() }
            } message: {
                Text(viewModel.error ?? "")
            }
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
            .foregroundStyle(value <= 0 ? .green : .red) // lower = better
        }
    }

    private func aqiColor(_ value: Int) -> Color {
        switch value {
        case ..<51:  return .green
        case ..<101: return Color(red: 0.8, green: 0.7, blue: 0) // yellow visible in dark mode
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
