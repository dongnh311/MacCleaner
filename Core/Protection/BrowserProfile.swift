import Foundation

struct BrowserDataLocation: Sendable, Hashable {
    let browser: String
    let bundleID: String
    let label: String           // e.g. "History", "Cache"
    let path: String
    let category: ItemCategory
}

enum BrowserCatalog {

    static func locations() -> [BrowserDataLocation] {
        let home = NSHomeDirectory()
        var out: [BrowserDataLocation] = []

        // Safari
        out += [
            BrowserDataLocation(browser: "Safari", bundleID: "com.apple.Safari",
                                label: "History",
                                path: "\(home)/Library/Safari/History.db",
                                category: .userCache),
            BrowserDataLocation(browser: "Safari", bundleID: "com.apple.Safari",
                                label: "Cache",
                                path: "\(home)/Library/Containers/com.apple.Safari/Data/Library/Caches",
                                category: .userCache),
            BrowserDataLocation(browser: "Safari", bundleID: "com.apple.Safari",
                                label: "Downloads list",
                                path: "\(home)/Library/Safari/Downloads.plist",
                                category: .userCache)
        ]

        // Chromium-family helper
        func chromium(name: String, bundleID: String, supportFolder: String) -> [BrowserDataLocation] {
            let base = "\(home)/Library/Application Support/\(supportFolder)"
            return [
                BrowserDataLocation(browser: name, bundleID: bundleID,
                                    label: "Cache",
                                    path: "\(home)/Library/Caches/\(supportFolder)",
                                    category: .userCache),
                BrowserDataLocation(browser: name, bundleID: bundleID,
                                    label: "History (Default profile)",
                                    path: "\(base)/Default/History",
                                    category: .userCache),
                BrowserDataLocation(browser: name, bundleID: bundleID,
                                    label: "Cookies (Default profile)",
                                    path: "\(base)/Default/Cookies",
                                    category: .userCache),
                BrowserDataLocation(browser: name, bundleID: bundleID,
                                    label: "Service Worker cache",
                                    path: "\(base)/Default/Service Worker/CacheStorage",
                                    category: .userCache),
                BrowserDataLocation(browser: name, bundleID: bundleID,
                                    label: "GPU cache",
                                    path: "\(base)/Default/GPUCache",
                                    category: .userCache)
            ]
        }

        out += chromium(name: "Chrome", bundleID: "com.google.Chrome", supportFolder: "Google/Chrome")
        out += chromium(name: "Brave",  bundleID: "com.brave.Browser", supportFolder: "BraveSoftware/Brave-Browser")
        out += chromium(name: "Edge",   bundleID: "com.microsoft.edgemac", supportFolder: "Microsoft Edge")
        out += chromium(name: "Arc",    bundleID: "company.thebrowser.Browser", supportFolder: "Arc")
        out += chromium(name: "Vivaldi", bundleID: "com.vivaldi.Vivaldi", supportFolder: "Vivaldi")

        // Firefox uses random profile names — point at the Profiles root
        out += [
            BrowserDataLocation(browser: "Firefox", bundleID: "org.mozilla.firefox",
                                label: "Profiles cache",
                                path: "\(home)/Library/Caches/Firefox",
                                category: .userCache),
            BrowserDataLocation(browser: "Firefox", bundleID: "org.mozilla.firefox",
                                label: "Profiles support",
                                path: "\(home)/Library/Application Support/Firefox/Profiles",
                                category: .userCache)
        ]

        return out
    }
}
