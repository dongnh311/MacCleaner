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
    /// Top-process snapshot used by AlertEngine — only refreshed every 8 ticks
    /// because /bin/ps isn't free.
    private var lastTopProcess: (rss: Int64, name: String?) = (0, nil)
    /// Sensors are sampled every 4th tick (~4s) — SMC reads aren't free.
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
        async let cpuTask = systemMetrics.sampleCPU()
        async let memTask = memoryService.snapshot()
        async let battTask = batteryService.snapshot()
        async let netTask = networkService.sample()
        async let gpuTask = gpuService.sample()

        let cpu = await cpuTask
        let mem = await memTask
        let batt = await battTask
        let net = await netTask
        let gpu = await gpuTask
        let disk = systemMetrics.sampleDisk()
        let history = await systemMetrics.cpuHistory()

        cpuPercent = Int(cpu.usagePercent.rounded())
        cpuHistory = history
        perCorePercent = cpu.perCorePercent
        gpuPercent = Int(gpu.utilizationPercent.rounded())
        memoryPressurePercent = Int(mem.pressurePercent.rounded())
        memoryFreeBytes = mem.free + mem.inactive
        memoryTotalBytes = mem.total
        diskFreeBytes = disk.freeBytes
        diskTotalBytes = disk.totalBytes
        batteryPresent = batt.isPresent
        batteryPercent = batt.percentage
        batteryCharging = batt.isCharging
        netInPerSec = net.bytesInPerSec
        netOutPerSec = net.bytesOutPerSec
        isVPNActive = net.isVPNActive
        let netHist = await networkService.history()
        netInHistory = netHist.inHistory
        netOutHistory = netHist.outHistory

        tickCounter &+= 1
        if tickCounter % 4 == 0 {
            async let cpuTempT = sensorsService.cpuTemperature()
            async let gpuTempT = sensorsService.gpuTemperature()
            async let fanT = sensorsService.fanRPM()
            cpuTemperature = await cpuTempT
            gpuTemperature = await gpuTempT
            fanRPM = await fanT
        }
        if tickCounter % 8 == 0 {
            let procs = await processMonitor.snapshot()
            if let top = procs.max(by: { $0.memoryBytes < $1.memoryBytes }) {
                lastTopProcess = (top.memoryBytes, top.name)
            }
            topByCPU = Array(procs.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(5))
            topByRAM = Array(procs.sorted { $0.memoryBytes > $1.memoryBytes }.prefix(5))
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
            topProcessRSSBytes: lastTopProcess.rss,
            topProcessName: lastTopProcess.name,
            timestamp: Date()
        ))
    }

    // MARK: - Display helpers

    var diskUsedPercent: Int {
        guard diskTotalBytes > 0 else { return 0 }
        return Int(Double(diskTotalBytes - diskFreeBytes) / Double(diskTotalBytes) * 100)
    }

    /// Compact rate string for a menu-bar label: "0", "47K", "1.2M".
    static func compactRate(_ bytesPerSec: UInt64) -> String {
        let v = Double(bytesPerSec)
        if v < 1024 { return "0" }
        if v < 1024 * 1024 { return "\(Int(v / 1024))K" }
        let mb = v / (1024 * 1024)
        return mb < 10 ? String(format: "%.1fM", mb) : "\(Int(mb))M"
    }
}
