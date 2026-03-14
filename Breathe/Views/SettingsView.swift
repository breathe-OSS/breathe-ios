import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: BreatheViewModel
    @AppStorage("isDarkTheme") private var isDarkTheme = false
    @AppStorage("animationsEnabled") private var animationsEnabled = true
    
    @State private var showDataSourceDialog = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Appearance")) {
                    Toggle(isOn: $isDarkTheme) {
                        VStack(alignment: .leading) {
                            Text("Dark Theme")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("Toggle app appearance")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("General")) {
                    // Toggle for Indian NAQI. In the ViewModel, false means Indian NAQI, true means US EPA.
                    // We bind a custom binding so the toggle shows "on" when it's NAQI.
                    Toggle(isOn: Binding(
                        get: { !viewModel.isUsAqi },
                        set: { viewModel.isUsAqi = !$0 }
                    )) {
                        VStack(alignment: .leading) {
                            Text("Indian NAQI")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("Switch to Indian National AQI")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Data Standards")
                            .font(.headline)
                        Text(!viewModel.isUsAqi ? "Indian National Air Quality Index (NAQI)" : "US EPA (2024 Standard)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: { showDataSourceDialog = true }) {
                        VStack(alignment: .leading) {
                            Text("Data Sources")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("OpenMeteo & AirGradient ground sensors")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let url = URL(string: "https://github.com/breathe-OSS/breathe") {
                        Link(destination: url) {
                            VStack(alignment: .leading) {
                                Text("Breathe OSS")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("View Source on GitHub")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section(header: Text("Performance")) {
                    Toggle(isOn: $animationsEnabled) {
                        VStack(alignment: .leading) {
                            Text("Animations")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("Enable all animations")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("We, the People of Breathe")) {
                    ContributorLink(name: "Sidharth \"Siddhi\" Sharma", role: "Lead Developer (@sidharthify)", url: "https://github.com/sidharthify")
                    ContributorLink(name: "Aaditya Gupta", role: "Developer (@Flashwreck)", url: "https://github.com/Flashwreck")
                    ContributorLink(name: "Aditya Choudhary", role: "Contributor (@empirea9)", url: "https://github.com/empirea9")
                    ContributorLink(name: "Veer P.S Singh", role: "Contributor (@Lostless1907)", url: "https://github.com/Lostless1907")
                    ContributorLink(name: "Suvesh Moza", role: "Contributor (@suveshmoza)", url: "https://github.com/suveshmoza")
                }
            }
            .navigationTitle("Settings")
            .alert("Data Sources", isPresented: $showDataSourceDialog) {
                Button("Close", role: .cancel) { }
            } message: {
                Text("Jammu & Kashmir regions (excl. Srinagar and Jammu)\nAir quality pollutants data sourced from Open-Meteo.\n\nSrinagar and Jammu\nPM10 and PM2.5 sourced from AirGradient ground sensor, and others from Open-Meteo\n\nairgradient.com\nopen-meteo.com")
            }
        }
    }
}

struct ContributorLink: View {
    let name: String
    let role: String
    let url: String
    
    var body: some View {
        if let linkUrl = URL(string: url) {
            Link(destination: linkUrl) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(role)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
