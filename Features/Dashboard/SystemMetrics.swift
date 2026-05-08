import Foundation
import Darwin

struct CPUSample: Sendable, Hashable {
    let usagePercent: Double
    let perCorePercent: [Double]
    let timestamp: Date

    init(usagePercent: Double, perCorePercent: [Double] = [], timestamp: Date = Date()) {
        self.usagePercent = usagePercent
        self.perCorePercent = perCorePercent
        self.timestamp = timestamp
    }
}

struct DiskSample: Sendable, Hashable {
    let totalBytes: Int64
    let freeBytes: Int64
    var usedBytes: Int64 { totalBytes - freeBytes }
    var usedPercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }
}

actor SystemMetrics {

    private var lastCPUTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?
    private var lastPerCoreTicks: [(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)] = []
    /// 60-sample rolling history of total CPU% — drives the popover sparkline.
    private var history: [Double] = []
    private let historyCapacity: Int = 60

    func sampleCPU() -> CPUSample {
        let total = sampleTotalCPU()
        let perCore = samplePerCoreCPU()
        history.append(total)
        if history.count > historyCapacity {
            history.removeFirst(history.count - historyCapacity)
        }
        return CPUSample(usagePercent: total, perCorePercent: perCore, timestamp: Date())
    }

    func cpuHistory() -> [Double] {
        history
    }

    private func sampleTotalCPU() -> Double {
        var info = host_cpu_load_info()
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let user = info.cpu_ticks.0
        let system = info.cpu_ticks.1
        let idle = info.cpu_ticks.2
        let nice = info.cpu_ticks.3

        let cpuPercent: Double
        if let last = lastCPUTicks {
            let dUser = Int64(user) &- Int64(last.user)
            let dSystem = Int64(system) &- Int64(last.system)
            let dIdle = Int64(idle) &- Int64(last.idle)
            let dNice = Int64(nice) &- Int64(last.nice)
            let dTotal = dUser + dSystem + dIdle + dNice
            cpuPercent = dTotal > 0 ? Double(dTotal - dIdle) / Double(dTotal) * 100 : 0
        } else {
            cpuPercent = 0
        }

        lastCPUTicks = (user, system, idle, nice)
        return max(0, min(100, cpuPercent))
    }

    /// Per-core CPU% via `host_processor_info`. First call returns zeros
    /// because we have no prior tick snapshot to diff against — same shape
    /// as the total-CPU implementation above.
    private func samplePerCoreCPU() -> [Double] {
        var cpuCount: natural_t = 0
        var cpuLoad: processor_info_array_t? = nil
        var cpuLoadCount: mach_msg_type_number_t = 0
        let kr = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &cpuLoad,
            &cpuLoadCount
        )
        guard kr == KERN_SUCCESS, let load = cpuLoad else { return [] }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: load)),
                vm_size_t(cpuLoadCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }

        let perCpu = Int(CPU_STATE_MAX)
        var current: [(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)] = []
        var percentages: [Double] = []

        for i in 0..<Int(cpuCount) {
            let base = i * perCpu
            let user = UInt32(bitPattern: load[base + Int(CPU_STATE_USER)])
            let system = UInt32(bitPattern: load[base + Int(CPU_STATE_SYSTEM)])
            let idle = UInt32(bitPattern: load[base + Int(CPU_STATE_IDLE)])
            let nice = UInt32(bitPattern: load[base + Int(CPU_STATE_NICE)])
            current.append((user, system, idle, nice))

            if i < lastPerCoreTicks.count {
                let last = lastPerCoreTicks[i]
                let dUser = Int64(user) &- Int64(last.user)
                let dSystem = Int64(system) &- Int64(last.system)
                let dIdle = Int64(idle) &- Int64(last.idle)
                let dNice = Int64(nice) &- Int64(last.nice)
                let dTotal = dUser + dSystem + dIdle + dNice
                let pct = dTotal > 0 ? Double(dTotal - dIdle) / Double(dTotal) * 100 : 0
                percentages.append(max(0, min(100, pct)))
            } else {
                percentages.append(0)
            }
        }

        lastPerCoreTicks = current
        return percentages
    }

    nonisolated func sampleDisk(at path: String = NSHomeDirectory()) -> DiskSample {
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: path)
        let total = (attrs?[.systemSize] as? NSNumber)?.int64Value ?? 0
        let free = (attrs?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        return DiskSample(totalBytes: total, freeBytes: free)
    }
}
