import Foundation

actor RuleEngine {

    private(set) var systemJunkRules: [CleanupRule] = []

    func loadSystemJunkRules() throws {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "system_junk", withExtension: "json"),
            Bundle.main.url(forResource: "system_junk", withExtension: "json", subdirectory: "CleanupRules"),
            Bundle.main.url(forResource: "system_junk", withExtension: "json", subdirectory: "Resources/CleanupRules")
        ]
        guard let url = candidates.compactMap({ $0 }).first else {
            throw ScanError.ruleLoadFailed("system_junk.json not found in bundle")
        }

        let data = try Data(contentsOf: url)
        let set = try JSONDecoder().decode(RuleSet.self, from: data)
        self.systemJunkRules = set.rules
        Log.scanner.info("Loaded \(set.rules.count) system junk rules from \(url.lastPathComponent, privacy: .public)")
    }

    func scanRule(_ rule: CleanupRule) async -> [CleanableItem] {
        var items: [CleanableItem] = []
        for path in rule.paths {
            let expanded = (path as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded).standardizedFileURL

            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            guard !WhitelistGuard.isScanRootProtected(url) else {
                Log.scanner.warning("rule \(rule.id, privacy: .public) targets protected path \(url.path, privacy: .public), skipping")
                continue
            }

            switch rule.mode {
            case .eachChildAsItem:
                items.append(contentsOf: await scanChildren(of: url, rule: rule))
            case .wholePathAsItem:
                if let item = await makeItem(for: url, rule: rule) {
                    items.append(item)
                }
            }
        }
        return items
    }

    private func scanChildren(of directory: URL, rule: CleanupRule) async -> [CleanableItem] {
        let childUrls: [URL]
        do {
            childUrls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            Log.scanner.warning("contentsOfDirectory failed at \(directory.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return []
        }

        let exclusionSet: Set<String> = Set(
            (rule.exclusions ?? []).map { ($0 as NSString).expandingTildeInPath }
        )

        let filtered = childUrls.filter { url in
            !exclusionSet.contains(url.path) && !WhitelistGuard.isProtected(url)
        }

        return await withTaskGroup(of: CleanableItem?.self) { group in
            for url in filtered {
                group.addTask { [self] in
                    await self.makeItem(for: url, rule: rule)
                }
            }
            var collected: [CleanableItem] = []
            for await item in group {
                if let item { collected.append(item) }
            }
            return collected
        }
    }

    private func makeItem(for url: URL, rule: CleanupRule) async -> CleanableItem? {
        let v = try? url.resourceValues(forKeys: [
            .isDirectoryKey,
            .contentModificationDateKey,
            .totalFileAllocatedSizeKey,
            .fileSizeKey
        ])
        let isDir = v?.isDirectory ?? false
        let lastModified = v?.contentModificationDate

        if let minDays = rule.minimumAgeDays, let lastMod = lastModified {
            let ageSeconds = Date().timeIntervalSince(lastMod)
            if ageSeconds < TimeInterval(minDays) * 86_400 {
                return nil
            }
        }

        let size: Int64
        if isDir {
            size = await Task.detached(priority: .userInitiated) {
                FileSizeCalculator.walk(directory: url).total
            }.value
        } else {
            size = Int64(v?.totalFileAllocatedSize ?? v?.fileSize ?? 0)
        }

        guard size > 0 else { return nil }

        return CleanableItem(
            id: UUID(),
            url: url,
            size: size,
            category: rule.category,
            safetyLevel: rule.safetyLevel,
            lastModified: lastModified,
            isDirectory: isDir,
            title: url.lastPathComponent,
            description: rule.name,
            ruleID: rule.id
        )
    }
}
