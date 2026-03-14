import SwiftUI

@main
struct BreatheApp: App {
    @AppStorage("isDarkTheme") private var isDarkTheme = false
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(isDarkTheme ? .dark : .light)
        }
    }
}
