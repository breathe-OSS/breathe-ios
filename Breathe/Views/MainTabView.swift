import SwiftUI

struct MainTabView: View{
        var body: some View {
                TabView {
                        HomeView()
                            .tabItem {
                                    Label("Home", systemImage: "house.fill")
                                }
                        MapView()
                            .tabItem {
                                    Label("Map", systemImage: "map.fill")
                                }
                        SearchView()
                            .tabItem {
                                    Label("Search", systemImage: "magnifyingglass")
                                }
                        SettingsView()
                            .tabItem {
                                    Label("Settings", systemImage: "gearshape.fill")
                                }
                    }
            }
    }
