import SwiftUI
import AppKit

@MainActor
struct MenuBarPopoverView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var memory: MemoryStats?
    @State private var disk: DiskSample = DiskSample(totalBytes: 0, freeBytes: 0)
    @State private var battery: BatteryStats = .empty
    @State private var cpu: CPUSample = CPUSample(usagePercent: 0, timestamp: Date())
    @State private var refreshTimer: Timer?
    @State private var lastSmartCareTotal: Int64?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading
            Divider()
            statsSection
            Divider()
            quickActions
            Divider()
            footer
        }
        .frame(width: 280)
        .onAppear { start() }
        .onDisappear { stop() }
    }

    private var heading: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles").foregroundStyle(.tint)
            Text("MacCleaner").font(.system(size: 13, weight: .semibold))
            Spacer()
            if let total = lastSmartCareTotal, total > 0 {
                Text("\(total.formattedBytes) cleanable")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private var statsSection: some View {
        VStack(spacing: 0) {
            statRow(label: "CPU", value: String(format: "%.0f%%", cpu.usagePercent), icon: "cpu")
            Divider()
            statRow(
                label: "Memory",
                value: memory.map { String(format: "%.1f / %.1f GB", Double($0.used) / 1_073_741_824, Double($0.total) / 1_073_741_824) } ?? "—",
                icon: "memorychip"
            )
            Divider()
            statRow(label: "Disk free", value: disk.freeBytes.formattedBytes, icon: "internaldrive")
            if battery.isPresent {
                Divider()
                statRow(
                    label: "Battery",
                    value: "\(battery.percentage)%\(battery.isCharging ? " ⚡" : "")",
                    icon: "battery.75percent"
                )
            }
        }
    }

    private func statRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(.tint).frame(width: 16)
            Text(label).font(.system(size: 12))
            Spacer()
            Text(value).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
    }

    private var quickActions: some View {
        VStack(spacing: 0) {
            menuButton(title: "Run Smart Care", icon: "sparkles") {
                Task { await runSmartCare() }
            }
            menuButton(title: "Open Activity Monitor", icon: "chart.line.uptrend.xyaxis") {
                if let url = URL(string: "/Applications/Utilities/Activity Monitor.app") {
                    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                }
            }
            menuButton(title: "Open MacCleaner…", icon: "macwindow") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first(where: { $0.contentViewController != nil })?.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func menuButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).frame(width: 16)
                Text(title).font(.system(size: 12))
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12).padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack {
            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")")
                .font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .controlSize(.small)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    // MARK: - Lifecycle

    private func start() {
        Task { await refresh() }
        let timer = Timer(timeInterval: 1.5, repeats: true) { _ in
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
        cpu = await cpuTask
        memory = await memTask
        battery = await battTask
        disk = container.systemMetrics.sampleDisk()
    }

    private func runSmartCare() async {
        let report = await container.smartCareOrchestrator.run()
        lastSmartCareTotal = report.totalCleanableBytes
    }
}
