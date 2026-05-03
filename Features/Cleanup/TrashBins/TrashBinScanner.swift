import Foundation

actor TrashBinScanner: CleanupScanner {

    let id = "trash_bins"
    let displayName = "Trash Bins"

    private let quarantine: QuarantineService

    init(quarantine: QuarantineService) {
        self.quarantine = quarantine
    }

    func scan() async throws -> [CleanableItem] {
        var items: [CleanableItem] = []

        let userTrash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        items.append(contentsOf: await scanTrash(at: userTrash, label: "User Trash"))

        if let volumes = try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes"),
            includingPropertiesForKeys: nil
        ) {
            for volume in volumes {
                let trashes = volume.appendingPathComponent(".Trashes")
                if FileManager.default.fileExists(atPath: trashes.path) {
                    if let userBins = try? FileManager.default.contentsOfDirectory(
                        at: trashes,
                        includingPropertiesForKeys: nil
                    ) {
                        for bin in userBins {
                            items.append(contentsOf: await scanTrash(at: bin, label: "Trash on \(volume.lastPathComponent)"))
                        }
                    }
                }
            }
        }

        Log.scanner.info("trash scan found \(items.count) items totalling \(items.reduce(Int64(0)) { $0 + $1.size }) bytes")
        return items
    }

    private func scanTrash(at directory: URL, label: String) async -> [CleanableItem] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .contentModificationDateKey,
                .isDirectoryKey,
                .totalFileAllocatedSizeKey,
                .fileSizeKey
            ],
            options: []
        ) else { return [] }

        return await withTaskGroup(of: CleanableItem?.self) { group in
            for url in entries {
                group.addTask {
                    let v = try? url.resourceValues(forKeys: [
                        .isDirectoryKey,
                        .contentModificationDateKey,
                        .totalFileAllocatedSizeKey,
                        .fileSizeKey
                    ])
                    let isDir = v?.isDirectory ?? false
                    let lastMod = v?.contentModificationDate

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
                        category: .trash,
                        safetyLevel: .review,
                        lastModified: lastMod,
                        isDirectory: isDir,
                        title: url.lastPathComponent,
                        description: label,
                        ruleID: nil
                    )
                }
            }
            var all: [CleanableItem] = []
            for await item in group { if let item { all.append(item) } }
            return all
        }
    }

    func clean(_ items: [CleanableItem]) async -> CleanResult {
        let urls = items.map { $0.url }
        let result = await quarantine.directDelete(urls)
        let succeededSet = Set(result.succeeded.map { $0.path })
        let failedMap: [String: String] = Dictionary(uniqueKeysWithValues: result.failed.map { ($0.0.path, $0.1) })

        var removed: [CleanableItem] = []
        var failed: [CleanFailure] = []
        var bytesFreed: Int64 = 0

        for item in items {
            if succeededSet.contains(item.url.path) {
                removed.append(item)
                bytesFreed += item.size
            } else if let reason = failedMap[item.url.path] {
                failed.append(CleanFailure(item: item, reason: reason))
            }
        }

        Log.scanner.info("trash clean: removed=\(removed.count) failed=\(failed.count) bytesFreed=\(bytesFreed)")
        return CleanResult(removed: removed, failed: failed, totalBytesFreed: bytesFreed)
    }
}
