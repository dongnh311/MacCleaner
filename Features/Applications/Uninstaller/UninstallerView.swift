import SwiftUI
import AppKit

@MainActor
struct UninstallerView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var apps: [InstalledApp] = []
    @State private var phase: Phase = .idle
    @State private var lastError: String?
    @State private var search: String = ""
    @State private var filter: SourceFilter = .all
    @State private var selectedApp: InstalledApp?
    @State private var leftovers: [AppLeftover] = []
    @State private var leftoverPhase: LeftoverPhase = .idle
    @State private var pendingUninstall: PendingUninstall?

    enum Phase { case idle, scanning, ready }
    enum LeftoverPhase { case idle, loading, ready }
    enum SourceFilter: String, CaseIterable, Identifiable {
        case all, system, user, appStore
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all:      return "All"
            case .system:   return "/Applications"
            case .user:     return "~/Applications"
            case .appStore: return "App Store"
            }
        }
    }

    struct PendingUninstall: Equatable {
        let app: InstalledApp
        let leftovers: [AppLeftover]
        var totalBytes: Int64 {
            app.size + leftovers.reduce(0) { $0 + $1.size }
        }
    }

    private var filteredApps: [InstalledApp] {
        var list = apps
        switch filter {
        case .all:      break
        case .system:   list = list.filter { !$0.isUserApp }
        case .user:     list = list.filter { $0.isUserApp }
        case .appStore: list = list.filter { $0.isAppStore }
        }
        if !search.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = search.lowercased()
            list = list.filter { $0.name.lowercased().contains(q) || ($0.bundleID?.lowercased().contains(q) ?? false) }
        }
        return list
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                header
                Divider()
                toolbar
                Divider()
                appList
            }
            .frame(minWidth: 380)

            inspector
                .frame(minWidth: 320, idealWidth: 360, maxWidth: 480)
        }
    }

    private var header: some View {
        ModuleHeader(
            icon: "xmark.bin",
            title: "Uninstaller",
            subtitle: "Remove apps with all leftovers"
        ) {
            Button {
                scan()
            } label: {
                Label(phase == .ready ? "Rescan" : "Scan", systemImage: "arrow.clockwise")
            }
            .disabled(phase == .scanning)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Picker("", selection: $filter) {
                ForEach(SourceFilter.allCases) { f in
                    Text(f.label).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 320)

            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search…", text: $search)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var appList: some View {
        switch phase {
        case .idle:
            VStack {
                Spacer()
                Image(systemName: "xmark.bin").font(.system(size: 56)).foregroundStyle(.tint)
                Text("Click Scan to list installed apps").foregroundStyle(.secondary).padding(.top, 8)
                if let lastError {
                    Text(lastError).font(.caption).foregroundStyle(.red).padding(.top, 4)
                }
                Spacer()
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .scanning:
            VStack {
                Spacer(); ProgressView().controlSize(.large); Text("Scanning Applications…").foregroundStyle(.secondary).padding(.top, 8); Spacer()
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            List(selection: Binding<URL?>(
                get: { selectedApp?.id },
                set: { newID in
                    if let id = newID, let app = apps.first(where: { $0.id == id }) {
                        select(app)
                    } else {
                        selectedApp = nil
                        leftovers = []
                        leftoverPhase = .idle
                    }
                }
            )) {
                ForEach(filteredApps) { app in
                    AppRow(app: app).tag(app.id)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    @ViewBuilder
    private var inspector: some View {
        if let app = selectedApp {
            VStack(spacing: 0) {
                inspectorHeader(app)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        leftoverSection
                        if let pending = pendingUninstall, pending.app.id == app.id {
                            confirmCard(pending)
                        }
                    }
                    .padding(16)
                }
                Divider()
                inspectorActions(app)
            }
        } else {
            VStack {
                Spacer()
                Text("Select an app to see details")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private func inspectorHeader(_ app: InstalledApp) -> some View {
        HStack(spacing: 12) {
            AppIcon(url: app.url).frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).font(.title3.weight(.semibold))
                if let v = app.version {
                    Text("Version \(v)\(app.buildVersion.map { " (\($0))" } ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let id = app.bundleID {
                    Text(id).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var leftoverSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LEFTOVERS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            switch leftoverPhase {
            case .idle:
                Text("Press Find Leftovers to inspect").font(.caption).foregroundStyle(.secondary)
            case .loading:
                HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Searching…").font(.caption).foregroundStyle(.secondary) }
            case .ready:
                if leftovers.isEmpty {
                    Text("No leftovers found").font(.caption).foregroundStyle(.green)
                } else {
                    VStack(spacing: 0) {
                        ForEach(leftovers) { left in
                            HStack(spacing: 8) {
                                Text(left.kind.displayName).font(.caption.weight(.medium)).frame(width: 130, alignment: .leading)
                                Text(left.url.path)
                                    .font(.system(size: 11, design: .monospaced))
                                    .lineLimit(1).truncationMode(.middle)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(left.size.formattedBytes)
                                    .font(.system(.caption, design: .monospaced))
                            }
                            .padding(.vertical, 4)
                            .contextMenu {
                                Button("Reveal in Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([left.url])
                                }
                            }
                            if left.id != leftovers.last?.id { Divider() }
                        }
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    let total = leftovers.reduce(Int64(0)) { $0 + $1.size }
                    Text("Total leftover: \(total.formattedBytes)")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }

    private func confirmCard(_ pending: PendingUninstall) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("Confirm uninstall").font(.callout.weight(.semibold))
            }
            Text("\(pending.app.name) (\(pending.app.size.formattedBytes)) plus \(pending.leftovers.count) leftover\(pending.leftovers.count == 1 ? "" : "s") will be moved to quarantine.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { pendingUninstall = nil }
                Button("Move \(pending.totalBytes.formattedBytes)") {
                    performUninstall(pending)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func inspectorActions(_ app: InstalledApp) -> some View {
        HStack(spacing: 8) {
            Button("Reveal") {
                NSWorkspace.shared.activateFileViewerSelecting([app.url])
            }
            Button("Find Leftovers") {
                findLeftovers(for: app)
            }
            .disabled(leftoverPhase == .loading)
            Spacer()
            Button(role: .destructive) {
                pendingUninstall = PendingUninstall(app: app, leftovers: leftovers)
            } label: {
                Label("Uninstall", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(12)
    }

    // MARK: - Actions

    private func scan() {
        Task { @MainActor in
            phase = .scanning
            apps = []
            selectedApp = nil
            leftovers = []
            leftoverPhase = .idle
            lastError = nil
            apps = await container.appScanner.scan()
            phase = .ready
            Log.app.info("UninstallerView: \(apps.count) apps found")
        }
    }

    private func select(_ app: InstalledApp) {
        selectedApp = app
        leftovers = []
        leftoverPhase = .idle
    }

    private func findLeftovers(for app: InstalledApp) {
        Task { @MainActor in
            leftoverPhase = .loading
            leftovers = await container.leftoverDetector.detect(for: app)
            leftoverPhase = .ready
        }
    }

    private func performUninstall(_ pending: PendingUninstall) {
        Task { @MainActor in
            var allURLs: [URL] = [pending.app.url]
            allURLs.append(contentsOf: pending.leftovers.map { $0.url })
            let result = await container.quarantine.quarantine(allURLs)
            let succeededSet = Set(result.succeeded.keys.map { $0.path })
            if succeededSet.contains(pending.app.url.path) {
                apps.removeAll { $0.id == pending.app.id }
                if selectedApp?.id == pending.app.id {
                    selectedApp = nil
                    leftovers = []
                    leftoverPhase = .idle
                }
            }
            pendingUninstall = nil
            Log.app.info("Uninstalled \(pending.app.name, privacy: .public) — succeeded: \(result.succeeded.count), failed: \(result.failed.count)")
        }
    }
}

private struct AppRow: View {
    let app: InstalledApp

    var body: some View {
        HStack(spacing: 10) {
            AppIcon(url: app.url).frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.name).font(.system(size: 13, weight: .medium))
                    if app.isAppStore {
                        Text("MAS").font(.system(size: 9, weight: .bold)).padding(.horizontal, 4).padding(.vertical, 1).background(Color.indigo.opacity(0.2)).foregroundStyle(.indigo).clipShape(Capsule())
                    }
                    if app.isUserApp {
                        Text("USER").font(.system(size: 9, weight: .bold)).padding(.horizontal, 4).padding(.vertical, 1).background(Color.gray.opacity(0.2)).foregroundStyle(.secondary).clipShape(Capsule())
                    }
                }
                HStack(spacing: 6) {
                    if let v = app.version { Text("v\(v)").font(.caption).foregroundStyle(.secondary) }
                    if let id = app.bundleID {
                        Text(id).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                }
            }
            Spacer()
            Text(app.size.formattedBytes)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct AppIcon: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                Color.gray.opacity(0.15)
            }
        }
        .task(id: url) { loadIcon() }
    }

    private func loadIcon() {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 64, height: 64)
        self.image = icon
    }
}
