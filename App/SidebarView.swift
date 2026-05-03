import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarSection.allCases, id: \.self) { section in
                Section(section.rawValue) {
                    ForEach(items(in: section)) { item in
                        Label(item.title, systemImage: item.symbol)
                            .tag(item as SidebarItem?)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MacCleaner")
    }

    private func items(in section: SidebarSection) -> [SidebarItem] {
        SidebarItem.allCases.filter { $0.section == section }
    }
}
