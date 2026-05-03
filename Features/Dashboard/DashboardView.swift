import SwiftUI
import Charts

@MainActor
struct DashboardView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var cpuHistory: [CPUSample] = []
    @State private var memHistory: [(date: Date, percent: Double)] = []
    @State private var disk: DiskSample = DiskSample(totalBytes: 0, freeBytes: 0)
    @State private var memory: MemoryStats?
    @State private var battery: BatteryStats = .empty
    @State private var topProcesses: [ProcessSnapshot] = []
    @State private var refreshTimer: Timer?

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 12)]
    private let historyCap = 60

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    cpuCard
                    memoryCard
                    diskCard
                    if battery.isPresent {
                        batteryCard
                    }
                    healthCard
                }
                .padding(16)

                topProcessesCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .onAppear { start() }
        .onDisappear { stop() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 28))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dashboard").font(.title2.weight(.semibold))
                Text("Live system metrics").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Cards

    private var cpuCard: some View {
        StatCard(title: "CPU", icon: "cpu") {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: "%.1f%%", cpuHistory.last?.usagePercent ?? 0))
                    .font(.system(size: 26, weight: .semibold, design: .monospaced))
                    .contentTransition(.numericText())
                Chart(cpuHistory, id: \.timestamp) { sample in
                    LineMark(
                        x: .value("t", sample.timestamp),
                        y: .value("usage", sample.usagePercent)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.tint)
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 50)
            }
        }
    }

    private var memoryCard: some View {
        StatCard(title: "Memory", icon: "memorychip") {
            VStack(alignment: .leading, spacing: 8) {
                if let mem = memory {
                    Text(String(format: "%.1f / %.1f GB", Double(mem.used) / 1_073_741_824, Double(mem.total) / 1_073_741_824))
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    Chart(memHistory, id: \.date) { sample in
                        LineMark(x: .value("t", sample.date), y: .value("p", sample.percent))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(.purple)
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 50)
                } else {
                    Text("…").foregroundStyle(.secondary)
                }
            }
        }
    }

    private var diskCard: some View {
        StatCard(title: "Disk", icon: "internaldrive") {
            VStack(alignment: .leading, spacing: 8) {
                Text(disk.freeBytes.formattedBytes)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                Text("free of \(disk.totalBytes.formattedBytes)")
                    .font(.caption).foregroundStyle(.secondary)
                ProgressView(value: disk.usedPercent, total: 100)
                    .progressViewStyle(.linear)
                    .tint(disk.usedPercent > 90 ? .red : (disk.usedPercent > 75 ? .orange : .green))
            }
        }
    }

    private var batteryCard: some View {
        StatCard(title: "Battery", icon: battery.isCharging ? "battery.100.bolt" : "battery.75percent") {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(battery.percentage)%")
                    .font(.system(size: 26, weight: .semibold, design: .monospaced))
                if let h = battery.healthPercent { Text("Capacity \(h)%").font(.caption).foregroundStyle(.secondary) }
                if let c = battery.cycleCount { Text("Cycles \(c)").font(.caption).foregroundStyle(.secondary) }
                ProgressView(value: Double(battery.percentage), total: 100)
                    .progressViewStyle(.linear)
            }
        }
    }

    private var healthCard: some View {
        StatCard(title: "Health", icon: "heart") {
            VStack(alignment: .leading, spacing: 8) {
                let pressure = memory?.pressurePercent ?? 0
                let cpu = cpuHistory.last?.usagePercent ?? 0
                let isOK = pressure < 75 && cpu < 80
                HStack {
                    Image(systemName: isOK ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(isOK ? .green : .orange)
                    Text(isOK ? "Good" : "Under load")
                        .font(.system(size: 22, weight: .semibold))
                }
                Text(String(format: "Pressure %.0f%% • CPU %.0f%%", pressure, cpu))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var topProcessesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TOP PROCESSES").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(topProcesses.prefix(5)) { proc in
                    HStack(spacing: 8) {
                        Text(proc.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Spacer()
                        Text(String(format: "%.1f%%", proc.cpuPercent))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .trailing)
                        Text(proc.memoryBytes.formattedBytes)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .trailing)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    if proc.id != topProcesses.prefix(5).last?.id { Divider() }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Lifecycle

    private func start() {
        Task { await refresh() }
        let timer = Timer(timeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in await refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refresh() async {
        async let cpuTask = container.systemMetrics.sampleCPU()
        async let memTask = container.memoryService.snapshot()
        async let battTask = container.batteryService.snapshot()
        async let procsTask = container.processMonitor.snapshot()
        let cpu = await cpuTask
        let mem = await memTask
        let batt = await battTask
        let procs = await procsTask

        cpuHistory.append(cpu)
        if cpuHistory.count > historyCap { cpuHistory.removeFirst(cpuHistory.count - historyCap) }
        memHistory.append((Date(), mem.pressurePercent))
        if memHistory.count > historyCap { memHistory.removeFirst(memHistory.count - historyCap) }
        memory = mem
        battery = batt
        topProcesses = procs.sorted { $0.cpuPercent > $1.cpuPercent }
        disk = container.systemMetrics.sampleDisk()
    }
}

private struct StatCard<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content

    init(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(.tint)
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
