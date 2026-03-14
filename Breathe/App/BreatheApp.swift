import SwiftUI

@main
struct BreatheApp: App {
    @AppStorage("isDarkTheme") private var isDarkTheme = false
    @StateObject private var viewModel = BreatheViewModel()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(viewModel)
                .preferredColorScheme(isDarkTheme ? .dark : .light)
        }
    }
}
