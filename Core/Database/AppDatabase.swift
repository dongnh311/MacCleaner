import Foundation
import GRDB

extension Notification.Name {
    /// Posted on the main actor whenever a row is inserted into scan_history.
    /// Recent Activity panel listens to this so it can update without polling.
    static let scanHistoryUpdated = Notification.Name("MacCleaner.scanHistoryUpdated")
}

final class AppDatabase: Sendable {

    let writer: any DatabaseWriter

    init(writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    private static var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()

        #if DEBUG
        m.eraseDatabaseOnSchemaChange = true
        #endif

        m.registerMigration("v1_initial") { db in
            try db.create(table: "scan_history") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("module", .text).notNull().indexed()
                t.column("started_at", .datetime).notNull()
                t.column("finished_at", .datetime)
                t.column("items_scanned", .integer).notNull().defaults(to: 0)
                t.column("bytes_total", .integer).notNull().defaults(to: 0)
                t.column("status", .text).notNull()
                t.column("source_path", .text)
            }

            try db.create(table: "exclusion") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("path", .text).notNull().unique()
                t.column("created_at", .datetime).notNull()
                t.column("note", .text)
            }
        }

        m.registerMigration("v2_app_usage") { db in
            // Hourly bucket of per-app activity. One row per (bundle_id,
            // hour_bucket); the logger upserts every minute while the app
            // is up. `hour_bucket` is Unix-epoch hours (seconds / 3600);
            // 32-bit integer is fine until year 6053.
            try db.create(table: "app_usage_hourly") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bundle_id", .text).notNull()
                t.column("name", .text).notNull()
                t.column("hour_bucket", .integer).notNull().indexed()
                t.column("minutes_seen", .integer).notNull().defaults(to: 0)
                t.column("avg_cpu_percent", .double).notNull().defaults(to: 0)
                t.column("avg_memory_bytes", .integer).notNull().defaults(to: 0)
                t.column("max_memory_bytes", .integer).notNull().defaults(to: 0)
                t.column("is_background", .integer).notNull().defaults(to: 0)
                t.column("sample_count", .integer).notNull().defaults(to: 0)
                t.uniqueKey(["bundle_id", "hour_bucket"])
            }
        }

        return m
    }

    static func makeShared() throws -> AppDatabase {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("MacCleaner", isDirectory: true)

        try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)

        let dbURL = appSupport.appendingPathComponent("maccleaner.sqlite")
        Log.db.info("opening database at \(dbURL.path, privacy: .public)")

        var config = Configuration()
        config.label = "MacCleanerDB"
        let pool = try DatabasePool(path: dbURL.path, configuration: config)
        return try AppDatabase(writer: pool)
    }

    static func inMemory() throws -> AppDatabase {
        let queue = try DatabaseQueue()
        return try AppDatabase(writer: queue)
    }
}

// MARK: - Scan history

extension AppDatabase {

    func recordScan(
        module: String,
        startedAt: Date,
        finishedAt: Date,
        itemsScanned: Int = 0,
        bytesTotal: Int64,
        sourcePath: String? = nil,
        status: String = "completed"
    ) async throws {
        try await writer.write { db in
            try db.execute(
                sql: """
                INSERT INTO scan_history
                    (module, started_at, finished_at, items_scanned, bytes_total, status, source_path)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [module, startedAt, finishedAt, itemsScanned, bytesTotal, status, sourcePath]
            )
        }
        await MainActor.run {
            NotificationCenter.default.post(name: .scanHistoryUpdated, object: nil)
        }
    }

    func recentScans(module: String? = nil, limit: Int = 20) async throws -> [ScanHistoryRow] {
        try await writer.read { db in
            if let module {
                return try ScanHistoryRow.fetchAll(
                    db,
                    sql: """
                    SELECT * FROM scan_history WHERE module = ?
                    ORDER BY started_at DESC LIMIT ?
                    """,
                    arguments: [module, limit]
                )
            } else {
                return try ScanHistoryRow.fetchAll(
                    db,
                    sql: "SELECT * FROM scan_history ORDER BY started_at DESC LIMIT ?",
                    arguments: [limit]
                )
            }
        }
    }
}

struct ScanHistoryRow: Codable, FetchableRecord, Sendable {
    var id: Int64
    var module: String
    var startedAt: Date
    var finishedAt: Date?
    var itemsScanned: Int
    var bytesTotal: Int64
    var status: String
    var sourcePath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case module
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case itemsScanned = "items_scanned"
        case bytesTotal = "bytes_total"
        case status
        case sourcePath = "source_path"
    }
}

// MARK: - App usage analytics

/// One bucket of activity for the AppUsageLogger to upsert. Hour is
/// Unix-epoch hours so it's a simple `Int(time / 3600)` from any Date.
struct AppUsageBucket: Sendable {
    let bundleID: String
    let name: String
    let hour: Int
    let minutesSeen: Int
    let avgCPUPercent: Double
    let avgMemoryBytes: Int64
    let maxMemoryBytes: Int64
    let isBackground: Bool
    let sampleCount: Int
}

/// Aggregate row returned by the analytics queries. `totalMinutes` is the
/// sum of `minutes_seen` over the window — i.e. how long the app was up
/// during the period the user is asking about.
struct UsageAggregate: Sendable, Identifiable {
    var id: String { bundleID }
    let bundleID: String
    let name: String
    let totalMinutes: Int
    let avgMemoryBytes: Int64
    let maxMemoryBytes: Int64
    let lastSeenHour: Int
    let isBackground: Bool
}

extension AppDatabase {

    /// Upsert one hour's worth of samples for a set of apps. Called by
    /// `AppUsageLogger` on every hour-roll and on a 5-minute partial
    /// flush so the latest data is visible to Usage Trends without
    /// waiting for the hour to complete.
    func recordUsageBuckets(_ buckets: [AppUsageBucket]) async throws {
        guard !buckets.isEmpty else { return }
        try await writer.write { db in
            for b in buckets {
                try db.execute(
                    sql: """
                    INSERT INTO app_usage_hourly
                        (bundle_id, name, hour_bucket, minutes_seen,
                         avg_cpu_percent, avg_memory_bytes, max_memory_bytes,
                         is_background, sample_count)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(bundle_id, hour_bucket) DO UPDATE SET
                        name = excluded.name,
                        minutes_seen = excluded.minutes_seen,
                        avg_cpu_percent = excluded.avg_cpu_percent,
                        avg_memory_bytes = excluded.avg_memory_bytes,
                        max_memory_bytes = excluded.max_memory_bytes,
                        is_background = excluded.is_background,
                        sample_count = excluded.sample_count
                    """,
                    arguments: [
                        b.bundleID, b.name, b.hour, b.minutesSeen,
                        b.avgCPUPercent, b.avgMemoryBytes, b.maxMemoryBytes,
                        b.isBackground ? 1 : 0, b.sampleCount
                    ]
                )
            }
        }
    }

    /// Top N apps by total minutes seen in the last `days`. If
    /// `backgroundOnly`, restricts to apps the logger marked as
    /// background (LSUIElement / LSBackgroundOnly).
    func topUsageByPresence(days: Int, limit: Int = 20,
                            backgroundOnly: Bool = false) async throws -> [UsageAggregate] {
        let cutoff = currentHour() - days * 24
        return try await writer.read { db in
            let bgClause = backgroundOnly ? "AND is_background = 1" : ""
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT bundle_id,
                       MAX(name) AS name,
                       SUM(minutes_seen) AS total_minutes,
                       AVG(avg_memory_bytes) AS avg_mem,
                       MAX(max_memory_bytes) AS max_mem,
                       MAX(hour_bucket) AS last_hour,
                       MAX(is_background) AS is_bg
                FROM app_usage_hourly
                WHERE hour_bucket >= ? \(bgClause)
                GROUP BY bundle_id
                ORDER BY total_minutes DESC
                LIMIT ?
                """,
                arguments: [cutoff, limit]
            )
            return rows.map(Self.aggregateFromRow)
        }
    }

    /// Top N apps by average memory consumption while running. Filters
    /// to apps with at least 30 minutes of samples in the window so a
    /// briefly-spiked app doesn't dominate the chart.
    func topUsageByMemory(days: Int, limit: Int = 20) async throws -> [UsageAggregate] {
        let cutoff = currentHour() - days * 24
        return try await writer.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT bundle_id,
                       MAX(name) AS name,
                       SUM(minutes_seen) AS total_minutes,
                       AVG(avg_memory_bytes) AS avg_mem,
                       MAX(max_memory_bytes) AS max_mem,
                       MAX(hour_bucket) AS last_hour,
                       MAX(is_background) AS is_bg
                FROM app_usage_hourly
                WHERE hour_bucket >= ?
                GROUP BY bundle_id
                HAVING total_minutes >= 30
                ORDER BY avg_mem DESC
                LIMIT ?
                """,
                arguments: [cutoff, limit]
            )
            return rows.map(Self.aggregateFromRow)
        }
    }

    /// Most-recently-seen hour for every app the logger ever tracked.
    /// The view layer compares this against the installed-app list from
    /// `AppScanner` to surface apps that haven't run in N days.
    func lastSeenPerApp() async throws -> [String: Int] {
        try await writer.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT bundle_id, MAX(hour_bucket) AS last_hour
                FROM app_usage_hourly
                GROUP BY bundle_id
                """
            )
            var out: [String: Int] = [:]
            for row in rows {
                let bid: String = row["bundle_id"]
                let h: Int = row["last_hour"]
                out[bid] = h
            }
            return out
        }
    }

    /// Drops buckets older than the retention window. Called on app
    /// launch — 90 days × 50 apps × 24 hr ≈ 108K rows / ~10 MB ceiling.
    func purgeUsageOlderThan(days: Int) async throws {
        let cutoff = currentHour() - days * 24
        try await writer.write { db in
            try db.execute(
                sql: "DELETE FROM app_usage_hourly WHERE hour_bucket < ?",
                arguments: [cutoff]
            )
        }
    }

    /// Unix-epoch hour for "now". Helper so analytics callers can do
    /// arithmetic without juggling Date conversions.
    static func currentHour(at date: Date = Date()) -> Int {
        Int(date.timeIntervalSince1970 / 3600)
    }
    private func currentHour() -> Int { Self.currentHour() }

    private static func aggregateFromRow(_ row: Row) -> UsageAggregate {
        UsageAggregate(
            bundleID: row["bundle_id"],
            name: row["name"] ?? row["bundle_id"],
            totalMinutes: row["total_minutes"] ?? 0,
            avgMemoryBytes: Int64(row["avg_mem"] as Double? ?? 0),
            maxMemoryBytes: row["max_mem"] ?? 0,
            lastSeenHour: row["last_hour"] ?? 0,
            isBackground: (row["is_bg"] as Int?) == 1
        )
    }
}
