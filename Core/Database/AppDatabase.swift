import Foundation
import GRDB

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
