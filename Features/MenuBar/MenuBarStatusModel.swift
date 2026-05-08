import Foundation
import SwiftUI

/// Drives the menu bar label and popover. One 1s tick samples every metric
/// service; views subscribe via @ObservedObject and re-render automatically.
@MainActor
final class MenuBarStatusModel: ObservableObject {

    // CPU
    @Published var cpuPercent: Int = 0
    // Memory
    @Published var memoryPressurePercent: Int = 0
    @Published var memoryFreeBytes: Int64 = 0
    @Published var memoryTotalBytes: Int64 = 0
    // Disk
    @Published var diskFreeBytes: Int64 = 0
    @Published var diskTotalBytes: Int64 = 0
    // Battery
    @Published var batteryPresent: Bool = false
    @Published var batteryPercent: Int = 0
    @Published var batteryCharging: Bool = false
    // Network
    @Published var netInPerSec: UInt64 = 0
    @Published var netOutPerSec: UInt64 = 0
    @Published var netInHistory: [Double] = []
    @Published var netOutHistory: [Double] = []
    @Published var isVPNActive: Bool = false
    // Sensors
    @Published var cpuTemperature: Double? = nil
    @Published var gpuTemperature: Double? = nil
    @Published var fanRPM: Double? = nil
    // GPU
    @Published var gpuPercent: Int = 0
    // Top processes (5-by-CPU, 5-by-RAM)
    @Published var topByCPU: [ProcessSnapshot] = []
    @Published var topByRAM: [ProcessSnapshot] = []
    // CPU history (60-sample rolling buffer, 0–100 each)
    @Published var cpuHistory: [Double] = []
    @Published var perCorePercent: [Double] = []
    // Smart Care derived
    @Published var lastQuickCleanBytes: Int64 = 0

    private let systemMetrics: SystemMetrics
    private let memoryService: MemoryService
    private let batteryService: BatteryService
    private let networkService: NetworkSpeedService
    private let sensorsService: SensorsService
    private let gpuService: GPUStatsService
    private let processMonitor: ProcessMonitor
    private var task: Task<Void, Never>?
    /// Sensors + GPU + processes are sampled at slower cadences than the
    /// 1Hz baseline — SMC reads, IORegistry walks and `ps` forks all cost
    /// real CPU. Counter advances each tick and modulo-tests gate the
    /// expensive samplers.
    private var tickCounter: Int = 0

    init(systemMetrics: SystemMetrics,
         memoryService: MemoryService,
         batteryService: BatteryService,
         networkService: NetworkSpeedService,
         sensorsService: SensorsService,
         gpuService: GPUStatsService,
         processMonitor: ProcessMonitor) {
        self.systemMetrics = systemMetrics
        self.memoryService = memoryService
        self.batteryService = batteryService
        self.networkService = networkService
        self.sensorsService = sensorsService
        self.gpuService = gpuService
        self.processMonitor = processMonitor
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func tick() async {
        tickCounter &+= 1
        let runGPU = (tickCounter % 4 == 0)
        let runSensors = (tickCounter % 4 == 0)
        let runProcesses = (tickCounter % 8 == 0)

        async let cpuTask = systemMetrics.sampleCPU()
        async let memTask = memoryService.snapshot()
        async let battTask = batteryService.snapshot()
        async let netTask = networkService.sampleWithHistory()

        let cpu = await cpuTask
        let mem = await memTask
        let batt = await battTask
        let netResult = await netTask
        let disk = systemMetrics.sampleDisk()
        let history = await systemMetrics.cpuHistory()

        // Change-detection on every published assign — SwiftUI fires an
        // invalidation cascade on @Published writes regardless of whether
        // the value actually changed, so a sleeping app would still
        // recompute the popover every second. The guards short-circuit
        // when the underlying service returned the same value.
        assignIfChanged(\.cpuPercent, Int(cpu.usagePercent.rounded()))
        assignIfChanged(\.perCorePercent, cpu.perCorePercent)
        assignIfChanged(\.cpuHistory, history)
        assignIfChanged(\.memoryPressurePercent, Int(mem.pressurePercent.rounded()))
        assignIfChanged(\.memoryFreeBytes, mem.free + mem.inactive)
        assignIfChanged(\.memoryTotalBytes, mem.total)
        assignIfChanged(\.diskFreeBytes, disk.freeBytes)
        assignIfChanged(\.diskTotalBytes, disk.totalBytes)
        assignIfChanged(\.batteryPresent, batt.isPresent)
        assignIfChanged(\.batteryPercent, batt.percentage)
        assignIfChanged(\.batteryCharging, batt.isCharging)
        assignIfChanged(\.netInPerSec, netResult.sample.bytesInPerSec)
        assignIfChanged(\.netOutPerSec, netResult.sample.bytesOutPerSec)
        assignIfChanged(\.isVPNActive, netResult.sample.isVPNActive)
        assignIfChanged(\.netInHistory, netResult.inHistory)
        assignIfChanged(\.netOutHistory, netResult.outHistory)

        // GPU sampling walks IORegistry — throttle to match sensors instead
        // of paying it on every 1Hz tick.
        if runGPU {
            let gpu = await gpuService.sample()
            assignIfChanged(\.gpuPercent, Int(gpu.utilizationPercent.rounded()))
        }

        if runSensors {
            // One sample → cpu/gpu/fan in a single actor hop instead of three.
            let d = await sensorsService.digest()
            assignIfChanged(\.cpuTemperature, d.cpuTemperature)
            assignIfChanged(\.gpuTemperature, d.gpuTemperature)
            assignIfChanged(\.fanRPM, d.fanRPM)
        }

        var topRSS: Int64 = topByRAM.first?.memoryBytes ?? 0
        var topName: String? = topByRAM.first?.name
        if runProcesses {
            let procs = await processMonitor.snapshot()
            let byCPU = Array(procs.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(5))
            let byRAM = Array(procs.sorted { $0.memoryBytes > $1.memoryBytes }.prefix(5))
            assignIfChanged(\.topByCPU, byCPU)
            assignIfChanged(\.topByRAM, byRAM)
            topRSS = byRAM.first?.memoryBytes ?? 0
            topName = byRAM.first?.name
        }

        // Hand the snapshot to the alert engine — cheap when alerts are off.
        AlertEngine.shared.evaluate(AlertSnapshot(
            cpuPercent: cpuPercent,
            memoryPressurePercent: memoryPressurePercent,
            diskFreeBytes: diskFreeBytes,
            batteryPercent: batteryPercent,
            batteryPresent: batteryPresent,
            cpuTemperature: cpuTemperature,
            fanRPM: fanRPM,
            topProcessRSSBytes: topRSS,
            topProcessName: topName,
            timestamp: Date()
        ))
    }

    /// Writes only when the new value differs from the current one. The
    /// equality check costs one comparison; the SwiftUI invalidation that
    /// `@Published` would otherwise trigger costs an entire view rebuild.
    private func assignIfChanged<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<MenuBarStatusModel, Value>, _ newValue: Value) {
        if self[keyPath: keyPath] != newValue {
            self[keyPath: keyPath] = newValue
        }
    }

    // MARK: - Display helpers

    var diskUsedPercent: Int {
        guard diskTotalBytes > 0 else { return 0 }
        return Int(Double(diskTotalBytes - diskFreeBytes) / Double(diskTotalBytes) * 100)
    }

    /// Compact rate string for a menu-bar label — kept for callers that
    /// reference the static helper. New code should use `UInt64.formattedRate`.
    static func compactRate(_ bytesPerSec: UInt64) -> String {
        bytesPerSec.formattedRate
    }
}
