import Foundation
import Darwin

struct CPUSample: Sendable, Hashable {
    let usagePercent: Double
    let timestamp: Date
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

    func sampleCPU() -> CPUSample {
        var info = host_cpu_load_info()
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else {
            return CPUSample(usagePercent: 0, timestamp: Date())
        }

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
        return CPUSample(usagePercent: max(0, min(100, cpuPercent)), timestamp: Date())
    }

    nonisolated func sampleDisk(at path: String = NSHomeDirectory()) -> DiskSample {
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: path)
        let total = (attrs?[.systemSize] as? NSNumber)?.int64Value ?? 0
        let free = (attrs?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        return DiskSample(totalBytes: total, freeBytes: free)
    }
}
