import SwiftUI

@main
struct MacCleanerApp: App {

    @StateObject private var container = AppContainer()
    @StateObject private var menuBarConfig = MenuBarConfig.shared
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

        MenuBarExtra(isInserted: Binding(
            get: { menuBarConfig.displayMode != .hidden },
            set: { shown in
                // Idempotent — SwiftUI calls `set` reactively during scene
                // evaluation, and an unconditional write fires a
                // UserDefaults notification that round-trips back into
                // another evaluation (infinite loop at 99% CPU).
                // Also: never clobber `.infoOnly` / `.iconOnly` back to
                // `.full` when the item is already visible.
                switch (shown, menuBarConfig.displayMode) {
                case (true, .hidden):       menuBarConfig.displayMode = .full
                case (false, let m) where m != .hidden: menuBarConfig.displayMode = .hidden
                default: break
                }
            }
        )) {
            MenuBarPopoverView(status: container.menuBarStatus)
                .environmentObject(container)
        } label: {
            MenuBarStatusLabel(status: container.menuBarStatus)
        }
        .menuBarExtraStyle(.window)
    }
}
