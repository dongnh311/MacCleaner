import Foundation
import GRDB

struct TCCEntry: Identifiable, Hashable, Sendable {
    let id: String
    let service: TCCService
    let client: String
    let isAllowed: Bool
    let scope: Scope

    enum Scope: String, Sendable, Hashable {
        case user, system

        var displayName: String { self == .user ? "User" : "System" }
    }
}

enum TCCService: String, Sendable, Hashable, CaseIterable {
    case camera                = "kTCCServiceCamera"
    case microphone            = "kTCCServiceMicrophone"
    case fullDiskAccess        = "kTCCServiceSystemPolicyAllFiles"
    case accessibility         = "kTCCServiceAccessibility"
    case screenCapture         = "kTCCServiceScreenCapture"
    case automation            = "kTCCServiceAppleEvents"
    case contacts              = "kTCCServiceAddressBook"
    case calendar              = "kTCCServiceCalendar"
    case reminders             = "kTCCServiceReminders"
    case photos                = "kTCCServicePhotos"
    case desktopFolder         = "kTCCServiceSystemPolicyDesktopFolder"
    case documentsFolder       = "kTCCServiceSystemPolicyDocumentsFolder"
    case downloadsFolder       = "kTCCServiceSystemPolicyDownloadsFolder"
    case other                 = "other"

    var displayName: String {
        switch self {
        case .camera:           return "Camera"
        case .microphone:       return "Microphone"
        case .fullDiskAccess:   return "Full Disk Access"
        case .accessibility:    return "Accessibility"
        case .screenCapture:    return "Screen Recording"
        case .automation:       return "Automation"
        case .contacts:         return "Contacts"
        case .calendar:         return "Calendar"
        case .reminders:        return "Reminders"
        case .photos:           return "Photos"
        case .desktopFolder:    return "Desktop Folder"
        case .documentsFolder:  return "Documents Folder"
        case .downloadsFolder:  return "Downloads Folder"
        case .other:            return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .camera:          return "camera"
        case .microphone:      return "mic"
        case .fullDiskAccess:  return "externaldrive"
        case .accessibility:   return "figure.walk.circle"
        case .screenCapture:   return "rectangle.dashed.badge.record"
        case .automation:      return "gearshape.2"
        case .contacts:        return "person.crop.circle"
        case .calendar:        return "calendar"
        case .reminders:       return "checklist"
        case .photos:          return "photo"
        case .desktopFolder:   return "menubar.dock.rectangle"
        case .documentsFolder: return "doc"
        case .downloadsFolder: return "arrow.down.doc"
        case .other:           return "questionmark.circle"
        }
    }

    var settingsURL: URL? {
        let suffix: String
        switch self {
        case .camera:          suffix = "Privacy_Camera"
        case .microphone:      suffix = "Privacy_Microphone"
        case .fullDiskAccess:  suffix = "Privacy_AllFiles"
        case .accessibility:   suffix = "Privacy_Accessibility"
        case .screenCapture:   suffix = "Privacy_ScreenCapture"
        case .automation:      suffix = "Privacy_Automation"
        case .contacts:        suffix = "Privacy_Contacts"
        case .calendar:        suffix = "Privacy_Calendar"
        case .reminders:       suffix = "Privacy_Reminders"
        case .photos:          suffix = "Privacy_Photos"
        default:               return nil
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(suffix)")
    }
}

actor PermissionsReader {

    enum ReadError: Error, LocalizedError {
        case accessDenied
        case databaseMissing
        case other(String)

        var errorDescription: String? {
            switch self {
            case .accessDenied:    return "Reading TCC.db requires Full Disk Access."
            case .databaseMissing: return "TCC database not found."
            case .other(let m):    return m
            }
        }
    }

    func readEntries() async throws -> [TCCEntry] {
        let userDB = "\(NSHomeDirectory())/Library/Application Support/com.apple.TCC/TCC.db"
        let systemDB = "/Library/Application Support/com.apple.TCC/TCC.db"

        var collected: [TCCEntry] = []
        if FileManager.default.fileExists(atPath: userDB) {
            do {
                collected.append(contentsOf: try Self.read(path: userDB, scope: .user))
            } catch ReadError.accessDenied {
                throw ReadError.accessDenied
            }
        }
        if FileManager.default.fileExists(atPath: systemDB) {
            if let rows = try? Self.read(path: systemDB, scope: .system) {
                collected.append(contentsOf: rows)
            }
        }
        guard !collected.isEmpty else {
            throw ReadError.accessDenied
        }
        return collected
    }

    private nonisolated static func read(path: String, scope: TCCEntry.Scope) throws -> [TCCEntry] {
        guard FileManager.default.isReadableFile(atPath: path) else {
            throw ReadError.accessDenied
        }
        var config = Configuration()
        config.readonly = true
        config.label = "TCC.\(scope.rawValue)"

        let queue: DatabaseQueue
        do {
            queue = try DatabaseQueue(path: path, configuration: config)
        } catch {
            throw ReadError.accessDenied
        }

        return try queue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT service, client, auth_value FROM access
            """)
            return rows.compactMap { row -> TCCEntry? in
                guard let service: String = row["service"],
                      let client: String = row["client"],
                      let auth: Int = row["auth_value"] else {
                    return nil
                }
                let svc = TCCService(rawValue: service) ?? .other
                return TCCEntry(
                    id: "\(scope.rawValue)::\(service)::\(client)",
                    service: svc,
                    client: client,
                    isAllowed: auth >= 2,
                    scope: scope
                )
            }
        }
    }
}
