import SwiftUI

@MainActor
struct CleanupModuleView<S: CleanupScanner>: View {

    let scanner: S
    let title: String
    let subtitle: String
    let symbol: String

    @EnvironmentObject private var container: AppContainer

    @State private var items: [CleanableItem] = []
    @State private var selectedIDs = Set<UUID>()
    @State private var phase: Phase = .idle
    @State private var lastError: String?
    @State private var lastResultMessage: String?
    @State private var filter: ItemCategory?
    @State private var sortOrder: SortField = .sizeDesc
    @State private var pendingConfirm: PendingConfirm?
    @State private var scanStartedAt: Date?

    enum Phase: Equatable { case idle, scanning, cleaning, scanned }

    enum SortField: String, CaseIterable, Identifiable {
        case sizeDesc, sizeAsc, modifiedDesc, modifiedAsc, name
        var id: String { rawValue }
        var label: String {
            switch self {
            case .sizeDesc:     return "Size ↓"
            case .sizeAsc:      return "Size ↑"
            case .modifiedDesc: return "Modified ↓"
            case .modifiedAsc:  return "Modified ↑"
            case .name:         return "Name"
            }
        }
    }

    struct PendingConfirm: Equatable {
        let items: [CleanableItem]
        var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    }

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeader(
                icon: symbol,
                title: title,
                subtitle: subtitle
            ) {
                if phase == .scanned && !items.isEmpty {
                    Button {
                        scan()
                    } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r")
                }
            }
            content
        }
        .animation(.smooth(duration: 0.2), value: phase)
        .task { restoreFromCacheIfAvailable() }
    }

    private func restoreFromCacheIfAvailable() {
        // Already have results in this view's state — keep them.
        guard items.isEmpty, phase == .idle else { return }
        guard let cached = container.cleanupResultsCache.get(scannerID: scanner.id) else { return }
        items = cached.items
        scanStartedAt = cached.scannedAt
        phase = .scanned
        let elapsed = Int(Date().timeIntervalSince(cached.scannedAt))
        lastResultMessage = "Restored \(cached.items.count) items from previous scan (\(elapsed)s ago)"
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            idleState
        case .scanning:
            scanningState
        case .scanned, .cleaning:
            scannedState
        }
    }

    private var idleState: some View {
        EmptyStateView(
            icon: symbol,
            title: "Ready to scan \(title)",
            message: lastError ?? "Press Start Scan to look for items that match the rule set."
        ) {
            Button {
                scan()
            } label: {
                Label("Start Scan", systemImage: "magnifyingglass")
                    .frame(minWidth: 160)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var scanningState: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView().controlSize(.large)
            Text("Scanning…")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Cancel", action: cancelScan)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scannedState: some View {
        VStack(spacing: 0) {
            heroZone
            Divider()
            if !items.isEmpty {
                toolbar
                Divider()
                resultList
                Divider()
            } else {
                emptyResults
            }
            if let pendingConfirm {
                confirmBar(pendingConfirm)
                Divider()
            }
            actionBar
        }
    }

    private var heroZone: some View {
        VStack(spacing: 8) {
            if items.isEmpty && phase == .scanned {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                Text("Nothing to clean")
                    .font(.title2.weight(.semibold))
            } else {
                Text(totalScannedSize.formattedBytes)
                    .font(.system(size: 40, weight: .semibold, design: .monospaced))
                Text("\(items.count) item\(items.count == 1 ? "" : "s") found")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let lastResultMessage {
                Text(lastResultMessage)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.top, 4)
            }
            if let lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterPill(label: "All", count: items.count, isSelected: filter == nil) {
                        filter = nil
                    }
                    ForEach(availableCategories, id: \.0) { (cat, count) in
                        FilterPill(label: cat.displayName, count: count, isSelected: filter == cat) {
                            filter = cat
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            Picker("", selection: $sortOrder) {
                ForEach(SortField.allCases) { field in
                    Text(field.label).tag(field)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 140)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var resultList: some View {
        List {
            ForEach(filteredSortedItems) { item in
                CleanupItemRow(
                    item: item,
                    isOn: Binding(
                        get: { selectedIDs.contains(item.id) },
                        set: { newValue in
                            if newValue { selectedIDs.insert(item.id) }
                            else { selectedIDs.remove(item.id) }
                        }
                    )
                ) {
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private var emptyResults: some View {
        VStack {
            Spacer()
            Text("No items match this filter")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func confirmBar(_ confirm: PendingConfirm) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Delete \(confirm.items.count) item\(confirm.items.count == 1 ? "" : "s") (\(confirm.totalSize.formattedBytes))?")
                    .font(.callout.weight(.medium))
                Text("Cache items are removed directly. Other items move to a 7-day quarantine.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel") { pendingConfirm = nil }
                .keyboardShortcut(.cancelAction)
            Button("Delete", role: .destructive) {
                performClean(confirm.items)
                pendingConfirm = nil
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            Text("\(selectedIDs.count) of \(items.count) selected • \(selectedSize.formattedBytes)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Select All") {
                selectedIDs = Set(filteredSortedItems.map { $0.id })
            }
            .disabled(items.isEmpty || phase == .cleaning)
            .keyboardShortcut("a")

            Button("Deselect All") { selectedIDs.removeAll() }
                .disabled(selectedIDs.isEmpty)
                .keyboardShortcut("d")

            if phase == .cleaning {
                ProgressView().controlSize(.small)
            }

            Button {
                requestClean()
            } label: {
                Text("Clean \(selectedSize.formattedBytes)")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedIDs.isEmpty || phase == .cleaning)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    // MARK: - Derived state

    private var totalScannedSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    private var selectedSize: Int64 {
        items.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    private var filteredSortedItems: [CleanableItem] {
        let filtered: [CleanableItem]
        if let filter {
            filtered = items.filter { $0.category == filter }
        } else {
            filtered = items
        }
        switch sortOrder {
        case .sizeDesc:     return filtered.sorted { $0.size > $1.size }
        case .sizeAsc:      return filtered.sorted { $0.size < $1.size }
        case .modifiedDesc: return filtered.sorted { ($0.lastModified ?? .distantPast) > ($1.lastModified ?? .distantPast) }
        case .modifiedAsc:  return filtered.sorted { ($0.lastModified ?? .distantPast) < ($1.lastModified ?? .distantPast) }
        case .name:         return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    private var availableCategories: [(ItemCategory, Int)] {
        var counts: [ItemCategory: Int] = [:]
        for item in items {
            counts[item.category, default: 0] += 1
        }
        return ItemCategory.allCases.compactMap { cat in
            counts[cat].map { (cat, $0) }
        }
    }

    // MARK: - Actions

    private func scan() {
        Task { @MainActor in
            phase = .scanning
            items = []
            selectedIDs = []
            lastError = nil
            lastResultMessage = nil
            scanStartedAt = Date()
            do {
                let result = try await scanner.scan()
                items = result
                phase = .scanned
                container.cleanupResultsCache.set(scannerID: scanner.id, items: result)
                Log.scanner.info("\(scanner.id, privacy: .public) scan: \(result.count) items, \(totalScannedSize) bytes")
            } catch {
                lastError = error.localizedDescription
                phase = .idle
                Log.scanner.error("\(scanner.id, privacy: .public) scan failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func cancelScan() {
        phase = .idle
    }

    private func requestClean() {
        let toClean = items.filter { selectedIDs.contains($0.id) }
        guard !toClean.isEmpty else { return }
        pendingConfirm = PendingConfirm(items: toClean)
    }

    private func performClean(_ toClean: [CleanableItem]) {
        Task { @MainActor in
            phase = .cleaning
            let startedAt = scanStartedAt ?? Date()
            let result = await scanner.clean(toClean)
            let removedIDs = Set(result.removed.map { $0.id })
            items.removeAll { removedIDs.contains($0.id) }
            selectedIDs.removeAll()
            phase = .scanned
            container.cleanupResultsCache.update(scannerID: scanner.id, items: items)
            lastResultMessage = "Freed \(result.totalBytesFreed.formattedBytes) (\(result.removed.count) item\(result.removed.count == 1 ? "" : "s"))"
            if !result.failed.isEmpty {
                lastError = "\(result.failed.count) item\(result.failed.count == 1 ? "" : "s") failed to clean"
            } else {
                lastError = nil
            }

            do {
                try await container.db.recordScan(
                    module: scanner.id,
                    startedAt: startedAt,
                    finishedAt: Date(),
                    itemsScanned: result.removed.count,
                    bytesTotal: result.totalBytesFreed,
                    sourcePath: nil,
                    status: result.failed.isEmpty ? "completed" : "partial"
                )
            } catch {
                Log.db.error("recordScan failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

// MARK: - Sub-components

struct FilterPill: View {
    let label: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label).font(.system(size: 11, weight: .medium))
                Text("\(count)")
                    .font(.system(size: 10, design: .monospaced))
                    .opacity(0.7)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct CleanupItemRow: View {
    let item: CleanableItem
    @Binding var isOn: Bool
    let onReveal: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: $isOn).labelsHidden()
            Image(systemName: item.isDirectory ? "folder.fill" : item.category.systemImage)
                .foregroundStyle(.tint)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 13))
                        .lineLimit(1)
                    SafetyBadge(level: item.safetyLevel)
                }
                Text(item.url.path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(item.size.formattedBytes)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Reveal in Finder", action: onReveal)
        }
    }
}

struct SafetyBadge: View {
    let level: SafetyLevel

    var body: some View {
        Text(level.displayName)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch level {
        case .safe:      return .green
        case .review:    return .orange
        case .dangerous: return .red
        }
    }
}
