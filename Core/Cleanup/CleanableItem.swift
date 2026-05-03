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
}
