import SwiftUI

struct ModulePlaceholderView: View {
    let selection: SidebarItem?

    var body: some View {
        if let item = selection {
            VStack(spacing: 0) {
                ModuleHeader(
                    icon: item.symbol,
                    title: item.title,
                    subtitle: "This module is not wired to a view yet",
                    accent: item.accentColor
                )
                EmptyStateView(
                    icon: item.symbol,
                    title: "\(item.title) is on the way",
                    message: "This module surface is reserved. The underlying scanner may already exist; the view just isn't routed.",
                    tint: item.accentColor
                ) {
                    EmptyView()
                }
            }
        } else {
            EmptyStateView(
                icon: "sidebar.left",
                title: "Select a module",
                message: "Pick anything from the sidebar to begin."
            ) {
                EmptyView()
            }
        }
    }
}
