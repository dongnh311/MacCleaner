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
    // Smart Care derived
    @Published var lastQuickCleanBytes: Int64 = 0

    private let systemMetrics: SystemMetrics
    private let memoryService: MemoryService
    private let batteryService: BatteryService
    private let networkService: NetworkSpeedService
    private var task: Task<Void, Never>?

    init(systemMetrics: SystemMetrics,
         memoryService: MemoryService,
         batteryService: BatteryService,
         networkService: NetworkSpeedService) {
        self.systemMetrics = systemMetrics
        self.memoryService = memoryService
        self.batteryService = batteryService
        self.networkService = networkService
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

        let cpu = await cpuTask
        let mem = await memTask
        let batt = await battTask
        let net = await netTask
        let disk = systemMetrics.sampleDisk()

        cpuPercent = Int(cpu.usagePercent.rounded())
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
