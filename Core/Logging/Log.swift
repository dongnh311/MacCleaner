import OSLog

enum Log {
    static let subsystem = "com.dong.MacCleaner"

    static let app         = Logger(subsystem: subsystem, category: "app")
    static let fs          = Logger(subsystem: subsystem, category: "filesystem")
    static let permissions = Logger(subsystem: subsystem, category: "permissions")
    static let db          = Logger(subsystem: subsystem, category: "database")
    static let scanner     = Logger(subsystem: subsystem, category: "scanner")
    static let ui          = Logger(subsystem: subsystem, category: "ui")
}
