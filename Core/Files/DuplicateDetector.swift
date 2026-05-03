import Foundation
import CryptoKit

struct DuplicateGroup: Identifiable, Sendable {
    let id: UUID
    let size: Int64
    let files: [FileNode]

    var redundantBytes: Int64 {
        guard files.count > 1 else { return 0 }
        return Int64(files.count - 1) * size
    }
}

actor DuplicateDetector {

    struct Config: Sendable {
        var minBytes: Int64
        var maxBytes: Int64
        var maxFiles: Int

        static let `default` = Config(
            minBytes: 1024,
            maxBytes: 2 * 1024 * 1024 * 1024,
            maxFiles: 50_000
        )
    }

    func findDuplicates(in directory: URL, config: Config = .default) async throws -> [DuplicateGroup] {
        try await Task.detached(priority: .userInitiated) {
            // Stage 1: walk and collect files within size band, grouped by exact size.
            var bySize: [Int64: [FileNode]] = [:]
            var visited = 0

            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles],
                errorHandler: { url, error in
                    Log.fs.warning("DuplicateDetector enum error \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    return true
                }
            ) else {
                throw ScanError.accessDenied(directory)
            }

            while let item = enumerator.nextObject() as? URL {
                if Task.isCancelled { return [] }
                if visited >= config.maxFiles { break }
                let v = try? item.resourceValues(forKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey, .contentModificationDateKey])
                if v?.isDirectory == true { continue }
                let size = Int64(v?.totalFileAllocatedSize ?? v?.fileSize ?? 0)
                if size < config.minBytes || size > config.maxBytes { continue }

                let node = FileNode(
                    id: item,
                    url: item,
                    name: item.lastPathComponent,
                    size: size,
                    isDirectory: false,
                    lastModified: v?.contentModificationDate
                )
                bySize[size, default: []].append(node)
                visited += 1
            }

            // Filter to size groups with >= 2 candidates.
            let candidates = bySize.values.filter { $0.count >= 2 }
            Log.fs.info("DuplicateDetector: \(visited) files visited; \(candidates.count) candidate size-groups")

            // Stage 2: group each size-group by hash of first 4KB.
            var quickHashGroups: [String: [FileNode]] = [:]
            for group in candidates {
                if Task.isCancelled { return [] }
                var byQuickHash: [Data: [FileNode]] = [:]
                for node in group {
                    if let h = DuplicateDetector.quickHash(node.url) {
                        byQuickHash[h, default: []].append(node)
                    }
                }
                for (hash, nodes) in byQuickHash where nodes.count >= 2 {
                    let key = "\(nodes.first?.size ?? 0)-\(hash.base64EncodedString())"
                    quickHashGroups[key] = nodes
                }
            }

            // Stage 3: confirm with full SHA256.
            var confirmed: [DuplicateGroup] = []
            for nodes in quickHashGroups.values {
                if Task.isCancelled { return [] }
                var byFullHash: [Data: [FileNode]] = [:]
                for node in nodes {
                    if let h = DuplicateDetector.fullHash(node.url) {
                        byFullHash[h, default: []].append(node)
                    }
                }
                for (_, dupes) in byFullHash where dupes.count >= 2 {
                    confirmed.append(DuplicateGroup(id: UUID(), size: dupes[0].size, files: dupes))
                }
            }

            confirmed.sort { $0.redundantBytes > $1.redundantBytes }
            Log.fs.info("DuplicateDetector: confirmed \(confirmed.count) duplicate groups")
            return confirmed
        }.value
    }

}

extension DuplicateDetector {

    /// SHA-256 of the first 4 KiB of the file. Cheap triage hash.
    nonisolated static func quickHash(_ url: URL) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 4096) else { return nil }
        return Data(SHA256.hash(data: data))
    }

    /// SHA-256 of the entire file, streamed in 1 MiB chunks.
    nonisolated static func fullHash(_ url: URL) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            do {
                guard let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty else { break }
                hasher.update(data: chunk)
            } catch { return nil }
        }
        return Data(hasher.finalize())
    }
}
