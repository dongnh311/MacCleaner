import SwiftUI
import AppKit

@MainActor
struct AppPermissionsView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var entries: [TCCEntry] = []
    @State private var phase: Phase = .idle
    @State private var lastError: String?
    @State private var serviceFilter: TCCService?

    enum Phase { case idle, loading, ready, accessDenied }

    private var groupedByService: [(TCCService, [TCCEntry])] {
        let active = entries.filter { $0.isAllowed }
        let dict = Dictionary(grouping: active, by: { $0.service })
        return dict
            .sorted { lhs, rhs in lhs.key.displayName.localizedCaseInsensitiveCompare(rhs.key.displayName) == .orderedAscending }
            .map { ($0.key, $0.value.sorted { $0.client.localizedCaseInsensitiveCompare($1.client) == .orderedAscending }) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .task { if phase == .idle { await load() } }
    }

    private var header: some View {
        ModuleHeader(
            icon: "lock.shield",
            title: "App Permissions",
            subtitle: "TCC.db viewer — manage in System Settings"
        ) {
            Button {
                Task { await load() }
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .disabled(phase == .loading)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .loading:
            VStack { Spacer(); ProgressView().controlSize(.large); Text("Reading TCC database…").foregroundStyle(.secondary).padding(.top, 8); Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .accessDenied:
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "lock.fill").font(.system(size: 56)).foregroundStyle(.orange)
                Text("Full Disk Access required").font(.title3.weight(.semibold))
                Text("MacCleaner needs Full Disk Access to read TCC.db.\nGrant access in System Settings, then click Reload.")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Open System Settings → Full Disk Access") {
                    PermissionsService.openSettings(for: .fullDiskAccess)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
                if let lastError {
                    Text(lastError).font(.caption).foregroundStyle(.red).padding(.top, 4)
                }
                Spacer()
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            if groupedByService.isEmpty {
                VStack { Spacer(); Text("No permissions granted to any app").foregroundStyle(.secondary); Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(groupedByService, id: \.0) { (service, list) in
                            serviceSection(service: service, entries: list)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private func serviceSection(service: TCCService, entries: [TCCEntry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: service.systemImage).foregroundStyle(.tint)
                Text(service.displayName.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entries.count) app\(entries.count == 1 ? "" : "s")")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                if let url = service.settingsURL {
                    Button("Manage") { NSWorkspace.shared.open(url) }
                        .controlSize(.small)
                }
            }
            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    HStack(spacing: 8) {
                        AppIdentityCell(
                            bundleID: entry.client,
                            programPath: nil,
                            iconSize: 24,
                            fallbackSymbol: "lock.shield"
                        )
                        Spacer()
                        Text(entry.scope.displayName)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(scopeColor(entry.scope).opacity(0.15))
                            .foregroundStyle(scopeColor(entry.scope))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    if entry.id != entries.last?.id { Divider() }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func scopeColor(_ scope: TCCEntry.Scope) -> Color {
        scope == .user ? .green : .blue
    }

    private func load() async {
        phase = .loading
        lastError = nil
        do {
            entries = try await container.permissionsReader.readEntries()
            phase = .ready
        } catch PermissionsReader.ReadError.accessDenied {
            phase = .accessDenied
        } catch {
            lastError = error.localizedDescription
            phase = .accessDenied
        }
    }
}
