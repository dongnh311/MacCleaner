import Foundation

enum WhitelistGuard {

    private static let absoluteProtected: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/Library/Apple",
        "/Library/Application Support/Apple",
        "/Library/Frameworks",
        "/Library/PrivilegedHelperTools",
        "/Applications",
        "/private/var/db",
        "/private/var/folders",
        "/private/etc"
    ]

    private static let userSubProtected: [String] = [
        "Documents",
        "Desktop",
        "Movies",
        "Music",
        "Pictures",
        "Downloads",
        ".ssh",
        ".gnupg",
        "Library/Keychains",
        "Library/Mobile Documents",
        "Library/CloudStorage"
    ]

    /// Returns true if the URL must NEVER be modified by any cleaner.
    static func isProtected(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path

        if path == "/usr/local" || path.hasPrefix("/usr/local/") {
            return false
        }

        for prefix in absoluteProtected {
            if path == prefix || path.hasPrefix(prefix + "/") {
                return true
            }
        }

        let home = NSHomeDirectory()
        for sub in userSubProtected {
            let full = (home as NSString).appendingPathComponent(sub)
            if path == full || path.hasPrefix(full + "/") {
                return true
            }
        }

        return false
    }
}
