import Foundation

actor HierarchicalScanner {

    /// Lists immediate children of `directory`, computing recursive sizes for sub-directories
    /// in parallel. Hidden files are skipped. Returns nodes sorted by size desc.
    func listChildren(of directory: URL) async -> [FileNode] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .totalFileAllocatedSizeKey,
                .fileSizeKey,
                .contentModificationDateKey
            ],
            options: [.skipsHiddenFiles]
        ) else {
            Log.fs.warning("HierarchicalScanner: cannot read \(directory.path, privacy: .public)")
            return []
        }

        return await withTaskGroup(of: FileNode?.self) { group in
            for url in urls {
                group.addTask {
                    let v = try? url.resourceValues(forKeys: [
                        .isDirectoryKey,
                        .totalFileAllocatedSizeKey,
                        .fileSizeKey,
                        .contentModificationDateKey
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
                    return FileNode(
                        id: url,
                        url: url,
                        name: url.lastPathComponent,
                        size: size,
                        isDirectory: isDir,
                        lastModified: lastMod
                    )
                }
            }
            var collected: [FileNode] = []
            for await node in group {
                if let node, node.size > 0 { collected.append(node) }
            }
            return collected.sorted { $0.size > $1.size }
        }
    }

    /// Returns the volumes mounted at /Volumes plus the root volume.
    nonisolated func mountedVolumes() -> [URL] {
        var result: [URL] = [URL(fileURLWithPath: "/")]
        if let entries = try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes"),
            includingPropertiesForKeys: nil
        ) {
            result.append(contentsOf: entries)
        }
        return result
    }
}
