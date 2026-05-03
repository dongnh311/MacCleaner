import Foundation

// `actor` is Swift's answer to data races: every method that mutates state
// must be called via `await`, and the runtime serialises access. No manual
// Mutex / @Synchronized like in Kotlin.
//
// We don't actually keep mutable state here yet — but using an actor sets
// the pattern for later (e.g., caching scan results across calls).
actor FileScanner {

    enum ScanError: Error, LocalizedError {
        case accessDenied(URL)
        var errorDescription: String? {
            switch self {
            case .accessDenied(let url):
                return "No permission to read \(url.path). Grant Full Disk Access in System Settings."
            }
        }
    }

    /// Lists immediate contents of `directory`, computing sizes (recursive for sub-folders).
    /// `async throws` is the rough equivalent of Kotlin `suspend fun ...: T` + checked exceptions.
    func listDirectory(_ directory: URL) async throws -> [FileEntry] {
        let keys: [URLResourceKey] = [.isDirectoryKey,
                                       .contentModificationDateKey,
                                       .totalFileAllocatedSizeKey,
                                       .fileSizeKey]
        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            )
        } catch CocoaError.fileReadNoPermission {
            throw ScanError.accessDenied(directory)
        }

        // Parallel size computation. `withThrowingTaskGroup` is structured concurrency:
        // if any child throws, the group cancels remaining tasks and propagates.
        // Conceptually identical to Kotlin's `coroutineScope { async { ... } }` pattern.
        return try await withThrowingTaskGroup(of: FileEntry.self) { group in
            for url in urls {
                group.addTask {
                    try await Self.makeEntry(for: url)
                }
            }
            var result: [FileEntry] = []
            result.reserveCapacity(urls.count)
            for try await entry in group { result.append(entry) }
            return result
        }
    }

    // `static` here = type-level function, callable without an actor instance.
    // Marked `nonisolated` implicitly because it's static and takes no actor state.
    private static func makeEntry(for url: URL) async throws -> FileEntry {
        let v = try url.resourceValues(forKeys: [.isDirectoryKey,
                                                  .contentModificationDateKey,
                                                  .totalFileAllocatedSizeKey,
                                                  .fileSizeKey])
        let isDir = v.isDirectory ?? false
        let modified = v.contentModificationDate ?? .distantPast

        let size: Int64
        if isDir {
            size = await directorySize(at: url)
        } else {
            size = Int64(v.totalFileAllocatedSize ?? v.fileSize ?? 0)
        }

        return FileEntry(id: url, name: url.lastPathComponent,
                         size: size, modified: modified, isDirectory: isDir)
    }

    /// Recursive directory size walk. Run on a detached task so we don't tie
    /// up the actor's serial executor with a long blocking enumeration.
    private static func directorySize(at directory: URL) async -> Int64 {
        await Task.detached(priority: .userInitiated) {
            var total: Int64 = 0
            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey],
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }   // skip unreadable items, keep going
            ) else { return 0 }

            while let item = enumerator.nextObject() as? URL {
                if Task.isCancelled { return total }
                let v = try? item.resourceValues(forKeys: [.totalFileAllocatedSizeKey,
                                                            .fileSizeKey])
                total += Int64(v?.totalFileAllocatedSize ?? v?.fileSize ?? 0)
            }
            return total
        }.value
    }
}
