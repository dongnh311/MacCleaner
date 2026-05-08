import Foundation
import IOKit

/// One snapshot of GPU activity. Apple Silicon exposes utilisation as an
/// integer percent in the `Device Utilization %` slot of AGXAccelerator's
/// PerformanceStatistics dictionary; Intel Macs publish similar numbers
/// under the older IOAccelerator class. Either way it's a public IORegistry
/// read — no private framework, no sudo.
struct GPUSample: Sendable, Hashable {
    let utilizationPercent: Double
    let rendererUtilizationPercent: Double?
    let tilerUtilizationPercent: Double?
    let timestamp: Date

    static let zero = GPUSample(
        utilizationPercent: 0,
        rendererUtilizationPercent: nil,
        tilerUtilizationPercent: nil,
        timestamp: .distantPast
    )
}

actor GPUStatsService {

    /// Reads PerformanceStatistics from the first matching GPU service.
    /// Returns `.zero` (timestamp = distantPast) on machines without an
    /// addressable accelerator (rare, mostly VMs).
    func sample() -> GPUSample {
        Self.read()
    }

    private nonisolated static func read() -> GPUSample {
        // AGXAccelerator covers M-series; IOAccelerator covers Intel + AMD.
        let candidates = ["AGXAccelerator", "IOAccelerator"]
        for serviceName in candidates {
            guard let stats = perfStats(for: serviceName) else { continue }
            let util = doubleValue(stats, keys: ["Device Utilization %", "GPU Activity(%)"]) ?? 0
            let renderer = doubleValue(stats, keys: ["Renderer Utilization %"])
            let tiler = doubleValue(stats, keys: ["Tiler Utilization %"])
            return GPUSample(
                utilizationPercent: util,
                rendererUtilizationPercent: renderer,
                tilerUtilizationPercent: tiler,
                timestamp: Date()
            )
        }
        return .zero
    }

    /// Walks the IORegistry, finds the first matching service, returns its
    /// PerformanceStatistics dictionary if present.
    private nonisolated static func perfStats(for ioClass: String) -> [String: Any]? {
        let matching = IOServiceMatching(ioClass)
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            var unmanaged: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(entry, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = unmanaged?.takeRetainedValue() as? [String: Any] else { continue }

            if let perf = dict["PerformanceStatistics"] as? [String: Any] {
                return perf
            }
        }
        return nil
    }

    /// First key in `keys` whose value coerces to Double. PerformanceStatistics
    /// values come back as NSNumber on macOS — direct cast works.
    private nonisolated static func doubleValue(_ stats: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let n = stats[key] as? NSNumber { return n.doubleValue }
        }
        return nil
    }
}
