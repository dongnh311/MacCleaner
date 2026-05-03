import Foundation

struct MaintenanceCommand: Identifiable, Sendable, Hashable {
    let id: String
    let title: String
    let summary: String
    let command: String
    let requiresAdmin: Bool
    let category: Category

    enum Category: String, Sendable, CaseIterable, Hashable {
        case periodic, dns, spotlight, launchServices, snapshots, dock

        var displayName: String {
            switch self {
            case .periodic:        return "Periodic Scripts"
            case .dns:             return "DNS Cache"
            case .spotlight:       return "Spotlight"
            case .launchServices:  return "Launch Services"
            case .snapshots:       return "Local Snapshots"
            case .dock:            return "Dock & Finder"
            }
        }
    }

    static let all: [MaintenanceCommand] = [
        MaintenanceCommand(
            id: "periodic_daily",
            title: "Run daily maintenance",
            summary: "Cleans /var/log, rotates logs, removes scratch files.",
            command: "sudo periodic daily",
            requiresAdmin: true,
            category: .periodic
        ),
        MaintenanceCommand(
            id: "periodic_weekly",
            title: "Run weekly maintenance",
            summary: "Rebuilds locate database, rotates more logs.",
            command: "sudo periodic weekly",
            requiresAdmin: true,
            category: .periodic
        ),
        MaintenanceCommand(
            id: "periodic_monthly",
            title: "Run monthly maintenance",
            summary: "Generates accounting reports, prunes more state.",
            command: "sudo periodic monthly",
            requiresAdmin: true,
            category: .periodic
        ),
        MaintenanceCommand(
            id: "flush_dns",
            title: "Flush DNS cache",
            summary: "Useful when domain resolution acts up.",
            command: "sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder",
            requiresAdmin: true,
            category: .dns
        ),
        MaintenanceCommand(
            id: "spotlight_reindex",
            title: "Reindex Spotlight (boot volume)",
            summary: "Forces Spotlight to rebuild its index from scratch.",
            command: "sudo mdutil -E /",
            requiresAdmin: true,
            category: .spotlight
        ),
        MaintenanceCommand(
            id: "lsregister_rebuild",
            title: "Rebuild Launch Services database",
            summary: "Fixes 'Open With' menu corruption and ghost duplicates.",
            command: "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -kill -r -domain local -domain system -domain user",
            requiresAdmin: false,
            category: .launchServices
        ),
        MaintenanceCommand(
            id: "thin_snapshots",
            title: "Free purgeable space",
            summary: "Reclaims local Time Machine snapshots up to 4 hours old.",
            command: "tmutil thinlocalsnapshots / 9999999999 4",
            requiresAdmin: true,
            category: .snapshots
        ),
        MaintenanceCommand(
            id: "restart_dock",
            title: "Restart Dock + Finder",
            summary: "Re-launches Finder and Dock — useful after settings changes.",
            command: "killall Dock && killall Finder",
            requiresAdmin: false,
            category: .dock
        )
    ]
}
