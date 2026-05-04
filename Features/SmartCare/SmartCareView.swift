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
            topBar
            ZStack {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                runFloatingButton
            }
        }
        .background(SmartCareBackdrop().ignoresSafeArea())
        .animation(.smooth(duration: 0.25), value: phase)
        .animation(.smooth(duration: 0.25), value: cleaningSafe)
        .task(id: container.smartCareAutoRunToken) {
            guard container.smartCareAutoRunToken != nil, phase != .scanning else { return }
            container.smartCareAutoRunToken = nil
            await runScanAsync()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            if phase == .ready {
                Button {
                    runScan()
                } label: {
                    Label("Start Over", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .keyboardShortcut("r")
            }
            Spacer()
            Text("Smart Scan")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if phase == .ready, let report {
                Text(report.scannedAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:    idleContent
        case .scanning: scanningContent
        case .ready:   readyContent
        }
    }

    private var idleContent: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .heroIconBackdrop(color: .accentColor)
            Text("Run Smart Care to scan your Mac")
                .font(.system(size: 22, weight: .semibold))
            Text("Inspects junk, trash, malware persistence, updates and login items in parallel.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            Spacer()
        }
    }

    private var scanningContent: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            ProgressView().controlSize(.large)
            Text("Running all scans…")
                .font(.titleMedium).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var readyContent: some View {
        guard let report else { return AnyView(EmptyView()) }
        return AnyView(
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    headline(report)
                    pillars(report)
                    if let cleanedMessage {
                        Label(cleanedMessage, systemImage: "checkmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.green)
                    }
                    if let lastError {
                        Label(lastError, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Color.clear.frame(height: 80) // breathing room above floating Run button
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.xl)
            }
        )
    }

    private func headline(_ report: SmartCareReport) -> some View {
        VStack(spacing: 6) {
            Text(headlineText(for: report))
                .font(.system(size: 26, weight: .semibold))
                .multilineTextAlignment(.center)
            Text("All of the tasks to keep your Mac clean, safe, and optimised are waiting. Run them all at once!")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 540)
        }
    }

    private func headlineText(for report: SmartCareReport) -> String {
        if report.hasDanger { return "Some items need your attention." }
        if report.totalCleanableBytes > 0 || report.totalIssueCount > 0 {
            return "Alright, here's what I've found."
        }
        return "Your Mac is in great shape."
    }

    // MARK: - Pillars

    private func pillars(_ report: SmartCareReport) -> some View {
        let cleanup = pillar(for: .cleanup, report: report)
        let protection = pillar(for: .protection, report: report)
        let speed = pillar(for: .speed, report: report)

        return HStack(alignment: .top, spacing: Spacing.lg) {
            PillarCard(model: cleanup) { onNavigate(.systemJunk) }
            PillarCard(model: protection) { onNavigate(.malware) }
            PillarCard(model: speed) { onNavigate(.loginItems) }
        }
    }

    private func pillar(for kind: PillarKind, report: SmartCareReport) -> PillarModel {
        switch kind {
        case .cleanup:
            let junk = report.entries.first(where: { $0.id == "system_junk" })
            let trash = report.entries.first(where: { $0.id == "trash" })
            let total = (junk?.totalBytes ?? 0) + (trash?.totalBytes ?? 0)
            return PillarModel(
                kind: .cleanup,
                gradient: [Color.blue.opacity(0.85), Color.cyan.opacity(0.7)],
                icon: "internaldrive.fill",
                title: "Cleanup",
                subtitle: "Removes unneeded junk",
                primaryValue: total > 0 ? total.formattedBytes : "0 KB",
                primaryColor: total > 0 ? Color.cyan : Color.green,
                showsCheckmark: total == 0,
                hasIssue: total > 0,
                detailsLabel: total > 0 ? "Review Details…" : nil
            )
        case .protection:
            let mal = report.entries.first(where: { $0.id == "malware" })
            let danger = mal?.severity == .danger
            let warn = mal?.severity == .review
            let value = danger ? "Issues" : (warn ? "Review" : "OK")
            let color: Color = danger ? .red : (warn ? .orange : .green)
            return PillarModel(
                kind: .protection,
                gradient: [Color.green.opacity(0.85), Color.mint.opacity(0.7)],
                icon: "shield.lefthalf.filled",
                title: "Protection",
                subtitle: "Neutralises potential threats",
                primaryValue: value,
                primaryColor: color,
                showsCheckmark: !danger && !warn,
                hasIssue: danger || warn,
                detailsLabel: (danger || warn) ? "Review Details…" : nil
            )
        case .speed:
            let updates = report.entries.first(where: { $0.id == "updates" })?.count ?? 0
            let perf = report.entries.first(where: { $0.id == "performance" })?.count ?? 0
            let total = updates + perf
            return PillarModel(
                kind: .speed,
                gradient: [Color.pink.opacity(0.85), Color.orange.opacity(0.7)],
                icon: "speedometer",
                title: "Speed",
                subtitle: "Increases system performance",
                primaryValue: total > 0 ? "\(total)" : "0",
                primaryColor: total > 0 ? Color.pink : Color.green,
                primarySuffix: total > 0 ? "tasks to run" : nil,
                showsCheckmark: total == 0,
                hasIssue: total > 0,
                detailsLabel: total > 0 ? "Review Details…" : nil
            )
        }
    }

    // MARK: - Floating run button

    @ViewBuilder
    private var runFloatingButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    if phase == .ready { cleanSafe() } else { runScan() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [.cyan.opacity(0.85), .blue.opacity(0.85)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 76, height: 76)
                            .shadow(color: .blue.opacity(0.4), radius: 16, y: 4)
                        Circle()
                            .stroke(Color.white.opacity(0.55), lineWidth: 1.2)
                            .frame(width: 76, height: 76)
                        if cleaningSafe || phase == .scanning {
                            ProgressView().controlSize(.large).tint(.white)
                        } else {
                            Text(phase == .ready ? "Run" : "Scan")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(phase == .scanning || cleaningSafe)
                .keyboardShortcut(.defaultAction)
                Spacer()
            }
            .padding(.bottom, Spacing.lg)
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
        let startedAt = Date()
        let r = await container.smartCareOrchestrator.run()
        report = r
        phase = .ready
        try? await container.db.recordScan(
            module: "SmartCare",
            startedAt: startedAt,
            finishedAt: Date(),
            itemsScanned: r.totalIssueCount,
            bytesTotal: r.totalCleanableBytes,
            sourcePath: nil,
            status: "scanned"
        )
    }

    private func cleanSafe() {
        cleaningSafe = true
        cleanedMessage = nil
        Task { @MainActor in
            let result = await container.smartCareOrchestrator.cleanAllSafeItems()
            cleaningSafe = false
            if result.removed.isEmpty {
                cleanedMessage = "Nothing safe to clean — review each pillar manually"
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

// MARK: - Pillar card

fileprivate enum PillarKind { case cleanup, protection, speed }

private struct PillarModel {
    let kind: PillarKind
    let gradient: [Color]
    let icon: String
    let title: String
    let subtitle: String
    let primaryValue: String
    let primaryColor: Color
    var primarySuffix: String? = nil
    let showsCheckmark: Bool
    let hasIssue: Bool
    let detailsLabel: String?
}

private struct PillarCard: View {
    let model: PillarModel
    let onReview: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            artwork
            HStack(spacing: 4) {
                if model.showsCheckmark {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.cyan)
                        .font(.system(size: 14))
                } else if model.hasIssue {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 14))
                }
                Text(model.title)
                    .font(.system(size: 16, weight: .semibold))
            }
            Text(model.subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(model.primaryValue)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(model.primaryColor)
                .contentTransition(.numericText())
            if let suffix = model.primarySuffix {
                Text(suffix)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let label = model.detailsLabel {
                Button(action: onReview) {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(height: 22)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }

    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(
                    colors: model.gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 110, height: 110)
                .shadow(color: model.gradient.last!.opacity(0.35), radius: 12, y: 6)
            Image(systemName: model.icon)
                .font(.system(size: 50, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
    }
}

// MARK: - Backdrop

private struct SmartCareBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.20, green: 0.18, blue: 0.32), Color(red: 0.12, green: 0.10, blue: 0.20)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [Color.purple.opacity(0.25), Color.clear],
                center: .top, startRadius: 0, endRadius: 600
            )
        }
    }
}
