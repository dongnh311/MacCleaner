import Foundation

actor FileSizeCalculator {

    struct Progress: Sendable {
        public let scannedItems: Int
        public let totalBytes: Int64
        public let currentPath: String
    }

    func recursiveSize(at directory: URL) async -> Int64 {
        await Task.detached(priority: .userInitiated) {
            Self.walk(directory: directory).total
        }.value
    }

    nonisolated static func walk(directory: URL) -> (total: Int64, count: Int) {
        var total: Int64 = 0
        var count = 0
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey],
            options: [.skipsHiddenFiles],
            errorHandler: { url, error in
                Log.fs.warning("enumerator error at \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return true
            }
        ) else { return (0, 0) }

        while let item = enumerator.nextObject() as? URL {
            if Task.isCancelled { return (total, count) }
            let v = try? item.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
            total += Int64(v?.totalFileAllocatedSize ?? v?.fileSize ?? 0)
            count += 1
        }
        return (total, count)
    }
}
