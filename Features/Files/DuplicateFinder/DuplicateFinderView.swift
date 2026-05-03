import SwiftUI
import AppKit

@MainActor
struct DuplicateFinderView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var selectedFolder: URL?
    @State private var groups: [DuplicateGroup] = []
    @State private var keepIDs: [UUID: URL] = [:]
    @State private var phase: Phase = .idle
    @State private var lastError: String?

    enum Phase { case idle, scanning, ready }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            controls
            Divider()
            content
            if !groups.isEmpty {
                Divider()
                actionBar
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 28))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Duplicate Finder").font(.title2.weight(.semibold))
                Text("Same content detected via SHA-256 byte-for-byte match").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                pickFolder()
            } label: {
                Label(selectedFolder.map { $0.lastPathComponent } ?? "Pick Folder…", systemImage: "folder")
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
                Image(systemName: "doc.on.doc").font(.system(size: 56)).foregroundStyle(.tint)
                Text("Pick a folder and press Scan").foregroundStyle(.secondary)
                if let lastError {
                    Text(lastError).font(.caption).foregroundStyle(.red)
                }
                Spacer()
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .scanning:
            VStack { Spacer(); ProgressView().controlSize(.large); Text("Hashing files…").foregroundStyle(.secondary).padding(.top, 8); Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            if groups.isEmpty {
                VStack { Spacer(); Image(systemName: "checkmark.seal").font(.system(size: 36)).foregroundStyle(.green); Text("No duplicates found").padding(.top, 8); Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                resultList
            }
        }
    }

    private var resultList: some View {
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.files) { file in
                        HStack(spacing: 8) {
                            Image(systemName: keepIDs[group.id] == file.url ? "star.fill" : "star")
                                .foregroundStyle(keepIDs[group.id] == file.url ? .yellow : .secondary)
                                .onTapGesture { keepIDs[group.id] = file.url }
                                .help("Mark this file to keep; others in the group will be deleted")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name).font(.system(size: 13)).lineLimit(1)
                                Text(file.url.path).font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                            }
                            Spacer()
                            if let mod = file.lastModified {
                                Text(mod.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                        .contextMenu {
                            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
                        }
                    }
                } header: {
                    HStack {
                        Text("\(group.files.count) copies × \(group.size.formattedBytes)")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text("Free \(group.redundantBytes.formattedBytes) by keeping one")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private var actionBar: some View {
        let unresolved = groups.filter { keepIDs[$0.id] == nil }.count
        let toDelete = groups.flatMap { group -> [URL] in
            guard let keep = keepIDs[group.id] else { return [] }
            return group.files.filter { $0.url != keep }.map { $0.url }
        }
        let savings = groups.reduce(Int64(0)) { acc, g in
            keepIDs[g.id] == nil ? acc : acc + g.redundantBytes
        }
        return HStack {
            Text(unresolved == 0
                 ? "All \(groups.count) groups resolved • will free \(savings.formattedBytes)"
                 : "\(unresolved) of \(groups.count) groups need a keeper")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Auto-pick newest") {
                for g in groups {
                    if let newest = g.files.max(by: { ($0.lastModified ?? .distantPast) < ($1.lastModified ?? .distantPast) }) {
                        keepIDs[g.id] = newest.url
                    }
                }
            }
            .disabled(groups.isEmpty)
            Button("Move \(toDelete.count) duplicates to Quarantine") {
                quarantine(urls: toDelete)
            }
            .buttonStyle(.borderedProminent)
            .disabled(toDelete.isEmpty)
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
            groups = []
            keepIDs.removeAll()
            lastError = nil
            do {
                groups = try await container.duplicateDetector.findDuplicates(in: folder)
                phase = .ready
            } catch {
                lastError = error.localizedDescription
                phase = .idle
            }
        }
    }

    private func quarantine(urls: [URL]) {
        guard !urls.isEmpty else { return }
        Task { @MainActor in
            let result = await container.quarantine.quarantine(urls)
            let succeededSet = Set(result.succeeded.keys.map { $0.path })
            groups = groups.compactMap { g in
                let remaining = g.files.filter { !succeededSet.contains($0.url.path) }
                if remaining.count <= 1 { return nil }
                return DuplicateGroup(id: g.id, size: g.size, files: remaining)
            }
            keepIDs = keepIDs.filter { (id, _) in groups.contains(where: { $0.id == id }) }
            Log.fs.info("DuplicateFinder: quarantined \(result.succeeded.count); \(result.failed.count) failed")
        }
    }
}
