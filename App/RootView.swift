import SwiftUI

struct RootView: View {

    @EnvironmentObject private var container: AppContainer
    @State private var selection: SidebarItem? = .smartCare
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "onboarding.completed")

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } content: {
            moduleContent
                .navigationSplitViewColumnWidth(min: 480, ideal: 640)
        } detail: {
            InspectorPlaceholderView()
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showOnboarding) {
            PermissionsWizardSheet()
                .environmentObject(container)
        }
    }

    @ViewBuilder
    private var moduleContent: some View {
        switch selection {
        case .smartCare:
            SmartCareView(onNavigate: { selection = $0 })
        case .dashboard:
            DashboardView()
        case .systemJunk:
            CleanupModuleView(
                scanner: container.systemJunkScanner,
                title: "System Junk",
                subtitle: "Caches, logs, dev-tool junk",
                symbol: "trash.circle"
            )
        case .trashBins:
            CleanupModuleView(
                scanner: container.trashBinScanner,
                title: "Trash Bins",
                subtitle: "Items in user and external-volume trash",
                symbol: "trash"
            )
        case .spaceLens:
            SpaceLensView()
        case .largeOldFiles:
            LargeOldFilesView()
        case .duplicates:
            DuplicateFinderView()
        case .similarPhotos:
            SimilarPhotosView()
        case .uninstaller:
            UninstallerView()
        case .updater:
            UpdaterView()
        case .maintenance:
            MaintenanceView()
        case .loginItems:
            LoginItemsView()
        case .processMonitor:
            ProcessMonitorView()
        case .memory:
            MemoryReleaseView()
        case .battery:
            BatteryMonitorView()
        case .malware:
            MalwareView()
        case .privacy:
            CleanupModuleView(
                scanner: container.privacyCleaner,
                title: "Privacy",
                subtitle: "Browser data, recents, chat caches",
                symbol: "eye.slash"
            )
        case .appPermissions:
            AppPermissionsView()
        case .myTools:
            MyToolsView(onNavigate: { selection = $0 })
        default:
            ModulePlaceholderView(selection: selection)
        }
    }
}
