import SwiftUI

@MainActor
struct SmartCareView: View {

    @EnvironmentObject private var container: AppContainer

    let onNavigate: (SidebarItem) -> Void

    @State private var report: SmartCareReport?
    @State private var phase: Phase = .idle
    @State private var lastError: String?
    @State private var cleaningSafe = false
    @State private var cleanedMessage: String?

    enum Phase: Equatable { case idle, scanning, ready }

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeader(
                icon: "sparkles",
                title: "Smart Care",
                subtitle: "Run all five core scans at once"
            ) {
                if phase == .ready {
                    Button {
                        runScan()
                    } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r")
                }
            }
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    hero
                        .padding(.top, Spacing.xl)
                    if phase == .ready, let report {
                        resultsList(report: report)
                        bottomActions(report: report)
                    } else if phase == .idle {
                        startCard
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xl)
            }
        }
        .animation(.smooth(duration: 0.25), value: phase)
        .animation(.smooth(duration: 0.25), value: cleaningSafe)
        .task(id: container.smartCareAutoRunToken) {
            guard container.smartCareAutoRunToken != nil, phase != .scanning else { return }
            container.smartCareAutoRunToken = nil
            await runScanAsync()
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var hero: some View {
        switch phase {
        case .idle:
            idleHero
        case .scanning:
            scanningHero
        case .ready:
            if let report { readyHero(report: report) }
        }
    }

    private var idleHero: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .heroIconBackdrop(color: .accentColor)
            Text("Ready when you are")
                .font(.system(size: 22, weight: .semibold))
            Text("Smart Care inspects junk, trash, malware persistence, updates, and login items in parallel.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
    }

    private var scanningHero: some View {
        VStack(spacing: Spacing.md) {
            ProgressView().controlSize(.large)
            Text("Running all scans…")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func readyHero(report: SmartCareReport) -> some View {
        VStack(spacing: Spacing.sm) {
            if report.hasDanger {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.red)
                    .heroIconBackdrop(color: .red)
                Text("Issues need review")
                    .font(.system(size: 24, weight: .semibold))
            } else if report.totalCleanableBytes > 0 {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                    .heroIconBackdrop(color: .green)
                Text(report.totalCleanableBytes.formattedBytes)
                    .font(.system(size: 36, weight: .semibold, design: .monospaced))
                    .contentTransition(.numericText())
                Text("cleanable across all modules")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                    .heroIconBackdrop(color: .green)
                Text("Your Mac is clean")
                    .font(.system(size: 24, weight: .semibold))
            }
            Text("Last scan: \(report.scannedAt.formatted(date: .abbreviated, time: .standard))")
                .font(.caption).foregroundStyle(.secondary)
            if let cleanedMessage {
                Label(cleanedMessage, systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
                    .padding(.top, 4)
            }
            if let lastError {
                Label(lastError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            }
        }
    }

    private var startCard: some View {
        VStack(spacing: Spacing.lg) {
            Button {
                runScan()
            } label: {
                Label("Start Scan", systemImage: "magnifyingglass")
                    .frame(maxWidth: 220)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Results

    private func resultsList(report: SmartCareReport) -> some View {
        VStack(spacing: Spacing.sm) {
            ForEach(report.entries) { entry in
                resultRow(entry)
            }
        }
    }

    private func resultRow(_ entry: SmartCareReport.Entry) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle().fill(severityColor(entry.severity).opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: entry.symbol)
                    .font(.system(size: 17))
                    .foregroundStyle(severityColor(entry.severity))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.title).font(.system(size: 14, weight: .semibold))
                    StatusBadge(text: severityLabel(entry.severity), color: severityColor(entry.severity))
                }
                Text(entry.summary).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let bytes = entry.totalBytes, bytes > 0 {
                Text(bytes.formattedBytes)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            } else if entry.count > 0 {
                Text("\(entry.count)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Button {
                onNavigate(entry.module)
            } label: {
                HStack(spacing: 3) {
                    Text("Review")
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                }
            }
            .controlSize(.small)
        }
        .padding(Spacing.md)
        .cardStyle()
    }

    private func bottomActions(report: SmartCareReport) -> some View {
        HStack(spacing: Spacing.md) {
            Button {
                cleanSafe()
            } label: {
                HStack(spacing: 6) {
                    if cleaningSafe { ProgressView().controlSize(.small) }
                    Label("Clean All Safe Items", systemImage: "leaf")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(cleaningSafe)

            Button {
                onNavigate(.systemJunk)
            } label: {
                Label("Review Each", systemImage: "list.bullet.rectangle")
            }
            .controlSize(.large)

            Spacer()

            Text("Safe items deleted directly. Review items move to a 7-day quarantine.")
                .font(.caption2).foregroundStyle(.secondary)
                .frame(maxWidth: 280, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
        .padding(.top, Spacing.sm)
    }

    private func severityLabel(_ s: SmartCareReport.Entry.Severity) -> String {
        switch s {
        case .ok: return "OK"
        case .review: return "REVIEW"
        case .danger: return "DANGER"
        }
    }

    private func severityColor(_ s: SmartCareReport.Entry.Severity) -> Color {
        switch s {
        case .ok:     return .green
        case .review: return .orange
        case .danger: return .red
        }
    }

    // MARK: - Actions

    private func runScan() {
        Task { @MainActor in await runScanAsync() }
    }

    private func runScanAsync() async {
        phase = .scanning
        cleanedMessage = nil
        lastError = nil
        report = await container.smartCareOrchestrator.run()
        phase = .ready
    }

    private func cleanSafe() {
        cleaningSafe = true
        cleanedMessage = nil
        Task { @MainActor in
            let result = await container.smartCareOrchestrator.cleanAllSafeItems()
            cleaningSafe = false
            if result.removed.isEmpty {
                cleanedMessage = "Nothing safe to clean"
            } else {
                cleanedMessage = "Freed \(result.totalBytesFreed.formattedBytes) (\(result.removed.count) items)"
            }
            try? await container.db.recordScan(
                module: "SmartCare.cleanSafe",
                startedAt: Date().addingTimeInterval(-1),
                finishedAt: Date(),
                itemsScanned: result.removed.count,
                bytesTotal: result.totalBytesFreed,
                sourcePath: nil,
                status: result.failed.isEmpty ? "completed" : "partial"
            )
            report = await container.smartCareOrchestrator.run()
        }
    }
}
