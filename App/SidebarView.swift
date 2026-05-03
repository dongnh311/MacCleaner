import SwiftUI

struct SidebarView: View {

    @EnvironmentObject private var container: AppContainer
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarSection.allCases, id: \.self) { section in
                Section {
                    ForEach(items(in: section)) { item in
                        SidebarRow(item: item, selection: selection)
                            .tag(item as SidebarItem?)
                    }
                } header: {
                    Text(section.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .tracking(0.5)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MacCleaner")
        .safeAreaInset(edge: .bottom) {
            footer
        }
    }

    private func items(in section: SidebarSection) -> [SidebarItem] {
        SidebarItem.allCases.filter { $0.section == section }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "internaldrive")
                .foregroundStyle(.secondary)
                .font(.caption)
            DiskFreeText()
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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

private struct SidebarRow: View {
    let item: SidebarItem
    let selection: SidebarItem?

    private var isSelected: Bool { selection == item }

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(item.accentColor)
                .frame(width: 3)
                .opacity(isSelected ? 1 : 0)
            Image(systemName: item.symbol)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? item.accentColor : Color.secondary)
                .frame(width: 18)
            Text(item.title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            Spacer()
            if let key = item.keyboardShortcut {
                Text("⌘\(String(key.character))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .opacity(isSelected ? 0.8 : 0.4)
            }
        }
        .padding(.vertical, 1)
        .contentShape(Rectangle())
    }
}

private struct DiskFreeText: View {
    @EnvironmentObject private var container: AppContainer
    @State private var label: String = "—"
    @State private var refreshTimer: Timer?

    var body: some View {
        Text(label)
            .onAppear {
                refresh()
                let timer = Timer(timeInterval: 60.0, repeats: true) { _ in
                    Task { @MainActor in refresh() }
                }
                RunLoop.main.add(timer, forMode: .common)
                refreshTimer = timer
            }
            .onDisappear {
                refreshTimer?.invalidate()
                refreshTimer = nil
            }
    }

    private func refresh() {
        let sample = container.systemMetrics.sampleDisk()
        if sample.totalBytes > 0 {
            label = "\(sample.freeBytes.formattedBytes) free"
        }
    }
}
