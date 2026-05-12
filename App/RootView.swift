import SwiftUI

struct RootView: View {

    @EnvironmentObject private var container: AppContainer
    @State private var selection: SidebarItem? = .smartCare
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage(DefaultsKeys.recentActivityVisible) private var showInspector: Bool = false
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: DefaultsKeys.onboardingCompleted)

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
                .background(unifiedBackdrop)
        } content: {
            moduleContent
                .background(unifiedBackdrop)
                .navigationSplitViewColumnWidth(min: 480, ideal: 640)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            withAnimation(.smooth(duration: 0.25)) {
                                showInspector.toggle()
                            }
                        } label: {
                            Image(systemName: showInspector ? "sidebar.right" : "sidebar.right")
                                .symbolVariant(showInspector ? .none : .fill)
                        }
                        .help(showInspector ? "Hide Recent Activity" : "Show Recent Activity")
                        .keyboardShortcut("0", modifiers: [.command, .option])
                    }
                }
        } detail: {
            Group {
                if showInspector {
                    InspectorPlaceholderView()
                        .background(unifiedBackdrop)
                } else {
                    Color.clear
                }
            }
            .navigationSplitViewColumnWidth(
                min: showInspector ? 280 : 0,
                ideal: showInspector ? 320 : 0,
                max: showInspector ? 400 : 0
            )
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showOnboarding) {
            PermissionsWizardSheet()
                .environmentObject(container)
        }
        .background(navigationShortcuts)
        .onChange(of: selection) { newValue in
            Log.ui.notice("sidebar selection -> \(newValue?.rawValue ?? "nil", privacy: .public)")
        }
        .onReceive(container.$pendingNavigation.compactMap { $0 }) { item in
            selection = item
            container.pendingNavigation = nil
        }
    }

    /// Subtle gradient drawn behind every module — picks up the section accent so the
    /// app feels less monotonous when switching panels.
    private var moduleBackdrop: some View {
        let accent = selection?.accentColor ?? .accentColor
        return LinearGradient(
            colors: [accent.opacity(0.06), Color.clear, Color.clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    /// Same backdrop applied to all 3 columns so sidebar + content +
    /// inspector blend into one canvas. NSVisualEffectView with the
    /// underWindowBackground material is the only reliable way to defeat
    /// the per-column materials NavigationSplitView applies on macOS —
    /// SwiftUI's `.scrollContentBackground(.hidden)` alone isn't enough.
    private var unifiedBackdrop: some View {
        PopupBackground(accent: selection?.accentColor ?? .accentColor)
    }

    /// ⌘1..⌘8 jump to top-level modules. Hidden buttons used purely for shortcut routing.
    private var navigationShortcuts: some View {
        ZStack {
            ForEach(SidebarItem.allCases) { item in
                if let key = item.keyboardShortcut {
                    Button("") {
                        selection = item
                    }
                    .keyboardShortcut(key, modifiers: .command)
                    .opacity(0)
                    .allowsHitTesting(false)
                }
            }
        }
    }

    @ViewBuilder
    private var moduleContent: some View {
        switch selection {
        case .smartCare:
            SmartCareView()
        case .dashboard:
            DashboardView()
        case .quickClean:
            QuickCleanView()
        case .systemJunk:
            CleanupModuleView(
                scanner: container.systemJunkScanner,
                title: "System Junk",
                subtitle: "Caches, logs, dev-tool junk",
                symbol: "trash.circle"
            )
        case .mailAttachments:
            CleanupModuleView(
                scanner: container.mailAttachmentsScanner,
                title: "Mail Attachments",
                subtitle: "Mail.app downloaded attachments — re-fetched on demand",
                symbol: "envelope.badge"
            )
        case .photoJunk:
            CleanupModuleView(
                scanner: container.photoJunkScanner,
                title: "Photo Junk",
                subtitle: "Photos library caches and derivative thumbnails",
                symbol: "photo.stack"
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
        case .usageTrends:
            UsageTrendsView()
        case .memory:
            MemoryReleaseView()
        case .battery:
            BatteryMonitorView()
        case .sensors:
            SensorsView()
        case .network:
            NetworkView()
        case .bluetooth:
            BluetoothView()
        case .diskMonitor:
            DiskMonitorView()
        case .clock:
            ClockView()
        case .paint:
            PaintView()
        case .malware:
            MalwareView()
        case .privacy:
            CleanupModuleView(
                scanner: container.privacyCleaner,
                title: "Privacy",
                subtitle: "Browser data, recents, chat caches",
                symbol: "eye.slash",
                accent: .red
            )
        case .appPermissions:
            AppPermissionsView()
        case .shredder:
            ShredderView()
        case .quarantine:
            QuarantineView()
        case .myTools:
            MyToolsView(onNavigate: { selection = $0 })
        case .none:
            ModulePlaceholderView(selection: nil)
        }
    }
}
