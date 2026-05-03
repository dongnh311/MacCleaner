import Foundation

actor LargeFilesScanner {

    struct Filter: Sendable {
        var minBytes: Int64
        var olderThanDays: Int?
        var maxResults: Int

        static let `default` = Filter(minBytes: 100 * 1024 * 1024, olderThanDays: nil, maxResults: 500)
    }

    func scan(at directory: URL, filter: Filter) async throws -> [FileNode] {
        try await Task.detached(priority: .userInitiated) {
            var results: [FileNode] = []
            let cutoffDate: Date? = filter.olderThanDays.map { Date().addingTimeInterval(-Double($0) * 86_400) }

            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .totalFileAllocatedSizeKey,
                    .fileSizeKey,
                    .contentModificationDateKey
                ],
                options: [.skipsHiddenFiles],
                errorHandler: { url, error in
                    Log.fs.warning("LargeFilesScanner: \(url.path, privacy: .public) — \(error.localizedDescription, privacy: .public)")
                    return true
                }
            ) else {
                throw ScanError.accessDenied(directory)
            }

            while let item = enumerator.nextObject() as? URL {
                if Task.isCancelled { return results }
                let v = try? item.resourceValues(forKeys: [
                    .isDirectoryKey,
                    .totalFileAllocatedSizeKey,
                    .fileSizeKey,
                    .contentModificationDateKey
                ])
                let isDir = v?.isDirectory ?? false
                if isDir { continue }

                let size = Int64(v?.totalFileAllocatedSize ?? v?.fileSize ?? 0)
                guard size >= filter.minBytes else { continue }

                let lastMod = v?.contentModificationDate
                if let cutoffDate, let mod = lastMod, mod >= cutoffDate { continue }

                results.append(FileNode(
                    id: item,
                    url: item,
                    name: item.lastPathComponent,
                    size: size,
                    isDirectory: false,
                    lastModified: lastMod
                ))
            }

            results.sort { $0.size > $1.size }
            if results.count > filter.maxResults {
                results = Array(results.prefix(filter.maxResults))
            }
            return results
        }.value
    }
}
