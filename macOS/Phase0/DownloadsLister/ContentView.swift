import SwiftUI
import AppKit

// `@MainActor` guarantees all members run on the main thread.
// SwiftUI views are already implicitly main-actor on macOS 14+, but being
// explicit makes the rule visible — useful while learning.
@MainActor
struct ContentView: View {
    // `@State` = mutable view-owned storage. Closer to `mutableStateOf` in Compose
    // than to ViewModel state. SwiftUI re-renders when these change.
    @State private var entries: [FileEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var sortOrder: [KeyPathComparator<FileEntry>] = [
        .init(\.size, order: .reverse)
    ]
    @State private var selection = Set<FileEntry.ID>()

    private let scanner = FileScanner()
    private let downloadsURL = FileManager.default
        .urls(for: .downloadsDirectory, in: .userDomainMask).first!

    private var sortedEntries: [FileEntry] {
        entries.sorted(using: sortOrder)
    }

    private var totalSize: Int64 {
        entries.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let errorMessage {
                errorBanner(errorMessage)
            }
            table
            Divider()
            footer
        }
        .task { await scan() }   // runs once when view appears, cancelled on disappear
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Image(systemName: "folder")
                .foregroundStyle(.tint)
            Text(downloadsURL.path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if isLoading {
                ProgressView().controlSize(.small)
            }
            Button("Refresh") {
                Task { await scan() }   // `Task { ... }` is "fire-and-forget" coroutine launch
            }
            .disabled(isLoading)
            .keyboardShortcut("r")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.1))
    }

    private var table: some View {
        Table(sortedEntries, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { entry in
                Label {
                    Text(entry.name).lineLimit(1)
                } icon: {
                    Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                        .foregroundStyle(entry.isDirectory ? .blue : .secondary)
                }
            }
            TableColumn("Size", value: \.size) { entry in
                Text(entry.formattedSize)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .foregroundStyle(entry.size == 0 ? .secondary : .primary)
            }
            .width(min: 80, ideal: 100)
            TableColumn("Modified", value: \.modified) { entry in
                Text(entry.modified.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            .width(min: 140, ideal: 160)
        }
        .contextMenu(forSelectionType: FileEntry.ID.self) { ids in
            Button("Reveal in Finder") { reveal(ids) }
                .disabled(ids.isEmpty)
        } primaryAction: { ids in
            reveal(ids)
        }
    }

    private var footer: some View {
        HStack {
            Text("\(entries.count) item\(entries.count == 1 ? "" : "s")")
            Spacer()
            Text("Total: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                .font(.system(.body, design: .monospaced))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Actions

    private func scan() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }   // runs no matter how this scope exits — like Kotlin's `finally`
        do {
            // Crossing actor boundary requires `await`. `entries` mutation back
            // here is fine because the function is @MainActor.
            entries = try await scanner.listDirectory(downloadsURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reveal(_ ids: Set<FileEntry.ID>) {
        let urls = Array(ids)
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
}

#Preview {
    ContentView()
        .frame(width: 800, height: 500)
}
