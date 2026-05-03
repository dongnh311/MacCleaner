import SwiftUI
import AppKit

@MainActor
struct LoginItemsView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var items: [LoginItem] = []
    @State private var phase: Phase = .idle
    @State private var lastError: String?
    @State private var search: String = ""
    @State private var scopeFilter: ScopeFilter = .all
    @State private var togglingLabels = Set<String>()

    enum Phase { case idle, scanning, ready }
    enum ScopeFilter: String, CaseIterable, Identifiable {
        case all, user, system
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all:    return "All"
            case .user:   return "User"
            case .system: return "System"
            }
        }
    }

    private var filtered: [LoginItem] {
        var list = items
        switch scopeFilter {
        case .all:    break
        case .user:   list = list.filter { $0.scope == .userAgent }
        case .system: list = list.filter { $0.scope != .userAgent }
        }
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = list.filter { $0.label.lowercased().contains(q) || ($0.program?.lowercased().contains(q) ?? false) }
        }
        return list
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            toolbar
            Divider()
            content
        }
        .task { if items.isEmpty { await reload() } }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "power")
                .font(.system(size: 28))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Login Items").font(.title2.weight(.semibold))
                Text("LaunchAgents and Daemons that auto-start").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await reload() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(phase == .scanning)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Picker("", selection: $scopeFilter) {
                ForEach(ScopeFilter.allCases) { f in Text(f.label).tag(f) }
            }
            .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 240)
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search…", text: $search).textFieldStyle(.plain)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            Spacer()
            Text("\(filtered.count) of \(items.count)").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .scanning:
            VStack {
                Spacer()
                if phase == .scanning {
                    ProgressView().controlSize(.large)
                    Text("Reading LaunchAgents…").foregroundStyle(.secondary).padding(.top, 8)
                }
                Spacer()
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            if filtered.isEmpty {
                VStack { Spacer(); Text("No items match").foregroundStyle(.secondary); Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filtered) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.isDisabled ? "power.circle" : "power.circle.fill")
                                .foregroundStyle(item.isDisabled ? Color.secondary : Color.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.label).font(.system(size: 13, weight: .medium))
                                if let program = item.program {
                                    Text(program)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1).truncationMode(.middle)
                                }
                            }
                            Spacer()
                            Text(item.scope.displayName)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(scopeColor(item.scope).opacity(0.15))
                                .foregroundStyle(scopeColor(item.scope))
                                .clipShape(Capsule())
                            if togglingLabels.contains(item.label) {
                                ProgressView().controlSize(.small)
                            } else if item.scope == .userAgent {
                                Toggle("", isOn: Binding(
                                    get: { !item.isDisabled },
                                    set: { _ in toggle(item) }
                                ))
                                .labelsHidden()
                            } else {
                                Text("admin").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .contextMenu {
                            Button("Reveal Plist") {
                                NSWorkspace.shared.activateFileViewerSelecting([item.plistURL])
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    private func scopeColor(_ scope: LoginItem.Scope) -> Color {
        switch scope {
        case .userAgent:    return .green
        case .systemAgent:  return .blue
        case .systemDaemon: return .red
        }
    }

    private func reload() async {
        phase = .scanning
        items = await container.loginItems.enumerate()
        phase = .ready
        Log.app.info("LoginItems: \(items.count) items")
    }

    private func toggle(_ item: LoginItem) {
        Task { @MainActor in
            togglingLabels.insert(item.label)
            let ok = await container.loginItems.toggle(item: item)
            togglingLabels.remove(item.label)
            if ok {
                await reload()
            } else {
                lastError = "launchctl toggle failed for \(item.label)"
            }
        }
    }
}
