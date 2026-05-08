import SwiftUI
import AppKit

@MainActor
struct QuarantineView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var sessions: [QuarantineService.SessionInfo] = []
    @State private var selectedSessionID: String?
    @State private var phase: Phase = .loading
    @State private var lastMessage: String?
    @State private var showEmptyAllConfirm = false
    @StateObject private var progress = CleanProgressTracker()

    enum Phase { case loading, ready }

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeader(
                icon: "archivebox",
                title: "Quarantine",
                subtitle: "Items moved here are kept for \(QuarantineService.retentionDays) days, then auto-purged",
                accent: .pink
            ) {
                Button {
                    Task { await reload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Button(role: .destructive) {
                    showEmptyAllConfirm = true
                } label: {
                    Label("Empty All", systemImage: "trash")
                }
                .disabled(sessions.isEmpty)
            }

            if phase == .loading {
                loadingView
            } else if sessions.isEmpty {
                emptyView
            } else {
                HSplitView {
                    sessionList
                        .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
                    detailView
                        .frame(minWidth: 360)
                }
            }

            if let lastMessage {
                Divider()
                Label(lastMessage, systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
                    .padding(8)
            }
            CleanProgressFooter(tracker: progress, tint: .pink)
        }
        .task { await reload() }
        .alert("Empty quarantine?", isPresented: $showEmptyAllConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                Task { await emptyAll() }
            }
        } message: {
            Text("This permanently deletes \(sessions.count) session\(sessions.count == 1 ? "" : "s") (\(totalBytes.formattedBytes)). Restore will no longer be possible.")
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView().controlSize(.large)
            Text("Reading quarantine…").foregroundStyle(.secondary).padding(.top, 6)
            Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: "archivebox")
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.pink)
                .heroIconBackdrop(color: .pink)
            Text("Quarantine is empty")
                .font(.titleMedium)
            Text("Items removed by the cleaners or uninstaller will appear here for the next \(QuarantineService.retentionDays) days, so you can restore them if needed.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            Spacer()
        }
    }

    private var sessionList: some View {
        List(selection: $selectedSessionID) {
            ForEach(sessions, id: \.id) { session in
                sessionRow(session).tag(session.id)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func sessionRow(_ session: QuarantineService.SessionInfo) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(session.totalBytes.formattedBytes)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("\(session.entries.count) item\(session.entries.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                retentionBadge(session.daysRemaining)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func retentionBadge(_ days: Int) -> some View {
        let color: Color = days <= 1 ? .red : (days <= 3 ? .orange : .secondary)
        Text("\(days)d left")
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var detailView: some View {
        if let id = selectedSessionID, let session = sessions.first(where: { $0.id == id }) {
            sessionDetail(session)
        } else {
            VStack {
                Spacer()
                Text("Select a session to view items")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private func sessionDetail(_ session: QuarantineService.SessionInfo) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.createdAt.formatted(date: .complete, time: .standard))
                        .font(.system(size: 13, weight: .semibold))
                    if let origin = session.origin {
                        Text("Origin: \(origin)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                }
                Spacer()
                Button {
                    NSWorkspace.shared.open(session.url)
                } label: {
                    Label("Reveal Folder", systemImage: "folder")
                }
                .controlSize(.small)
                Button(role: .destructive) {
                    Task { await deleteSession(session) }
                } label: {
                    Label("Delete Session", systemImage: "trash")
                }
                .controlSize(.small)
            }
            .padding(12)
            Divider()
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(session.entries, id: \.self) { entry in
                        entryRow(session: session, entry: entry)
                    }
                }
                .padding(12)
            }
        }
    }

    private func entryRow(session: QuarantineService.SessionInfo, entry: QuarantineService.Manifest.Entry) -> some View {
        let canRestore = !entry.from.isEmpty
        return HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.pink.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: entry.to.hasSuffix(".app") ? "app.dashed" : "doc")
                    .font(.system(size: 14))
                    .foregroundStyle(.pink)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.to)
                    .font(.system(size: 12, weight: .semibold))
                if !entry.from.isEmpty {
                    Text(entry.from)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                    if entry.to.hasSuffix(".app") {
                        Text("Inferred from filename — will fail safely if path is wrong")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text("Origin unknown (legacy item — restore manually via Reveal Folder)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text(entry.size.formattedBytes)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
            Button {
                Task { await restore(sessionID: session.id, entry: entry) }
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .controlSize(.small)
            .disabled(!canRestore)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pink.opacity(0.18), lineWidth: 0.5))
        )
    }

    // MARK: - Actions

    private var totalBytes: Int64 {
        sessions.reduce(0) { $0 + $1.totalBytes }
    }

    private func reload() async {
        phase = .loading
        let list = await container.quarantine.listSessions()
        sessions = list
        if let sel = selectedSessionID, !list.contains(where: { $0.id == sel }) {
            selectedSessionID = nil
        }
        if selectedSessionID == nil {
            selectedSessionID = list.first?.id
        }
        phase = .ready
    }

    private func restore(sessionID: String, entry: QuarantineService.Manifest.Entry) async {
        let result = await container.quarantine.restore(sessionID: sessionID, entry: entry)
        switch result {
        case .success(let url):
            lastMessage = "Restored to \(url.path)"
            await reload()
            if let session = sessions.first(where: { $0.id == sessionID }), session.entries.isEmpty {
                _ = await container.quarantine.deleteSession(sessionID)
                await reload()
            }
        case .failure(let err):
            lastMessage = "Restore failed: \(err.localizedDescription)"
        }
    }

    private func deleteSession(_ session: QuarantineService.SessionInfo) async {
        if await container.quarantine.deleteSession(session.id) {
            lastMessage = "Deleted session \(session.id) (\(session.totalBytes.formattedBytes))"
            await reload()
        } else {
            lastMessage = "Failed to delete session"
        }
    }

    private func emptyAll() async {
        progress.start(total: sessions.count)
        let count = await container.quarantine.deleteAllSessions(onProgress: progress.makeHandler())
        progress.finish()
        lastMessage = "Emptied quarantine (\(count) session\(count == 1 ? "" : "s") removed)"
        await reload()
    }
}
