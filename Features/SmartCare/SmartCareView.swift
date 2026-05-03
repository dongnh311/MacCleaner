import SwiftUI
import AppKit

struct SmartCareView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var selectedFolder: URL?
    @State private var isScanning = false
    @State private var totalBytes: Int64 = 0
    @State private var elapsed: TimeInterval = 0
    @State private var lastError: String?
    @State private var scanTask: Task<Void, Never>?
    @State private var recentScans: [ScanHistoryRow] = []

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 24) {
                    heroSection
                        .padding(.top, 32)
                    actionRow
                    if let lastError {
                        errorBanner(lastError)
                    }
                    if !recentScans.isEmpty {
                        recentScansSection
                    }
                }
                .padding(24)
            }
        }
        .task { await loadRecent() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Smart Care")
                    .font(.title2.weight(.semibold))
                Text("Pick any folder — MacCleaner will measure its real size")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroSection: some View {
        if let folder = selectedFolder {
            VStack(spacing: 12) {
                Text(folder.path)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)

                if isScanning {
                    ProgressView()
                        .controlSize(.large)
                        .padding(.vertical, 8)
                    Text("Scanning…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text(totalBytes.formattedBytes)
                        .font(.system(size: 40, weight: .semibold, design: .monospaced))
                        .foregroundStyle(totalBytes == 0 ? .secondary : .primary)
                    if elapsed > 0 {
                        Text("Done in \(String(format: "%.2f", elapsed))s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 56))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                Text("Pick a folder to scan")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                pickFolder()
            } label: {
                Label("Pick Folder…", systemImage: "folder")
            }
            .controlSize(.large)
            .disabled(isScanning)
            .keyboardShortcut("o")

            if isScanning {
                Button("Cancel", role: .destructive, action: cancelScan)
                    .controlSize(.large)
            } else if selectedFolder != nil {
                Button {
                    scan()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .controlSize(.large)
                .keyboardShortcut("r")
            }

            Spacer()
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var recentScansSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENT SCANS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(recentScans, id: \.id) { row in
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.sourcePath ?? "—")
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(row.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(row.bytesTotal.formattedBytes)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    if row.id != recentScans.last?.id {
                        Divider()
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Actions

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        panel.message = "Choose a folder to measure"
        if panel.runModal() == .OK, let url = panel.url {
            selectedFolder = url
            scan()
        }
    }

    private func scan() {
        guard let folder = selectedFolder else { return }
        cancelScan()
        isScanning = true
        totalBytes = 0
        elapsed = 0
        lastError = nil
        let startedAt = Date()
        let calculator = container.sizeCalculator
        let database = container.db

        scanTask = Task { @MainActor in
            Log.scanner.info("scan started: \(folder.path, privacy: .public)")
            let total = await calculator.recursiveSize(at: folder)
            let finishedAt = Date()
            guard !Task.isCancelled else {
                self.isScanning = false
                return
            }
            self.totalBytes = total
            self.elapsed = finishedAt.timeIntervalSince(startedAt)
            self.isScanning = false
            Log.scanner.info("scan finished: \(total) bytes in \(self.elapsed, format: .fixed(precision: 2))s")

            do {
                try await database.recordScan(
                    module: "SmartCare.demo",
                    startedAt: startedAt,
                    finishedAt: finishedAt,
                    bytesTotal: total,
                    sourcePath: folder.path
                )
                await loadRecent()
            } catch {
                Log.db.error("recordScan failed: \(error.localizedDescription, privacy: .public)")
                self.lastError = "Saved scan to history failed: \(error.localizedDescription)"
            }
        }
    }

    private func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        if isScanning { isScanning = false }
    }

    private func loadRecent() async {
        do {
            recentScans = try await container.db.recentScans(module: "SmartCare.demo", limit: 5)
        } catch {
            Log.db.error("loadRecent failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
