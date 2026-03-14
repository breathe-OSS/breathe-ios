import SwiftUI

@main
struct BreatheApp: App {

    @AppStorage("themeMode") private var themeMode = "auto"

    @StateObject private var viewModel = BreatheViewModel()

    var body: some Scene {
        WindowGroup {

            MainTabView()
                .environmentObject(viewModel)
                .preferredColorScheme(colorScheme)
        }
    }

    private var colorScheme: ColorScheme? {
        switch themeMode {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil   // Auto (system)
        }
    }
}