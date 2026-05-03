import SwiftUI

@main
struct MacCleanerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 1000, minHeight: 640)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))

        Settings {
            SettingsView()
        }
    }
}
