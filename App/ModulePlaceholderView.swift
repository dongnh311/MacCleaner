import SwiftUI

struct ModulePlaceholderView: View {
    let selection: SidebarItem?

    var body: some View {
        if let item = selection {
            VStack(spacing: 16) {
                Image(systemName: item.symbol)
                    .font(.system(size: 48, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                Text(item.title)
                    .font(.system(size: 22, weight: .semibold))
                Text("Module not implemented yet.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Select a module")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
