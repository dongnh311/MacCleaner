import SwiftUI
import AppKit

@MainActor
struct SpaceLensView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var pathStack: [URL] = []
    @State private var children: [FileNode] = []
    @State private var phase: Phase = .idle
    @State private var hoveredNode: FileNode?
    @State private var lastError: String?

    enum Phase: Equatable { case idle, scanning, ready }

    private var currentURL: URL? { pathStack.last }
    private var totalSize: Int64 { children.reduce(0) { $0 + $1.size } }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            breadcrumbs
            Divider()
            content
            if !children.isEmpty {
                Divider()
                detailBar
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 28))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Space Lens").font(.title2.weight(.semibold))
                Text("Treemap of disk usage").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                ForEach(volumes(), id: \.self) { vol in
                    Button(volumeLabel(vol)) { startScan(at: vol) }
                }
                Divider()
                Button("Choose Folder…", action: pickFolder)
            } label: {
                Label(currentURL.map { displayName($0) } ?? "Pick Volume", systemImage: "internaldrive")
            }
            .frame(maxWidth: 220)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var breadcrumbs: some View {
        HStack(spacing: 4) {
            if pathStack.isEmpty {
                Text("No location selected")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(pathStack.enumerated()), id: \.offset) { (index, url) in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Button(displayName(url)) {
                        pathStack = Array(pathStack.prefix(index + 1))
                        rescan()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "chart.pie")
                    .font(.system(size: 64))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                Text("Pick a volume or folder to begin")
                    .foregroundStyle(.secondary)
                if let lastError {
                    Text(lastError).font(.caption).foregroundStyle(.red)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .scanning:
            VStack(spacing: 12) {
                Spacer()
                ProgressView().controlSize(.large)
                Text("Scanning…").foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .ready:
            if children.isEmpty {
                VStack { Spacer(); Text("No content").foregroundStyle(.secondary); Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { proxy in
                    let tiles = TreemapLayout.layout(
                        children,
                        in: CGRect(origin: .zero, size: proxy.size),
                        value: { Double($0.size) }
                    )
                    ZStack(alignment: .topLeading) {
                        ForEach(tiles, id: \.id) { tile in
                            TreemapTileView(
                                node: tile.item,
                                rect: tile.rect,
                                isHovered: hoveredNode == tile.item,
                                onTap: { drillIn(tile.item) },
                                onHover: { hovering in hoveredNode = hovering ? tile.item : nil }
                            )
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .padding(2)
            }
        }
    }

    private var detailBar: some View {
        HStack(spacing: 12) {
            if let hover = hoveredNode {
                Image(systemName: hover.isDirectory ? "folder" : "doc")
                    .foregroundStyle(.tint)
                Text(hover.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(hover.url.path).font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                Spacer()
                Text(hover.size.formattedBytes)
                    .font(.system(.body, design: .monospaced))
            } else {
                Text("\(children.count) item\(children.count == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Total: \(totalSize.formattedBytes)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    // MARK: - Actions

    private func volumes() -> [URL] {
        container.hierarchicalScanner.mountedVolumes()
    }

    private func volumeLabel(_ url: URL) -> String {
        if url.path == "/" { return "Macintosh HD (/)" }
        return url.lastPathComponent
    }

    private func displayName(_ url: URL) -> String {
        if url.path == "/" { return "/" }
        return url.lastPathComponent
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            startScan(at: url)
        }
    }

    private func startScan(at url: URL) {
        pathStack = [url]
        rescan()
    }

    private func drillIn(_ node: FileNode) {
        guard node.isDirectory else {
            NSWorkspace.shared.activateFileViewerSelecting([node.url])
            return
        }
        pathStack.append(node.url)
        rescan()
    }

    private func rescan() {
        guard let url = currentURL else { return }
        Task { @MainActor in
            phase = .scanning
            lastError = nil
            children = await container.hierarchicalScanner.listChildren(of: url)
            phase = .ready
        }
    }
}

private struct TreemapTileView: View {
    let node: FileNode
    let rect: CGRect
    let isHovered: Bool
    let onTap: () -> Void
    let onHover: (Bool) -> Void

    var body: some View {
        let area = max(20, rect.width * rect.height)
        let showLabel = rect.width > 60 && rect.height > 30
        let color = tileColor(category: node.category)

        Rectangle()
            .fill(color.opacity(isHovered ? 0.85 : 0.65))
            .overlay(
                Rectangle().stroke(Color.white.opacity(0.4), lineWidth: 0.5)
            )
            .overlay(alignment: .topLeading) {
                if showLabel {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(node.name)
                            .font(.system(size: min(13, max(9, rect.width / 14)), weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(node.size.formattedBytes)
                            .font(.system(size: 10, design: .monospaced))
                            .opacity(0.8)
                    }
                    .padding(4)
                    .foregroundStyle(.white)
                }
            }
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .onHover(perform: onHover)
            .help("\(node.name) · \(node.size.formattedBytes)")
            .accessibilityElement()
            .accessibilityLabel(node.name)
            .accessibilityValue(node.size.formattedBytes)
            .opacity(area < 4 ? 0 : 1)
    }

    private func tileColor(category: FileCategory) -> Color {
        switch category {
        case .directory: return .blue
        case .document:  return .indigo
        case .media:     return .purple
        case .code:      return .teal
        case .archive:   return .brown
        case .app:       return .orange
        case .other:     return .gray
        }
    }
}
