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
            header
            Divider()
            ScrollView {
                VStack(spacing: 20) {
                    hero
                    if phase == .ready, let report {
                        resultsList(report: report)
                        bottomActions(report: report)
                    } else if phase == .idle {
                        startCard
                    }
                }
                .padding(20)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Smart Care").font(.title2.weight(.semibold))
                Text("Run all five core scans in parallel").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if phase == .ready {
                Button {
                    runScan()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var hero: some View {
        VStack(spacing: 12) {
            switch phase {
            case .idle:
                Image(systemName: "sparkles")
                    .font(.system(size: 64))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                Text("Ready when you are")
                    .font(.title.weight(.semibold))
                Text("Smart Care inspects junk, trash, malware persistence, updates, and login items at once.")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            case .scanning:
                ProgressView().controlSize(.large)
                Text("Running all scans…").font(.title3).foregroundStyle(.secondary)
            case .ready:
                if let report {
                    if report.hasDanger {
                        Image(systemName: "exclamationmark.shield.fill").font(.system(size: 56)).foregroundStyle(.red)
                        Text("Issues need review").font(.title.weight(.semibold))
                    } else if report.totalCleanableBytes > 0 {
                        Image(systemName: "leaf").font(.system(size: 56)).foregroundStyle(.green)
                        Text("\(report.totalCleanableBytes.formattedBytes) cleanable")
                            .font(.system(size: 32, weight: .semibold, design: .monospaced))
                    } else {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 56)).foregroundStyle(.green)
                        Text("Your Mac is clean").font(.title.weight(.semibold))
                    }
                    Text(report.scannedAt.formatted(date: .abbreviated, time: .standard))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let cleanedMessage {
                Text(cleanedMessage).font(.callout).foregroundStyle(.green).padding(.top, 4)
            }
            if let lastError {
                Text(lastError).font(.caption).foregroundStyle(.red).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var startCard: some View {
        VStack(spacing: 12) {
            Button {
                runScan()
            } label: {
                Label("Start Scan", systemImage: "magnifyingglass")
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func resultsList(report: SmartCareReport) -> some View {
        VStack(spacing: 8) {
            ForEach(report.entries) { entry in
                resultRow(entry)
            }
        }
    }

    private func resultRow(_ entry: SmartCareReport.Entry) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(severityColor(entry.severity).opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: entry.symbol).foregroundStyle(severityColor(entry.severity))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.title).font(.system(size: 14, weight: .medium))
                    severityBadge(entry.severity)
                }
                Text(entry.summary).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let bytes = entry.totalBytes, bytes > 0 {
                Text(bytes.formattedBytes).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
            } else if entry.count > 0 {
                Text("\(entry.count)").font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
            }
            Button("Review") { onNavigate(entry.module) }
                .controlSize(.small)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func bottomActions(report: SmartCareReport) -> some View {
        HStack {
            Button {
                cleanSafe()
            } label: {
                if cleaningSafe { ProgressView().controlSize(.small) }
                Text("Clean All Safe Items")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(cleaningSafe)

            Button("Review Each") { onNavigate(.systemJunk) }
                .controlSize(.large)

            Spacer()
            Text("Safe items are deleted directly. Review items move to a 7-day quarantine.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private func severityBadge(_ s: SmartCareReport.Entry.Severity) -> some View {
        Text(s == .ok ? "OK" : (s == .review ? "REVIEW" : "DANGER"))
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(severityColor(s).opacity(0.18))
            .foregroundStyle(severityColor(s))
            .clipShape(Capsule())
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
        Task { @MainActor in
            phase = .scanning
            cleanedMessage = nil
            lastError = nil
            report = await container.smartCareOrchestrator.run()
            phase = .ready
        }
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
            // Refresh report
            report = await container.smartCareOrchestrator.run()
        }
    }
}
