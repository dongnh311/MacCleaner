import Foundation

struct InstalledApp: Identifiable, Hashable, Sendable {
    let id: URL
    let url: URL
    let name: String
    let bundleID: String?
    let version: String?
    let buildVersion: String?
    let size: Int64
    let lastModified: Date?
    let lastOpened: Date?
    let isAppStore: Bool
    let isUserApp: Bool
    let sparkleFeedURL: String?

    var sizeText: String { size.formattedBytes }
}

struct AppLeftover: Identifiable, Hashable, Sendable {
    let id: URL
    let url: URL
    let kind: Kind
    let size: Int64

    enum Kind: String, Sendable, CaseIterable {
        case applicationSupport
        case caches
        case preferences
        case logs
        case savedState
        case containers
        case groupContainers
        case httpStorages
        case webKit
        case launchAgents

        var displayName: String {
            switch self {
            case .applicationSupport: return "Application Support"
            case .caches:             return "Caches"
            case .preferences:        return "Preferences"
            case .logs:               return "Logs"
            case .savedState:         return "Saved State"
            case .containers:         return "Containers"
            case .groupContainers:    return "Group Containers"
            case .httpStorages:       return "HTTP Storages"
            case .webKit:             return "WebKit"
            case .launchAgents:       return "Launch Agents"
            }
        }
    }
}
