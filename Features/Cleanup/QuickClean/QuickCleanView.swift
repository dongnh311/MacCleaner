import SwiftUI

@MainActor
struct QuickCleanView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var phase: Phase = .idle
    @State private var groups: [Group] = []
    @State private var selectedIDs: Set<Group.ID> = []
    @State private var scannedAt: Date?
    @State private var resultMessage: String?

    enum Phase: Equatable { case idle, scanning, ready, cleaning, done }

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeader(
                icon: "bolt.circle",
                title: "Quick Clean",
                subtitle: "Caches, logs and trash — safe to delete, will regenerate",
                accent: .orange
            ) {
                if phase == .ready || phase == .done {
                    Button {
                        runScan()
                    } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r")
                }
            }
            content
        }
        .animation(.smooth(duration: 0.25), value: phase)
        .task { if phase == .idle { runScan() } }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            EmptyStateView(
                icon: "bolt.circle",
                title: "Ready to clean",
                message: "Scans User Caches, System Caches, Logs, Xcode artifacts and Trash Bins.",
                tint: .orange
            ) {
                Button { runScan() } label: {
                    Label("Start Scan", systemImage: "magnifyingglass")
                        .frame(maxWidth: 220).padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        case .scanning:
            scanningView
        case .ready, .cleaning, .done:
            readyView
        }
    }

    private var scanningView: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            ProgressView().controlSize(.large)
            Text("Scanning safe-to-delete items…")
                .font(.titleMedium).foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var readyView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    hero
                        .padding(.top, Spacing.xl)
                    groupList
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.lg)
            }
            Divider()
            footer
        }
    }

    private var hero: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: phase == .done ? "checkmark.seal.fill" : "bolt.circle.fill")
                .font(.system(size: 48))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(phase == .done ? .green : .orange)
                .heroIconBackdrop(color: phase == .done ? .green : .orange)
            Text(selectedTotalBytes.formattedBytes)
                .font(.system(size: 32, weight: .semibold, design: .monospaced))
                .contentTransition(.numericText())
            Text(phase == .done ? "Cleaned successfully" : "selected to clean")
                .font(.callout).foregroundStyle(.secondary)
            if let message = resultMessage {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.callout).foregroundStyle(.green)
                    .padding(.top, 4)
            }
            if let scannedAt {
                Text("Last scan: \(scannedAt.formatted(date: .abbreviated, time: .standard))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var groupList: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(groups) { group in
                groupRow(group)
            }
        }
    }

    private func groupRow(_ group: Group) -> some View {
        let isSelected = selectedIDs.contains(group.id)
        return HStack(spacing: Spacing.md) {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { newValue in
                    if newValue { selectedIDs.insert(group.id) } else { selectedIDs.remove(group.id) }
                }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)
            .disabled(group.items.isEmpty || phase == .cleaning)

            ZStack {
                Circle().fill(Color.orange.opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: group.symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(group.title).font(.system(size: 14, weight: .semibold))
                Text(group.items.isEmpty ? "Nothing to clean" : "\(group.items.count) items")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Text(group.totalBytes.formattedBytes)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(group.items.isEmpty ? .tertiary : .secondary)
                .contentTransition(.numericText())
        }
        .padding(Spacing.md)
        .cardStyle()
        .opacity(group.items.isEmpty ? 0.55 : 1)
    }

    private var footer: some View {
        HStack(spacing: Spacing.md) {
            Button {
                if selectedIDs.count == groups.filter({ !$0.items.isEmpty }).count {
                    selectedIDs.removeAll()
                } else {
                    selectedIDs = Set(groups.filter { !$0.items.isEmpty }.map(\.id))
                }
            } label: {
                Text(selectedIDs.isEmpty ? "Select All" : "Deselect All")
            }
            .controlSize(.regular)
            .disabled(phase == .cleaning || groups.allSatisfy { $0.items.isEmpty })

            Spacer()

            if phase == .cleaning {
                ProgressView().controlSize(.small)
                Text("Cleaning…").foregroundStyle(.secondary).font(.callout)
            } else {
                Text("Caches and logs regenerate as apps run.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Button {
                cleanNow()
            } label: {
                Label("Clean Now — \(selectedTotalBytes.formattedBytes)", systemImage: "leaf.fill")
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(selectedIDs.isEmpty || selectedTotalBytes == 0 || phase == .cleaning)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.md)
        .background(.bar)
    }

    // MARK: - Computed

    private var selectedTotalBytes: Int64 {
        groups.filter { selectedIDs.contains($0.id) }
              .reduce(Int64(0)) { $0 + $1.totalBytes }
    }

    // MARK: - Actions

    private func runScan() {
        Task { @MainActor in
            phase = .scanning
            resultMessage = nil
            let junk = (try? await container.systemJunkScanner.scan()) ?? []
            let trash = (try? await container.trashBinScanner.scan()) ?? []
            let safeJunk = junk.filter { $0.safetyLevel == .safe }
            let assembled = Self.assemble(systemJunk: safeJunk, trash: trash)
            self.groups = assembled
            self.selectedIDs = Set(assembled.filter { !$0.items.isEmpty }.map(\.id))
            self.scannedAt = Date()
            self.phase = .ready
        }
    }

    private func cleanNow() {
        let selected = groups.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        let trashItems = selected.filter { $0.id == .trash }.flatMap(\.items)
        let junkItems = selected.filter { $0.id != .trash }.flatMap(\.items)

        Task { @MainActor in
            phase = .cleaning
            resultMessage = nil
            async let junkResult = container.systemJunkScanner.clean(junkItems)
            async let trashResult = container.trashBinScanner.clean(trashItems)
            let (jr, tr) = await (junkResult, trashResult)
            let freed = jr.totalBytesFreed + tr.totalBytesFreed
            let removed = jr.removed.count + tr.removed.count
            let failed = jr.failed.count + tr.failed.count

            try? await container.db.recordScan(
                module: "QuickClean",
                startedAt: scannedAt ?? Date().addingTimeInterval(-1),
                finishedAt: Date(),
                itemsScanned: removed + failed,
                bytesTotal: freed,
                sourcePath: nil,
                status: failed == 0 ? "completed" : "partial"
            )

            resultMessage = "Freed \(freed.formattedBytes) (\(removed) items)\(failed > 0 ? " — \(failed) failed" : "")"
            phase = .done

            // Auto-rescan to refresh sizes — but stay on the .done screen visually.
            let junk = (try? await container.systemJunkScanner.scan()) ?? []
            let trash = (try? await container.trashBinScanner.scan()) ?? []
            let safeJunk = junk.filter { $0.safetyLevel == .safe }
            let assembled = Self.assemble(systemJunk: safeJunk, trash: trash)
            self.groups = assembled
            self.selectedIDs = Set(assembled.filter { !$0.items.isEmpty }.map(\.id))
            self.scannedAt = Date()
        }
    }

    // MARK: - Grouping

    /// Buckets system-junk items by category and tacks Trash Bins onto the end.
    /// Categories not represented in Quick Clean's curated set (e.g. mail, photo)
    /// fall through to "Other Safe" so the totals still tally.
    private static func assemble(systemJunk: [CleanableItem], trash: [CleanableItem]) -> [Group] {
        var byID: [Group.ID: [CleanableItem]] = [:]
        for item in systemJunk {
            let id: Group.ID
            switch item.category {
            case .userCache:                  id = .userCache
            case .systemCache:                id = .systemCache
            case .userLog:                    id = .userLog
            case .systemLog:                  id = .systemLog
            case .xcodeJunk, .devToolCache:   id = .xcode
            default:                          id = .other
            }
            byID[id, default: []].append(item)
        }
        if !trash.isEmpty {
            byID[.trash, default: []].append(contentsOf: trash)
        }

        return Group.ID.allCases.map { gid in
            Group(id: gid, items: byID[gid] ?? [])
        }
    }
}

// MARK: - Group model

extension QuickCleanView {

    struct Group: Identifiable, Equatable {
        enum ID: String, CaseIterable, Hashable, Identifiable {
            case userCache, systemCache, userLog, systemLog, xcode, trash, other
            var id: String { rawValue }
        }

        let id: ID
        let items: [CleanableItem]

        var title: String {
            switch id {
            case .userCache:    return "User Cache Files"
            case .systemCache:  return "System Cache Files"
            case .userLog:      return "User Log Files"
            case .systemLog:    return "System Log Files"
            case .xcode:        return "Xcode & Dev Tool Junk"
            case .trash:        return "Trash Bins"
            case .other:        return "Other Safe Items"
            }
        }

        var symbol: String {
            switch id {
            case .userCache:    return "person.crop.circle"
            case .systemCache:  return "gearshape.2"
            case .userLog:      return "doc.text"
            case .systemLog:    return "doc.text.below.ecg"
            case .xcode:        return "hammer"
            case .trash:        return "trash"
            case .other:        return "tray"
            }
        }

        var totalBytes: Int64 {
            items.reduce(0) { $0 + $1.size }
        }
    }
}
