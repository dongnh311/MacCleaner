import SwiftUI
import AppKit

@MainActor
struct SimilarPhotosView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var selectedFolder: URL?
    @State private var clusters: [PhotoCluster] = []
    @State private var keepIDs: [UUID: URL] = [:]
    @State private var phase: Phase = .idle
    @State private var lastError: String?
    @State private var threshold: Float = 12.0
    @StateObject private var progress = CleanProgressTracker()

    enum Phase { case idle, scanning, ready }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            controls
            Divider()
            content
            if !clusters.isEmpty {
                Divider()
                CleanProgressFooter(tracker: progress)
                actionBar
            }
        }
    }

    private var header: some View {
        ModuleHeader(
            icon: "photo.on.rectangle.angled",
            title: "Similar Photos",
            subtitle: "Vision feature-print clustering",
            accent: .purple
        )
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                pickFolder()
            } label: {
                Label(selectedFolder.map { $0.lastPathComponent } ?? "Pick Folder…", systemImage: "folder")
            }
            HStack(spacing: 6) {
                Text("Threshold:").font(.caption).foregroundStyle(.secondary)
                Slider(value: $threshold, in: 4...25, step: 1).frame(width: 140)
                Text(String(format: "%.0f", threshold))
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 24)
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
                Image(systemName: "photo.on.rectangle.angled").font(.system(size: 56)).foregroundStyle(.tint)
                Text("Pick a folder of images and press Scan").foregroundStyle(.secondary)
                if let lastError {
                    Text(lastError).font(.caption).foregroundStyle(.red)
                }
                Spacer()
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .scanning:
            VStack { Spacer(); ProgressView().controlSize(.large); Text("Computing feature prints…").foregroundStyle(.secondary).padding(.top, 8); Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            if clusters.isEmpty {
                VStack { Spacer(); Image(systemName: "checkmark.seal").font(.system(size: 36)).foregroundStyle(.green); Text("No similar photos found").padding(.top, 8); Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16, pinnedViews: []) {
                        ForEach(clusters) { cluster in
                            ClusterCard(
                                cluster: cluster,
                                keepURL: keepIDs[cluster.id]
                            ) { url in
                                keepIDs[cluster.id] = url
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var actionBar: some View {
        let toDelete = clusters.flatMap { c -> [URL] in
            guard let keep = keepIDs[c.id] else { return [] }
            return c.photos.filter { $0.url != keep }.map { $0.url }
        }
        let savings = clusters.reduce(Int64(0)) { acc, c in
            keepIDs[c.id] == nil ? acc : acc + c.redundantBytes
        }
        return HStack {
            Text("\(clusters.count) clusters • potential save \(savings.formattedBytes)")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Auto-pick largest") {
                for c in clusters {
                    if let largest = c.photos.max(by: { $0.size < $1.size }) {
                        keepIDs[c.id] = largest.url
                    }
                }
            }
            Button("Move \(toDelete.count) similar to Quarantine") {
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
            clusters = []
            keepIDs.removeAll()
            lastError = nil
            do {
                let config = ImageSimilarity.Config(distanceThreshold: threshold, maxImages: 5_000)
                clusters = try await container.imageSimilarity.findClusters(in: folder, config: config)
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
            progress.start(total: urls.count)
            let result = await container.quarantine.quarantine(urls, onProgress: progress.makeHandler())
            progress.finish()
            let succeededSet = Set(result.succeeded.keys.map { $0.path })
            clusters = clusters.compactMap { c in
                let remaining = c.photos.filter { !succeededSet.contains($0.url.path) }
                if remaining.count <= 1 { return nil }
                return PhotoCluster(id: c.id, photos: remaining)
            }
            keepIDs = keepIDs.filter { (id, _) in clusters.contains(where: { $0.id == id }) }
        }
    }
}

private struct ClusterCard: View {
    let cluster: PhotoCluster
    let keepURL: URL?
    let onKeep: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(cluster.photos.count) similar photos")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("Save \(cluster.redundantBytes.formattedBytes)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(cluster.photos) { photo in
                        VStack(spacing: 4) {
                            ZStack(alignment: .topTrailing) {
                                ThumbnailView(url: photo.url)
                                    .frame(width: 110, height: 110)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(keepURL == photo.url ? Color.yellow : Color.clear, lineWidth: 2)
                                    )
                                    .onTapGesture { onKeep(photo.url) }
                                if keepURL == photo.url {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                        .padding(4)
                                        .background(.regularMaterial, in: Circle())
                                        .padding(4)
                                }
                            }
                            Text(photo.size.formattedBytes)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(photo.name)
                                .font(.system(size: 10))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(width: 110)
                        }
                        .contextMenu {
                            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([photo.url]) }
                        }
                    }
                }
            }
        }
        .padding(12)
        .cardStyle(radius: 8, withShadow: false)
    }
}

private struct ThumbnailView: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.gray.opacity(0.2)
                    .overlay(ProgressView().controlSize(.small))
            }
        }
        .task(id: url) { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        // NSImage isn't Sendable; load on main actor (cheap for small thumbnails).
        let img = NSImage(contentsOf: url)
        if let img {
            img.size = NSSize(width: 220, height: 220)
        }
        self.image = img
    }
}
