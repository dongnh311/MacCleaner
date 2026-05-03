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
                                        .foregroundStyle(selection == item ? item.accentColor : .secondary)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("MacCleaner")
            footer
        }
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
