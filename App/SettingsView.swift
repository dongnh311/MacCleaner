import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var container: AppContainer

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gear") }
            QuarantineSettings()
                .tabItem { Label("Quarantine", systemImage: "tray.full") }
            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 540, height: 380)
    }
}

private struct GeneralSettings: View {
    @AppStorage("appearance.preference") private var appearance: String = "system"
    @AppStorage("startup.runSmartCare") private var runSmartCareOnLaunch: Bool = false

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    Text("Match System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                Toggle("Run Smart Care at launch", isOn: $runSmartCareOnLaunch)
            } header: {
                Text("Appearance & startup")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct QuarantineSettings: View {
    @EnvironmentObject private var container: AppContainer

    @State private var sessions: [(URL, Date, Int64)] = []
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quarantine")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Reveal Folder") {
                    let url = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(".MacCleanerQuarantine")
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                Button("Refresh") { Task { await reload() } }
            }
            Text("Items move to ~/.MacCleanerQuarantine/<timestamp>/ and are auto-purged after \(QuarantineService.retentionDays) days.")
                .font(.caption).foregroundStyle(.secondary)

            if sessions.isEmpty {
                Text(loading ? "Loading…" : "No quarantine sessions")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(sessions.enumerated()), id: \.offset) { (_, row) in
                        HStack {
                            Text(row.0.lastPathComponent)
                                .font(.system(size: 12, design: .monospaced))
                            Spacer()
                            Text(row.1.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(row.2.formattedBytes)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .trailing)
                        }
                    }
                }
                .listStyle(.bordered)
                .frame(maxHeight: .infinity)
            }
        }
        .padding()
        .task { await reload() }
    }

    private func reload() async {
        loading = true
        defer { loading = false }
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".MacCleanerQuarantine")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            sessions = []
            return
        }
        let prepared: [(URL, Date, Int64)] = await withTaskGroup(of: (URL, Date, Int64).self) { group in
            for url in entries {
                group.addTask {
                    let v = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                    let date = v?.contentModificationDate ?? .distantPast
                    let size = await Task.detached(priority: .background) {
                        FileSizeCalculator.walk(directory: url).total
                    }.value
                    return (url, date, size)
                }
            }
            var rows: [(URL, Date, Int64)] = []
            for await row in group { rows.append(row) }
            return rows
        }
        sessions = prepared.sorted { $0.1 > $1.1 }
    }
}

private struct AboutSettings: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            Text("MacCleaner")
                .font(.title.weight(.semibold))
            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?") • build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Personal macOS cleaner — feature-parity with CleanMyMac 5")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
