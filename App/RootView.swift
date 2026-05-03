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
            SmartCareView()
        default:
            ModulePlaceholderView(selection: selection)
        }
    }
}
