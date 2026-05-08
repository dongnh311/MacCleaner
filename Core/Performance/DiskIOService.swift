import Foundation
import IOKit

struct DiskVolume: Identifiable, Sendable, Hashable {
    var id: String { mountPath }
    let name: String
    let mountPath: String
    let bsdName: String?       // e.g. "disk3s1s1" — key for IOReg lookup
    let totalBytes: Int64
    let freeBytes: Int64
    let isInternal: Bool
    let isReadOnly: Bool

    var usedBytes: Int64 { max(0, totalBytes - freeBytes) }
    var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
}

struct DiskIORate: Sendable, Hashable {
    let bsdName: String
    let bytesReadPerSec: UInt64
    let bytesWrittenPerSec: UInt64
}

/// Per-volume disk metrics: free/total via FileManager, I/O via IOKit
/// IOBlockStorageDriver "Statistics" dictionary. The IOBlockStorageDriver
/// service publishes cumulative counters; we diff successive samples to
/// produce per-second rates.
actor DiskIOService {

    private struct CumulativeIO {
        var read: UInt64
        var written: UInt64
        var at: Date
    }

    private var lastSamples: [String: CumulativeIO] = [:]
    private var rateHistoryRead: [String: [Double]] = [:]
    private var rateHistoryWrite: [String: [Double]] = [:]
    private let historyCapacity: Int = 60

    func volumes() -> [DiskVolume] {
        Self.readVolumes()
    }

    /// One sample → one DiskIORate per *whole disk* (BSD `diskN`). Volumes
    /// (`disk3s1s1`) inherit the rate of their parent disk because IOKit
    /// only publishes counters on the block-driver level.
    func sampleRates() -> [DiskIORate] {
        let now = Date()
        let raw = Self.readBlockStorageStats()
        var out: [DiskIORate] = []

        for (bsd, totals) in raw {
            if let prev = lastSamples[bsd] {
                let dt = now.timeIntervalSince(prev.at)
                let read = dt > 0 ? UInt64(Double(totals.read &- prev.read) / dt) : 0
                let write = dt > 0 ? UInt64(Double(totals.written &- prev.written) / dt) : 0
                out.append(DiskIORate(bsdName: bsd, bytesReadPerSec: read, bytesWrittenPerSec: write))

                rateHistoryRead[bsd, default: []].append(Double(read))
                rateHistoryWrite[bsd, default: []].append(Double(write))
                trimHistory(for: bsd)
            }
            lastSamples[bsd] = CumulativeIO(read: totals.read, written: totals.written, at: now)
        }
        return out
    }

    func history(for bsd: String) -> (read: [Double], write: [Double]) {
        let parent = parentDisk(for: bsd)
        return (rateHistoryRead[parent] ?? [], rateHistoryWrite[parent] ?? [])
    }

    private func trimHistory(for bsd: String) {
        if let count = rateHistoryRead[bsd]?.count, count > historyCapacity {
            rateHistoryRead[bsd]?.removeFirst(count - historyCapacity)
        }
        if let count = rateHistoryWrite[bsd]?.count, count > historyCapacity {
            rateHistoryWrite[bsd]?.removeFirst(count - historyCapacity)
        }
    }

    /// Maps a slice BSD name (`disk3s1s1`) to its parent whole-disk
    /// (`disk3`) which is what IOBlockStorageDriver publishes counters on.
    nonisolated func parentDisk(for bsd: String) -> String {
        guard bsd.hasPrefix("disk") else { return bsd }
        let suffix = bsd.dropFirst("disk".count)
        var num = ""
        for ch in suffix {
            if ch.isNumber { num.append(ch) } else { break }
        }
        return "disk" + num
    }

    // MARK: - IORegistry walks

    private nonisolated static func readVolumes() -> [DiskVolume] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsInternalKey,
            .volumeIsReadOnlyKey,
            .volumeURLForRemountingKey
        ]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        var volumes: [DiskVolume] = []
        for url in urls {
            let v = try? url.resourceValues(forKeys: Set(keys))
            guard let total = v?.volumeTotalCapacity, total > 0 else { continue }
            let bsd = bsdName(forMountPath: url.path)
            volumes.append(DiskVolume(
                name: v?.volumeName ?? url.lastPathComponent,
                mountPath: url.path,
                bsdName: bsd,
                totalBytes: Int64(total),
                freeBytes: Int64(v?.volumeAvailableCapacity ?? 0),
                isInternal: v?.volumeIsInternal ?? false,
                isReadOnly: v?.volumeIsReadOnly ?? false
            ))
        }
        return volumes.sorted { lhs, rhs in
            if lhs.isInternal != rhs.isInternal { return lhs.isInternal }
            return lhs.name < rhs.name
        }
    }

    /// Resolve a mount path to its BSD device name via statfs.
    private nonisolated static func bsdName(forMountPath path: String) -> String? {
        var stat = statfs()
        guard statfs(path, &stat) == 0 else { return nil }
        let mn = withUnsafeBytes(of: &stat.f_mntfromname) { raw -> String? in
            guard let base = raw.baseAddress else { return nil }
            return String(cString: base.assumingMemoryBound(to: CChar.self))
        }
        // /dev/disk3s1s1 → disk3s1s1
        guard let mn else { return nil }
        return mn.replacingOccurrences(of: "/dev/", with: "")
    }

    /// Walks IORegistry under IOBlockStorageDriver, returns cumulative
    /// read/write byte counters keyed by parent BSD device (e.g. "disk0").
    private nonisolated static func readBlockStorageStats() -> [String: (read: UInt64, written: UInt64)] {
        var out: [String: (UInt64, UInt64)] = [:]
        let matching = IOServiceMatching("IOBlockStorageDriver")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return out
        }
        defer { IOObjectRelease(iterator) }

        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            var unmanaged: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(entry, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = unmanaged?.takeRetainedValue() as? [String: Any],
                  let stats = dict["Statistics"] as? [String: Any] else { continue }

            let read = (stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
            let written = (stats["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
            // Fish out the BSD name of the parent IOMedia.
            var parent: io_registry_entry_t = 0
            IORegistryEntryGetParentEntry(entry, kIOServicePlane, &parent)
            defer { if parent != 0 { IOObjectRelease(parent) } }
            if parent == 0 { continue }

            var bsdRef: Unmanaged<CFTypeRef>?
            bsdRef = IORegistryEntryCreateCFProperty(parent, "BSD Name" as CFString, kCFAllocatorDefault, 0)
            guard let bsd = bsdRef?.takeRetainedValue() as? String else { continue }

            out[bsd] = (read, written)
        }
        return out
    }
}
