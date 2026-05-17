import Foundation

actor AppScanner {

    func scan() async -> [InstalledApp] {
        let roots: [(URL, Bool)] = [
            (URL(fileURLWithPath: "/Applications"), false),
            (FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"), true)
        ]

        return await withTaskGroup(of: [InstalledApp].self) { group in
            for (root, isUser) in roots {
                group.addTask {
                    await Self.scanRoot(root, isUser: isUser)
                }
            }
            var collected: [InstalledApp] = []
            for await partial in group { collected.append(contentsOf: partial) }
            return collected.sorted { $0.size > $1.size }
        }
    }

    private nonisolated static func scanRoot(_ root: URL, isUser: Bool) async -> [InstalledApp] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return await withTaskGroup(of: InstalledApp?.self) { group in
            for url in entries where url.pathExtension == "app" {
                group.addTask { await Self.makeApp(at: url, isUser: isUser) }
            }
            var apps: [InstalledApp] = []
            for await app in group {
                if let app { apps.append(app) }
            }
            return apps
        }
    }

    private nonisolated static func makeApp(at url: URL, isUser: Bool) async -> InstalledApp? {
        let info = readInfoPlist(at: url)
        let bundleID = info?["CFBundleIdentifier"] as? String
        let displayName = (info?["CFBundleDisplayName"] as? String)
            ?? (info?["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        let sparkleFeed = info?["SUFeedURL"] as? String

        let isAppStore = FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/_MASReceipt/receipt").path)

        let size = await Task.detached(priority: .background) {
            FileSizeCalculator.walk(directory: url).total
        }.value

        let v = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        let lastModified = v?.contentModificationDate

        return InstalledApp(
            id: url,
            url: url,
            name: displayName,
            bundleID: bundleID,
            version: version,
            buildVersion: build,
            size: size,
            lastModified: lastModified,
            lastOpened: lastModified,
            isAppStore: isAppStore,
            isUserApp: isUser,
            sparkleFeedURL: sparkleFeed
        )
    }

    private nonisolated static func readInfoPlist(at appURL: URL) -> [String: Any]? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL) else { return nil }
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) else { return nil }
        return plist as? [String: Any]
    }
}
