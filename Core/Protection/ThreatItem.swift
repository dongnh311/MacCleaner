import Foundation

struct ThreatItem: Identifiable, Hashable, Sendable {
    let id: URL
    let url: URL
    let kind: ThreatKind
    let severity: Severity
    let title: String
    let description: String
    let signals: [String]   // human-readable risk signals
    let isCodeSigned: Bool?
    let bundleID: String?

    enum ThreatKind: String, Sendable, Hashable {
        case launchAgent
        case launchDaemon
        case loginItem
        case browserExtension
        case quarantinedExecutable
        case suspiciousBinary
    }

    enum Severity: Int, Sendable, Hashable, Comparable {
        case info = 0
        case warn = 1
        case danger = 2

        var label: String {
            switch self {
            case .info: return "INFO"
            case .warn: return "REVIEW"
            case .danger: return "DANGER"
            }
        }

        static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }
    }
}
