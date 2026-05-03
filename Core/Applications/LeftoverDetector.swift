import Foundation

actor LeftoverDetector {

    func detect(for app: InstalledApp) async -> [AppLeftover] {
        guard let bundleID = app.bundleID, !bundleID.isEmpty else { return [] }

        let candidates = candidatePaths(bundleID: bundleID)
        return await withTaskGroup(of: AppLeftover?.self) { group in
            for (kind, path) in candidates {
                group.addTask {
                    await Self.makeLeftover(at: path, kind: kind)
                }
            }
            var results: [AppLeftover] = []
            for await leftover in group {
                if let leftover { results.append(leftover) }
            }
            return results.sorted { $0.size > $1.size }
        }
    }

    private nonisolated static func makeLeftover(at path: String, kind: AppLeftover.Kind) async -> AppLeftover? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let url = URL(fileURLWithPath: path)

        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)

        let size: Int64
        if isDir.boolValue {
            size = await Task.detached(priority: .background) {
                FileSizeCalculator.walk(directory: url).total
            }.value
        } else {
            let v = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
            size = Int64(v?.totalFileAllocatedSize ?? v?.fileSize ?? 0)
        }
        guard size > 0 else { return nil }

        return AppLeftover(id: url, url: url, kind: kind, size: size)
    }

    private nonisolated func candidatePaths(bundleID: String) -> [(AppLeftover.Kind, String)] {
        let home = NSHomeDirectory()
        var out: [(AppLeftover.Kind, String)] = [
            (.applicationSupport, "\(home)/Library/Application Support/\(bundleID)"),
            (.caches,             "\(home)/Library/Caches/\(bundleID)"),
            (.preferences,        "\(home)/Library/Preferences/\(bundleID).plist"),
            (.logs,               "\(home)/Library/Logs/\(bundleID)"),
            (.savedState,         "\(home)/Library/Saved Application State/\(bundleID).savedState"),
            (.containers,         "\(home)/Library/Containers/\(bundleID)"),
            (.groupContainers,    "\(home)/Library/Group Containers/group.\(bundleID)"),
            (.httpStorages,       "\(home)/Library/HTTPStorages/\(bundleID)"),
            (.webKit,             "\(home)/Library/WebKit/\(bundleID)")
        ]

        for prefix in ["LaunchAgents", "LaunchDaemons"] {
            let full = "\(home)/Library/\(prefix)/\(bundleID).plist"
            out.append((.launchAgents, full))
        }

        return out
    }
}
