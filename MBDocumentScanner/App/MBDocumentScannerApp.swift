import SwiftUI

@main
struct MBDocumentScannerApp: App {
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView(settings: settings)
                .environmentObject(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}
