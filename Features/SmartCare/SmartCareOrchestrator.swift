import Foundation

struct SmartCareReport: Sendable {
    let entries: [Entry]
    let scannedAt: Date

    var totalCleanableBytes: Int64 {
        entries.reduce(0) { $0 + ($1.totalBytes ?? 0) }
    }
    var totalIssueCount: Int {
        entries.reduce(0) { $0 + $1.count }
    }
    var hasDanger: Bool {
        entries.contains { $0.severity == .danger }
    }

    struct Entry: Identifiable, Sendable {
        let id: String
        let module: SidebarItem
        let title: String
        let symbol: String
        let count: Int
        let totalBytes: Int64?
        let severity: Severity
        let summary: String

        enum Severity: String, Sendable, Hashable {
            case ok, review, danger
        }
    }
}

actor SmartCareOrchestrator {

    private let systemJunk: SystemJunkScanner
    private let trash: TrashBinScanner
    private let malware: MalwareScanner
    private let homebrew: HomebrewUpdater
    private let appScanner: AppScanner
    private let sparkle: SparkleUpdater
    private let loginItems: LoginItemsService

    init(systemJunk: SystemJunkScanner,
         trash: TrashBinScanner,
         malware: MalwareScanner,
         homebrew: HomebrewUpdater,
         appScanner: AppScanner,
         sparkle: SparkleUpdater,
         loginItems: LoginItemsService) {
        self.systemJunk = systemJunk
        self.trash = trash
        self.malware = malware
        self.homebrew = homebrew
        self.appScanner = appScanner
        self.sparkle = sparkle
        self.loginItems = loginItems
    }

    func run() async -> SmartCareReport {
        async let junkTask = (try? systemJunk.scan()) ?? []
        async let trashTask = (try? trash.scan()) ?? []
        async let malwareTask = malware.scan()
        async let casksTask = homebrew.outdatedCasksOrEmpty()
        async let installedTask = appScanner.scan()
        async let agentsTask = loginItems.enumerate()

        let junk = await junkTask
        let trashItems = await trashTask
        let malwareItems = await malwareTask
        let casks = await casksTask
        let apps = await installedTask
        let sparkleUpdates = await sparkle.checkUpdates(for: apps)
        let agents = await agentsTask

        let activeAgents = agents.filter { !$0.isDisabled && $0.scope == .userAgent }

        let entries: [SmartCareReport.Entry] = [
            buildJunkEntry(items: junk),
            buildTrashEntry(items: trashItems),
            buildMalwareEntry(items: malwareItems),
            buildUpdatesEntry(casks: casks.count, sparkle: sparkleUpdates.count),
            buildPerformanceEntry(activeUserAgents: activeAgents.count)
        ]

        let report = SmartCareReport(entries: entries, scannedAt: Date())
        Log.scanner.info("SmartCare report: \(report.totalIssueCount) issues, \(report.totalCleanableBytes.formattedBytes) cleanable")
        return report
    }

    /// Cleans only items marked SafetyLevel.safe across the cleanup scanners.
    func cleanAllSafeItems() async -> CleanResult {
        let junk = (try? await systemJunk.scan()) ?? []
        let safe = junk.filter { $0.safetyLevel == .safe }
        guard !safe.isEmpty else {
            return CleanResult(removed: [], failed: [], totalBytesFreed: 0)
        }
        return await systemJunk.clean(safe)
    }

    // MARK: - Builders

    private func buildJunkEntry(items: [CleanableItem]) -> SmartCareReport.Entry {
        let total = items.reduce(Int64(0)) { $0 + $1.size }
        return .init(
            id: "system_junk",
            module: .systemJunk,
            title: "System Junk",
            symbol: "trash.circle",
            count: items.count,
            totalBytes: total,
            severity: items.isEmpty ? .ok : .review,
            summary: items.isEmpty ? "Nothing to clean" : "\(items.count) items, \(total.formattedBytes)"
        )
    }

    private func buildTrashEntry(items: [CleanableItem]) -> SmartCareReport.Entry {
        let total = items.reduce(Int64(0)) { $0 + $1.size }
        return .init(
            id: "trash",
            module: .trashBins,
            title: "Trash Bins",
            symbol: "trash",
            count: items.count,
            totalBytes: total,
            severity: items.isEmpty ? .ok : .review,
            summary: items.isEmpty ? "Empty" : "\(items.count) items, \(total.formattedBytes)"
        )
    }

    private func buildMalwareEntry(items: [ThreatItem]) -> SmartCareReport.Entry {
        let danger = items.contains { $0.severity == .danger }
        let warn = items.contains { $0.severity == .warn }
        let severity: SmartCareReport.Entry.Severity = danger ? .danger : (warn ? .review : .ok)
        let summary: String
        if danger { summary = "Suspicious persistence detected" }
        else if warn { summary = "\(items.filter { $0.severity == .warn }.count) items to review" }
        else { summary = "No persistence threats" }
        return .init(
            id: "malware",
            module: .malware,
            title: "Malware",
            symbol: "shield.lefthalf.filled",
            count: items.count,
            totalBytes: nil,
            severity: severity,
            summary: summary
        )
    }

    private func buildUpdatesEntry(casks: Int, sparkle: Int) -> SmartCareReport.Entry {
        let total = casks + sparkle
        let summary: String
        if total == 0 { summary = "All up to date" }
        else if casks > 0 && sparkle > 0 { summary = "\(casks) casks + \(sparkle) Sparkle apps" }
        else if casks > 0 { summary = "\(casks) Homebrew cask\(casks == 1 ? "" : "s") outdated" }
        else { summary = "\(sparkle) Sparkle app\(sparkle == 1 ? "" : "s") outdated" }
        return .init(
            id: "updates",
            module: .updater,
            title: "Updates",
            symbol: "arrow.triangle.2.circlepath",
            count: total,
            totalBytes: nil,
            severity: total == 0 ? .ok : .review,
            summary: summary
        )
    }

    private func buildPerformanceEntry(activeUserAgents: Int) -> SmartCareReport.Entry {
        .init(
            id: "performance",
            module: .loginItems,
            title: "Performance",
            symbol: "wrench.and.screwdriver",
            count: activeUserAgents,
            totalBytes: nil,
            severity: activeUserAgents > 8 ? .review : .ok,
            summary: "\(activeUserAgents) active user LaunchAgent\(activeUserAgents == 1 ? "" : "s")"
        )
    }
}

// MARK: - Helper

extension HomebrewUpdater {
    func outdatedCasksOrEmpty() async -> [CaskUpdate] {
        do { return try await outdatedCasks() }
        catch { return [] }
    }
}
