import SwiftUI

@main
struct MBDocumentScannerApp: App {
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView(settings: settings)
                .environmentObject(settings)
                .tint(ScanTheme.accent)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}
