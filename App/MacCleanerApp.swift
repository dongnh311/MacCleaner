import SwiftUI

@main
struct MacCleanerApp: App {

    @StateObject private var container = AppContainer()
    @NSApplicationDelegateAdaptor(MacCleanerAppDelegate.self) private var appDelegate

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
        // Hidden title bar + unified toolbar = traffic lights float over
        // the sidebar / inspector and the toolbar shares the window's own
        // chrome rather than adding a separate strip.
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))

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
