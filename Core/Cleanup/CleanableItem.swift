import Foundation

struct CleanableItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let size: Int64
    let category: ItemCategory
    let safetyLevel: SafetyLevel
    let lastModified: Date?
    let isDirectory: Bool
    let title: String
    let description: String
    let ruleID: String?
}

enum SafetyLevel: String, Codable, Sendable, Hashable {
    case safe
    case review
    case dangerous

    var displayName: String {
        switch self {
        case .safe:      return "SAFE"
        case .review:    return "REVIEW"
        case .dangerous: return "DANGEROUS"
        }
    }
}

enum ItemCategory: String, Codable, Sendable, Hashable, CaseIterable {
    case userCache       = "user_cache"
    case systemCache     = "system_cache"
    case userLog         = "user_log"
    case systemLog       = "system_log"
    case xcodeJunk       = "xcode_junk"
    case devToolCache    = "dev_tool_cache"
    case downloadedFile  = "downloaded_file"
    case trash           = "trash"
    case mailAttachment  = "mail_attachment"
    case photoCache      = "photo_cache"
    case other           = "other"

    var displayName: String {
        switch self {
        case .userCache:      return "User Cache"
        case .systemCache:    return "System Cache"
        case .userLog:        return "Logs"
        case .systemLog:      return "System Logs"
        case .xcodeJunk:      return "Xcode"
        case .devToolCache:   return "Dev Tools"
        case .downloadedFile: return "Downloads"
        case .trash:          return "Trash"
        case .mailAttachment: return "Mail"
        case .photoCache:     return "Photos"
        case .other:          return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .userCache, .systemCache: return "internaldrive"
        case .userLog, .systemLog:     return "doc.text"
        case .xcodeJunk:               return "hammer"
        case .devToolCache:            return "shippingbox"
        case .downloadedFile:          return "arrow.down.circle"
        case .trash:                   return "trash"
        case .mailAttachment:          return "envelope"
        case .photoCache:              return "photo"
        case .other:                   return "questionmark.folder"
        }
    }

    /// Long-form description shown in the cleanup detail panel — explains
    /// what this category contains and why it's safe (or not) to remove.
    var rationale: String {
        switch self {
        case .userCache:
            return "App caches under ~/Library/Caches. Apps regenerate them on next launch — safe to clean when the app isn't running."
        case .systemCache:
            return "OS-level caches under /Library/Caches and /System/Library/Caches. macOS rebuilds them on demand."
        case .userLog:
            return "Per-user log files in ~/Library/Logs. Useful for debugging recent issues, otherwise typically stale and bulky."
        case .systemLog:
            return "System-wide log files. macOS rotates them automatically; old archives rarely matter."
        case .xcodeJunk:
            return "Xcode derived data, build intermediates, archives, and Simulator runtimes. Xcode rebuilds on next compile; runtimes re-download from Apple if needed."
        case .devToolCache:
            return "Caches from CocoaPods, npm/yarn/pnpm, Gradle, Maven, SPM, etc. Each tool re-downloads on next install."
        case .downloadedFile:
            return "Files in ~/Downloads. Often safe to remove but may contain user documents — review before deleting."
        case .trash:
            return "Items in Trash bins (user + per-volume). Cleaning is a permanent delete."
        case .mailAttachment:
            return "Cached Mail attachments. Mail re-downloads from the IMAP/Exchange server on demand."
        case .photoCache:
            return "Photo library derivatives and thumbnail caches. Photos.app rebuilds on next launch."
        case .other:
            return "Miscellaneous cleanable items that don't fit the other categories."
        }
    }
}
