import SwiftUI
import AppKit

@MainActor
struct LargeOldFilesView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var selectedFolder: URL?
    @State private var minSizeMB: Double = 100
    @State private var olderThanDays: Int = 0
    @State private var nodes: [FileNode] = []
    @State private var phase: Phase = .idle
    @State private var lastError: String?
    @State private var selectedIDs = Set<URL>()
    @StateObject private var progress = CleanProgressTracker()

    enum Phase { case idle, scanning, ready }

    private static let ageOptions: [(label: String, days: Int)] = [
        ("Any age", 0),
        (">30 days", 30),
        (">90 days", 90),
        (">180 days", 180),
        (">1 year", 365),
        (">2 years", 730)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            controls
            Divider()
            content
            if !nodes.isEmpty {
                Divider()
                CleanProgressFooter(tracker: progress)
                actionBar
            }
        }
    }

    private var header: some View {
        ModuleHeader(
            icon: "doc.text.magnifyingglass",
            title: "Large & Old Files",
            subtitle: "Files matching size and age thresholds",
            accent: .purple
        )
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button {
                pickFolder()
            } label: {
                Label(selectedFolder.map { $0.lastPathComponent } ?? "Pick Folder…", systemImage: "folder")
            }

            Divider().frame(height: 22)

            HStack(spacing: 8) {
                Text("Min size:").font(.caption).foregroundStyle(.secondary)
                Slider(value: $minSizeMB, in: 10...5000, step: 10)
                    .frame(width: 160)
                Text("\(Int(minSizeMB)) MB").font(.system(.caption, design: .monospaced)).frame(width: 70, alignment: .leading)
            }

            HStack(spacing: 6) {
                Text("Age:").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $olderThanDays) {
                    ForEach(Self.ageOptions, id: \.days) { opt in
                        Text(opt.label).tag(opt.days)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 130)
            }

            Spacer()
            Button("Scan") { scan() }
                .buttonStyle(.borderedProminent)
                .disabled(selectedFolder == nil || phase == .scanning)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("Pick a folder and press Scan")
                    .foregroundStyle(.secondary)
                if let lastError {
                    Text(lastError).font(.caption).foregroundStyle(.red)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .scanning:
            VStack { Spacer(); ProgressView().controlSize(.large); Text("Scanning…").foregroundStyle(.secondary).padding(.top, 8); Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .ready:
            if nodes.isEmpty {
                VStack { Spacer(); Image(systemName: "checkmark.seal").font(.system(size: 36)).foregroundStyle(.green); Text("No files match these filters").padding(.top, 8); Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(nodes) { node in
                        HStack(spacing: 8) {
                            Toggle("", isOn: Binding(
                                get: { selectedIDs.contains(node.id) },
                                set: { newValue in
                                    if newValue { selectedIDs.insert(node.id) } else { selectedIDs.remove(node.id) }
                                }
                            ))
                            .labelsHidden()
                            Image(systemName: node.category == .media ? "photo" : "doc")
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(node.name).font(.system(size: 13)).lineLimit(1)
                                Text(node.url.path)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(node.size.formattedBytes)
                                    .font(.system(.body, design: .monospaced))
                                if let mod = node.lastModified {
                                    Text(mod.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                        .contextMenu {
                            Button("Reveal in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([node.url])
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    private var actionBar: some View {
        let selectedSize = nodes.filter { selectedIDs.contains($0.id) }.reduce(Int64(0)) { $0 + $1.size }
        return HStack {
            Text("\(selectedIDs.count) of \(nodes.count) selected • \(selectedSize.formattedBytes)")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Select All") { selectedIDs = Set(nodes.map { $0.id }) }
            Button("Deselect All") { selectedIDs.removeAll() }.disabled(selectedIDs.isEmpty)
            Button("Move to Quarantine") { moveToQuarantine() }
                .buttonStyle(.borderedProminent)
                .disabled(selectedIDs.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        if panel.runModal() == .OK, let url = panel.url {
            selectedFolder = url
        }
    }

    private func scan() {
        guard let folder = selectedFolder else { return }
        Task { @MainActor in
            phase = .scanning
            nodes = []
            selectedIDs.removeAll()
            lastError = nil
            do {
                let filter = LargeFilesScanner.Filter(
                    minBytes: Int64(minSizeMB) * 1024 * 1024,
                    olderThanDays: olderThanDays > 0 ? olderThanDays : nil,
                    maxResults: 1000
                )
                nodes = try await container.largeFilesScanner.scan(at: folder, filter: filter)
                phase = .ready
                Log.fs.info("LargeOldFiles: \(nodes.count) hits in \(folder.path, privacy: .public)")
            } catch {
                lastError = error.localizedDescription
                phase = .idle
            }
        }
    }

    private func moveToQuarantine() {
        let urls = nodes.filter { selectedIDs.contains($0.id) }.map { $0.url }
        guard !urls.isEmpty else { return }
        Task { @MainActor in
            progress.start(total: urls.count)
            let result = await container.quarantine.quarantine(urls, onProgress: progress.makeHandler())
            progress.finish()
            let succeededSet = Set(result.succeeded.keys.map { $0.path })
            nodes.removeAll { succeededSet.contains($0.url.path) }
            selectedIDs.removeAll()
            Log.fs.info("LargeOldFiles: quarantined \(result.succeeded.count) (failed: \(result.failed.count))")
        }
    }
}
