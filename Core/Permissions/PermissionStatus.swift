import Foundation

enum PermissionStatus: Equatable, Sendable {
    case granted
    case denied
    case unknown
}

enum PermissionType: String, CaseIterable, Identifiable, Sendable {
    case fullDiskAccess
    case accessibility

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullDiskAccess: return "Full Disk Access"
        case .accessibility:  return "Accessibility"
        }
    }

    var rationale: String {
        switch self {
        case .fullDiskAccess:
            return "Required to scan caches, mail attachments, browser data, and the TCC database."
        case .accessibility:
            return "Required to quit running apps before cleanup and automate maintenance tasks."
        }
    }

    var settingsURL: URL {
        switch self {
        case .fullDiskAccess:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        case .accessibility:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        }
    }
}
