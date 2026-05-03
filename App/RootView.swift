import SwiftUI

struct RootView: View {
    @State private var selection: SidebarItem? = .smartCare
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } content: {
            ModulePlaceholderView(selection: selection)
                .navigationSplitViewColumnWidth(min: 480, ideal: 640)
        } detail: {
            InspectorPlaceholderView()
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        }
        .navigationSplitViewStyle(.balanced)
    }
}
