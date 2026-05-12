import Foundation
import AppKit

struct ProcessSnapshot: Identifiable, Hashable, Sendable {
    let id: Int32
    let pid: Int32
    let name: String
    let user: String
    let cpuPercent: Double
    let memoryBytes: Int64
    let command: String
}

/// One running app process that has no Dock presence — either menu-bar
/// only (LSUIElement) or fully hidden (LSBackgroundOnly). These are the
/// surfaces a user typically doesn't see in the Dock or ⌘-Tab, so they're
/// the natural place for a "what's running that I don't know about" view.
struct BackgroundApp: Identifiable, Hashable, Sendable {
    let id: Int32
    let pid: Int32
    let name: String
    let bundleID: String
    let bundlePath: String
    let memoryBytes: Int64
    /// Bundle ID starts with `com.apple.` — these are system processes
    /// the user usually shouldn't quit. Surfaced visually so they don't
    /// drown out third-party entries in the review list.
    let isAppleProcess: Bool
}

/// One 60s sample of a running app, captured by `AppUsageLogger`. Used
/// only at sampling time — gets aggregated into `AppUsageBucket` rows
/// before any persistence happens.
private struct AppUsageSample: Sendable {
    let bundleID: String
    let name: String
    let cpuPercent: Double
    let memoryBytes: Int64
    let isBackground: Bool
}

/// Long-running observer that snapshots the running-apps roster every
/// 60 seconds and records hourly aggregates to the database. The
/// "Usage Trends" view reads these aggregates to answer:
/// - which apps the user actually uses
/// - which background apps run the longest (data exfiltration risk)
/// - which apps haven't been seen for N days (cleanup candidates)
///
/// Storage budget: ~50 active apps × 24 hours × 90 days ≈ 108K rows.
/// A daily purge in `start()` keeps the table bounded.
actor AppUsageLogger {

    private struct Accumulator {
        var name: String
        var isBackground: Bool
        var cpuSum: Double
        var memSum: Int64
        var maxMem: Int64
        var sampleCount: Int
    }

    private let db: AppDatabase
    private let processMonitor: ProcessMonitor

    private var task: Task<Void, Never>?
    /// Unix-epoch hour for the bucket we're currently accumulating into.
    /// 0 = uninitialised (first tick).
    private var currentHour: Int = 0
    private var currentBucket: [String: Accumulator] = [:]

    init(db: AppDatabase, processMonitor: ProcessMonitor) {
        self.db = db
        self.processMonitor = processMonitor
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            await self?.purgeOld()
            // Take an immediate sample so the user sees data after one
            // minute of runtime instead of waiting 60s + flush interval.
            await self?.tick()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                await self?.tick()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func tick() async {
        let hour = AppDatabase.currentHour()
        if currentHour != 0 && hour != currentHour {
            currentBucket = [:]
        }
        currentHour = hour

        let snap = await processMonitor.snapshot()
        // `uniquingKeysWith` instead of `uniqueKeysWithValues`: ps occasionally
        // emits a pid twice during zombie reaping; `unique…` traps.
        let rssByPID = Dictionary(snap.map { ($0.pid, $0.memoryBytes) }, uniquingKeysWith: { first, _ in first })
        let cpuByPID = Dictionary(snap.map { ($0.pid, $0.cpuPercent) }, uniquingKeysWith: { first, _ in first })

        let samples = await MainActor.run { () -> [AppUsageSample] in
            var out: [AppUsageSample] = []
            for app in NSWorkspace.shared.runningApplications {
                guard let bid = app.bundleIdentifier, !bid.isEmpty else { continue }
                let pid = app.processIdentifier
                guard pid > 0 else { continue }
                out.append(AppUsageSample(
                    bundleID: bid,
                    name: app.localizedName ?? bid,
                    cpuPercent: cpuByPID[pid] ?? 0,
                    memoryBytes: rssByPID[pid] ?? 0,
                    isBackground: app.activationPolicy != .regular
                ))
            }
            return out
        }

        for s in samples {
            var acc = currentBucket[s.bundleID]
                ?? Accumulator(name: s.name, isBackground: s.isBackground,
                               cpuSum: 0, memSum: 0, maxMem: 0, sampleCount: 0)
            acc.cpuSum += s.cpuPercent
            acc.memSum += s.memoryBytes
            acc.maxMem = max(acc.maxMem, s.memoryBytes)
            acc.sampleCount += 1
            acc.name = s.name
            currentBucket[s.bundleID] = acc
        }

        await flush(hour: currentHour)
    }

    private func flush(hour: Int) async {
        guard !currentBucket.isEmpty else { return }
        let buckets = currentBucket.map { (bid, acc) -> AppUsageBucket in
            AppUsageBucket(
                bundleID: bid,
                name: acc.name,
                hour: hour,
                minutesSeen: acc.sampleCount,
                avgCPUPercent: acc.sampleCount > 0 ? acc.cpuSum / Double(acc.sampleCount) : 0,
                avgMemoryBytes: acc.sampleCount > 0 ? acc.memSum / Int64(acc.sampleCount) : 0,
                maxMemoryBytes: acc.maxMem,
                isBackground: acc.isBackground,
                sampleCount: acc.sampleCount
            )
        }
        do {
            try await db.recordUsageBuckets(buckets)
        } catch {
            Log.db.error("usage flush failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func purgeOld() async {
        do { try await db.purgeUsageOlderThan(days: 90) }
        catch { Log.db.error("usage purge failed: \(error.localizedDescription, privacy: .public)") }
    }
}

@MainActor
enum BackgroundAppScanner {
    /// Snapshot of NSRunningApplications whose activation policy is NOT
    /// `.regular` — accessory (LSUIElement / menu-bar only) and prohibited
    /// (LSBackgroundOnly / fully hidden). Memory is enriched from the
    /// caller-supplied `[pid: rssBytes]` map (typically built from the
    /// already-running `ProcessMonitor.snapshot`) so we don't fork ps a
    /// second time. PIDs not in the map get 0 bytes; UI shows "—".
    static func scan(rssByPID: [Int32: Int64] = [:]) -> [BackgroundApp] {
        var out: [BackgroundApp] = []
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy != .regular else { continue }
            guard let bundleID = app.bundleIdentifier, !bundleID.isEmpty else { continue }
            let pid = app.processIdentifier
            guard pid > 0 else { continue }
            out.append(BackgroundApp(
                id: pid,
                pid: pid,
                name: app.localizedName ?? bundleID,
                bundleID: bundleID,
                bundlePath: app.bundleURL?.path ?? "",
                memoryBytes: rssByPID[pid] ?? 0,
                isAppleProcess: bundleID.hasPrefix("com.apple.")
            ))
        }
        return out.sorted { lhs, rhs in
            // Third-party first (user's review target), then by memory desc.
            if lhs.isAppleProcess != rhs.isAppleProcess { return !lhs.isAppleProcess }
            if lhs.memoryBytes != rhs.memoryBytes { return lhs.memoryBytes > rhs.memoryBytes }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

actor ProcessMonitor {

    func snapshot() async -> [ProcessSnapshot] {
        await Task.detached(priority: .userInitiated) {
            Self.runPS()
        }.value
    }

    func kill(pid: Int32, force: Bool) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            let signal: Int32 = force ? Int32(SIGKILL) : Int32(SIGTERM)
            return Darwin.kill(pid, signal) == 0
        }.value
    }

    private nonisolated static func runPS() -> [ProcessSnapshot] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,rss=,pcpu=,user=,comm="]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            Log.app.error("ps spawn failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
        // Read the pipe BEFORE waitUntilExit. With 500+ processes, ps output
        // exceeds the 64KB pipe buffer; if we wait first, ps blocks on write
        // and we deadlock. readDataToEndOfFile drains until ps closes the
        // pipe on exit, then waitUntilExit returns immediately.
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        var results: [ProcessSnapshot] = []
        results.reserveCapacity(512)

        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Format: pid rss pcpu user comm  (comm may contain spaces — last column)
            let scanner = Scanner(string: trimmed)
            scanner.charactersToBeSkipped = .whitespaces

            var pid: Int32 = 0
            var rssKB: Int64 = 0
            var pcpu: Double = 0
            var user: NSString?

            guard scanner.scanInt32(&pid),
                  scanner.scanInt64(&rssKB),
                  scanner.scanDouble(&pcpu),
                  scanner.scanUpToCharacters(from: .whitespaces, into: &user) else { continue }

            let userStr = (user as String?) ?? ""
            let comm = String(trimmed[scanner.string.index(scanner.string.startIndex, offsetBy: scanner.currentIndex.utf16Offset(in: scanner.string))...])
                .trimmingCharacters(in: .whitespaces)

            let url = URL(fileURLWithPath: comm)
            let displayName = url.pathComponents.contains(where: { $0.hasSuffix(".app") })
                ? (url.pathComponents.first(where: { $0.hasSuffix(".app") })?.replacingOccurrences(of: ".app", with: "") ?? url.lastPathComponent)
                : url.lastPathComponent

            results.append(ProcessSnapshot(
                id: pid,
                pid: pid,
                name: displayName.isEmpty ? comm : displayName,
                user: userStr,
                cpuPercent: pcpu,
                memoryBytes: rssKB * 1024,
                command: comm
            ))
        }

        return results
    }
}
