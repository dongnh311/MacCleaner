import Foundation
import IOKit
import IOKit.ps

struct BatteryStats: Sendable, Hashable {
    let isPresent: Bool
    let percentage: Int
    let isCharging: Bool
    let isPowerAdapterConnected: Bool
    let cycleCount: Int?
    let healthPercent: Int?
    let condition: String?
    let timeToEmptyMinutes: Int?
    let timeToFullMinutes: Int?

    static let empty = BatteryStats(
        isPresent: false, percentage: 0, isCharging: false, isPowerAdapterConnected: false,
        cycleCount: nil, healthPercent: nil, condition: nil, timeToEmptyMinutes: nil, timeToFullMinutes: nil
    )
}

actor BatteryService {

    func snapshot() -> BatteryStats {
        Self.read()
    }

    private nonisolated static func read() -> BatteryStats {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return .empty
        }
        guard let cfArray = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() else {
            return .empty
        }
        let sources = cfArray as Array

        var stats = BatteryStats.empty
        for src in sources {
            let cfTypeSrc = src as CFTypeRef
            guard let descRaw = IOPSGetPowerSourceDescription(blob, cfTypeSrc)?.takeUnretainedValue() else { continue }
            guard let info = descRaw as? [String: Any] else { continue }
            let type = info[kIOPSTypeKey] as? String
            guard type == kIOPSInternalBatteryType else { continue }

            let percent = info[kIOPSCurrentCapacityKey] as? Int ?? 0
            let state = info[kIOPSPowerSourceStateKey] as? String
            let isAC = state == kIOPSACPowerValue
            let isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
            let timeToEmpty = info[kIOPSTimeToEmptyKey] as? Int
            let timeToFull = info[kIOPSTimeToFullChargeKey] as? Int

            stats = BatteryStats(
                isPresent: true,
                percentage: percent,
                isCharging: isCharging,
                isPowerAdapterConnected: isAC,
                cycleCount: nil,
                healthPercent: nil,
                condition: nil,
                timeToEmptyMinutes: (timeToEmpty ?? -1) > 0 ? timeToEmpty : nil,
                timeToFullMinutes: (timeToFull ?? -1) > 0 ? timeToFull : nil
            )
            break
        }

        if stats.isPresent {
            stats = augmentFromIORegistry(stats: stats)
        }
        return stats
    }

    private nonisolated static func augmentFromIORegistry(stats: BatteryStats) -> BatteryStats {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return stats }
        defer { IOObjectRelease(service) }

        func intProp(_ key: String) -> Int? {
            guard let raw = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else { return nil }
            return raw as? Int
        }

        func stringProp(_ key: String) -> String? {
            guard let raw = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else { return nil }
            return raw as? String
        }

        let cycle = intProp("CycleCount")

        let maxCap = intProp("AppleRawMaxCapacity") ?? intProp("MaxCapacity")
        let designCap = intProp("DesignCapacity")
        let health: Int?
        if let m = maxCap, let d = designCap, d > 0 {
            health = (m * 100) / d
        } else {
            health = nil
        }
        let condition = stringProp("BatteryServiceState") ?? stringProp("Condition")

        return BatteryStats(
            isPresent: stats.isPresent,
            percentage: stats.percentage,
            isCharging: stats.isCharging,
            isPowerAdapterConnected: stats.isPowerAdapterConnected,
            cycleCount: cycle,
            healthPercent: health,
            condition: condition,
            timeToEmptyMinutes: stats.timeToEmptyMinutes,
            timeToFullMinutes: stats.timeToFullMinutes
        )
    }
}
