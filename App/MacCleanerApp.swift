import SwiftUI

@main
struct MacCleanerApp: App {

    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environmentObject(container)
                .frame(minWidth: 1000, minHeight: 640)
                .task {
                    if SmokeTest.isEnabled {
                        await SmokeTest.run(container: container)
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))

        Settings {
            SettingsView()
                .environmentObject(container)
        }

        MenuBarExtra {
            MenuBarPopoverView(status: container.menuBarStatus)
                .environmentObject(container)
        } label: {
            MenuBarStatusLabel(status: container.menuBarStatus)
        }
        .menuBarExtraStyle(.window)
    }
}
