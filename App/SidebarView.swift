import SwiftUI

struct SidebarView: View {

    @EnvironmentObject private var container: AppContainer
    @Binding var selection: SidebarItem?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(SidebarSection.allCases, id: \.self) { section in
                    Section(section.rawValue) {
                        ForEach(SidebarItem.allCases.filter { $0.section == section }) { item in
                            NavigationLink(value: item) {
                                Label {
                                    Text(item.title)
                                } icon: {
                                    Image(systemName: item.symbol)
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(item.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .navigationTitle("MacCleaner")
            footer
        }
        .background(Color.clear)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "internaldrive")
                .foregroundStyle(.secondary)
                .font(.caption)
            DiskFreeText(status: container.menuBarStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                AppPresenter.openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings…")
            .keyboardShortcut(",")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

/// Subscribes to the menu-bar ticker (1s) instead of running its own 60s
/// timer so the footer follows Finder within a second of a Clean.
/// Uses `.onReceive(diskFreeBytes)` rather than `@ObservedObject` so the
/// node only re-renders on disk changes — not every CPU/RAM/net tick.
private struct DiskFreeText: View {
    let status: MenuBarStatusModel
    @State private var label: String = "—"

    var body: some View {
        Text(label)
            .onReceive(status.$diskFreeBytes.combineLatest(status.$diskTotalBytes)) { free, total in
                label = total > 0 ? "\(free.formattedBytes) free" : "—"
            }
    }
}
