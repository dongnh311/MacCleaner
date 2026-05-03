import Foundation
@preconcurrency import Vision
import AppKit

struct PhotoCluster: Identifiable, Sendable {
    let id: UUID
    let photos: [FileNode]

    var totalBytes: Int64 { photos.reduce(0) { $0 + $1.size } }
    var redundantBytes: Int64 {
        guard photos.count > 1 else { return 0 }
        return totalBytes - (photos.first?.size ?? 0)
    }
}

actor ImageSimilarity {

    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif",
        "gif", "bmp", "webp", "raw", "cr2", "arw", "nef", "dng"
    ]

    struct Config: Sendable {
        var distanceThreshold: Float
        var maxImages: Int

        static let `default` = Config(distanceThreshold: 12.0, maxImages: 5_000)
    }

    func findClusters(in directory: URL, config: Config = .default) async throws -> [PhotoCluster] {
        let imageNodes = try await Task.detached(priority: .userInitiated) {
            try Self.collectImageNodes(at: directory, max: config.maxImages)
        }.value

        Log.fs.info("ImageSimilarity: collected \(imageNodes.count) images")
        guard imageNodes.count >= 2 else { return [] }

        // Compute feature prints in parallel (bounded).
        let prints = await computePrints(for: imageNodes)
        guard prints.count >= 2 else { return [] }

        // O(n²) clustering: union-find with distance threshold.
        let clusters = cluster(prints: prints, threshold: config.distanceThreshold)
        Log.fs.info("ImageSimilarity: \(clusters.count) clusters with >= 2 photos")
        return clusters
    }

    private nonisolated static func collectImageNodes(at directory: URL, max: Int) throws -> [FileNode] {
        var results: [FileNode] = []
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            throw ScanError.accessDenied(directory)
        }

        while let item = enumerator.nextObject() as? URL {
            if Task.isCancelled { return results }
            if results.count >= max { break }
            let ext = item.pathExtension.lowercased()
            guard imageExtensions.contains(ext) else { continue }
            let v = try? item.resourceValues(forKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey, .contentModificationDateKey])
            if v?.isDirectory == true { continue }
            let size = Int64(v?.totalFileAllocatedSize ?? v?.fileSize ?? 0)
            guard size > 1024 else { continue }
            results.append(FileNode(
                id: item,
                url: item,
                name: item.lastPathComponent,
                size: size,
                isDirectory: false,
                lastModified: v?.contentModificationDate
            ))
        }
        return results
    }

    private struct PrintedNode: Sendable {
        let node: FileNode
        let observation: VNFeaturePrintObservation
    }

    private func computePrints(for nodes: [FileNode]) async -> [PrintedNode] {
        await withTaskGroup(of: PrintedNode?.self) { group in
            let maxConcurrent = max(2, ProcessInfo.processInfo.activeProcessorCount - 1)
            var inFlight = 0
            var iter = nodes.makeIterator()

            func next() -> FileNode? { iter.next() }

            while inFlight < maxConcurrent, let node = next() {
                inFlight += 1
                group.addTask { Self.featurePrint(for: node) }
            }

            var results: [PrintedNode] = []
            while let printed = await group.next() {
                if let printed { results.append(printed) }
                if let node = next() {
                    group.addTask { Self.featurePrint(for: node) }
                } else {
                    inFlight -= 1
                }
            }
            return results
        }
    }

    private nonisolated static func featurePrint(for node: FileNode) -> PrintedNode? {
        let request = VNGenerateImageFeaturePrintRequest()
        request.usesCPUOnly = false
        let handler = VNImageRequestHandler(url: node.url, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first as? VNFeaturePrintObservation else {
                return nil
            }
            return PrintedNode(node: node, observation: observation)
        } catch {
            Log.fs.warning("featurePrint failed for \(node.url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func cluster(prints: [PrintedNode], threshold: Float) -> [PhotoCluster] {
        var parent = Array(0..<prints.count)

        func find(_ x: Int) -> Int {
            var r = x
            while parent[r] != r { r = parent[r] }
            var i = x
            while parent[i] != r {
                let next = parent[i]
                parent[i] = r
                i = next
            }
            return r
        }

        func union(_ a: Int, _ b: Int) {
            let ra = find(a), rb = find(b)
            if ra != rb { parent[ra] = rb }
        }

        for i in 0..<prints.count {
            for j in (i + 1)..<prints.count {
                var distance: Float = .infinity
                do {
                    try prints[i].observation.computeDistance(&distance, to: prints[j].observation)
                } catch { continue }
                if distance <= threshold {
                    union(i, j)
                }
            }
        }

        var groups: [Int: [FileNode]] = [:]
        for i in 0..<prints.count {
            let root = find(i)
            groups[root, default: []].append(prints[i].node)
        }

        return groups.values
            .filter { $0.count >= 2 }
            .map { PhotoCluster(id: UUID(), photos: $0.sorted { $0.size > $1.size }) }
            .sorted { $0.redundantBytes > $1.redundantBytes }
    }
}
