import SwiftUI
struct SearchView: View {
@EnvironmentObject private var viewModel: BreatheViewModel
@State private var searchText = ""

var filteredZones: [Zone] {
    if searchText.isEmpty {
        return viewModel.zones
    } else {
        return viewModel.zones.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
}

var body: some View {

    NavigationStack {

        List {

            if viewModel.isLoading && viewModel.zones.isEmpty {

                ProgressView("Loading zones...")

            } else {

                ForEach(filteredZones) { zone in

                    let isPinned = viewModel.pinnedZoneIds.contains(zone.id)

                    Button {

                        viewModel.togglePin(for: zone)

                    } label: {

                        HStack(spacing: 12) {

                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 2) {

                                Text(zone.name)
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)

                                if let provider = zone.provider {

                                    Text(provider)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: isPinned ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(
                                    isPinned
                                    ? Color.accentColor
                                    : Color.secondary.opacity(0.5)
                                )
                        }
                        .padding(.vertical, 12)
                        .opacity(isPinned ? 1 : 0.85)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: isPinned)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Search & Pin Zones")
        .searchable(text: $searchText, prompt: "Search locations...")
        .refreshable {
            await viewModel.loadZones()
        }
    }
}
}
