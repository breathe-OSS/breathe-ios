import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var viewModel: BreatheViewModel
    @State private var searchText = ""

    var filteredZones: [Zone] {
        if searchText.isEmpty {
            return viewModel.zones
        } else {
            return viewModel.zones.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading && viewModel.zones.isEmpty {
                    ProgressView("Loading zones...")
                } else {
                    ForEach(filteredZones) { zone in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(zone.name)
                                    .font(.headline)
                            }
                            Spacer()
                            Button(action: {
                                viewModel.togglePin(for: zone)
                            }) {
                                Image(systemName: viewModel.pinnedZoneIds.contains(zone.id) ? "pin.fill" : "pin")
                                    .foregroundColor(viewModel.pinnedZoneIds.contains(zone.id) ? .blue : .gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search & Pin Zones")
            .searchable(text: $searchText, prompt: "Search locations...")
            .refreshable {
                await viewModel.loadZones()
            }
        }
    }
}
