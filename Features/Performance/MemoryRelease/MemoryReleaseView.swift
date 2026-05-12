import SwiftUI
import AppKit

@MainActor
struct MemoryReleaseView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var stats: MemoryStats?
    @State private var pressureHistory: [Double] = []
    @State private var topProcesses: [ProcessSnapshot] = []
    @State private var sortKey: SortKey = .memory
    @State private var isPaused = false

    /// Performance section accent (#64D2FF) — matches `SidebarItem.section.performance.accent`.
    private static let accent = Color(red: 0.392, green: 0.824, blue: 1.0)
    /// 48 samples × 1.5s refresh = ~72s of pressure history. Enough to
    /// see a recent spike, short enough that the line stays readable.
    private static let historyCapacity = 48

    enum SortKey: Hashable { case memory, cpu }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                if let stats {
                    VStack(spacing: Spacing.md) {
                        pressureCard(stats)
                        tileGrid(stats)
                        allocationBar(stats)
                        topProcessesSection
                    }
                    .padding(Spacing.lg)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
        }
        .refreshTask(every: 1.5) { await refresh() }
    }

    // MARK: - Header

    private var header: some View {
        ModuleHeader(
            icon: "memorychip",
            title: "Memory",
            subtitle: subtitleText,
            accent: Self.accent
        ) {
            Button {
                isPaused.toggle()
            } label: {
                Label(isPaused ? "Resume" : "Pause",
                      systemImage: isPaused ? "play.fill" : "pause.fill")
            }
            .help(isPaused ? "Resume live updates" : "Pause live updates")

            Button {
                let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            } label: {
                Label("Activity Monitor", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.borderedProminent)
            .help("macOS auto-manages memory pressure; `sudo purge` requires admin")
        }
    }

    private var subtitleText: String {
        guard let stats else { return "Live RAM breakdown via host_statistics64" }
        return "\(stats.total.formattedBytes) unified · \(isPaused ? "paused" : "live")"
    }

    // MARK: - Pressure card (sparkline)

    private func pressureCard(_ stats: MemoryStats) -> some View {
        let (tint, label) = pressureLabel(stats.pressurePercent)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                SectionHeading("Pressure")
                Spacer()
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(tint)
            }
            SparklineView(values: pressureHistory, tint: tint, fill: true, maxValue: 100)
                .frame(height: 60)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(withShadow: false)
    }

    private func pressureLabel(_ pct: Double) -> (Color, String) {
        if pct < 60 { return (.green, "Green — plenty available") }
        if pct < 85 { return (.orange, "Yellow — apps may swap to disk") }
        return (.red, "Red — heavy pressure")
    }

    // MARK: - Tile grid

    private func tileGrid(_ stats: MemoryStats) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.md), count: 5),
            spacing: Spacing.md
        ) {
            memoryTile("App memory", value: stats.appMemory, swatch: AllocationColor.app)
            memoryTile("Wired", value: stats.wired, swatch: AllocationColor.wired)
            memoryTile("Compressed", value: stats.compressed, swatch: AllocationColor.compressed)
            memoryTile("Cached files", value: stats.inactive, swatch: AllocationColor.cached)
            memoryTile("Free", value: stats.free, swatch: AllocationColor.free)
        }
    }

    private func memoryTile(_ label: String, value: Int64, swatch: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(swatch)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Text(value.formattedBytes)
                .font(.system(size: 17, weight: .medium, design: .monospaced))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .cardStyle(withShadow: false)
    }

    // MARK: - Allocation bar

    private func allocationBar(_ stats: MemoryStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeading("Allocation · \(stats.total.formattedBytes) total")
            GeometryReader { geo in
                let w = geo.size.width
                HStack(spacing: 0) {
                    AllocationColor.app.frame(width: w * ratio(stats.appMemory, stats.total))
                    AllocationColor.wired.frame(width: w * ratio(stats.wired, stats.total))
                    AllocationColor.compressed.frame(width: w * ratio(stats.compressed, stats.total))
                    AllocationColor.cached.frame(width: w * ratio(stats.inactive, stats.total))
                    Color.white.opacity(0.10)
                }
            }
            .frame(height: 22)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        }
    }

    // MARK: - Top processes

    private var topProcessesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                SectionHeading("Top processes", count: min(topProcesses.count, 10))
                Spacer()
                chip("By memory", active: sortKey == .memory) { sortKey = .memory }
                chip("By CPU", active: sortKey == .cpu) { sortKey = .cpu }
            }
            VStack(spacing: 0) {
                processHeaderRow
                Divider()
                ForEach(sortedProcesses) { proc in
                    processRow(proc)
                    if proc.id != sortedProcesses.last?.id {
                        Divider()
                    }
                }
            }
            .cardStyle(withShadow: false)
        }
    }

    private var sortedProcesses: [ProcessSnapshot] {
        let sorted: [ProcessSnapshot]
        switch sortKey {
        case .memory: sorted = topProcesses.sorted { $0.memoryBytes > $1.memoryBytes }
        case .cpu:    sorted = topProcesses.sorted { $0.cpuPercent > $1.cpuPercent }
        }
        return Array(sorted.prefix(10))
    }

    private var processHeaderRow: some View {
        HStack(spacing: Spacing.md) {
            Color.clear.frame(width: 14)
            Text("PROCESS")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("PID")
                .frame(width: 70, alignment: .trailing)
            Text("CPU")
                .frame(width: 70, alignment: .trailing)
            Text("MEMORY")
                .frame(width: 90, alignment: .trailing)
            Color.clear.frame(width: 20)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.tertiary)
        .tracking(0.5)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private func processRow(_ p: ProcessSnapshot) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "cpu")
                .font(.system(size: 11))
                .foregroundStyle(Self.accent)
                .frame(width: 14)
            Text(p.name)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(p.pid)")
                .font(.system(size: 12, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(String(format: "%.0f%%", p.cpuPercent))
                .font(.system(size: 12, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(p.cpuPercent > 60 ? .orange : .secondary)
                .frame(width: 70, alignment: .trailing)
            Text(p.memoryBytes.formattedBytes)
                .font(.system(size: 12, design: .monospaced))
                .monospacedDigit()
                .frame(width: 90, alignment: .trailing)
            KillProcessButton {
                Task { _ = await container.processMonitor.kill(pid: p.pid, force: false) }
            }
            .frame(width: 20)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private func chip(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(active ? Self.accent.opacity(0.22) : Color.white.opacity(0.04))
                .foregroundStyle(active ? Self.accent : .secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Refresh

    private func refresh() async {
        guard !isPaused else { return }
        let s = await container.memoryService.snapshot()
        stats = s
        pressureHistory.append(s.pressurePercent)
        if pressureHistory.count > Self.historyCapacity {
            pressureHistory.removeFirst(pressureHistory.count - Self.historyCapacity)
        }
        topProcesses = await container.processMonitor.snapshot()
    }

    private func ratio(_ part: Int64, _ total: Int64) -> CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(part) / CGFloat(total)
    }
}

/// SIGTERM trigger — destructive red on hover so the kill intent reads
/// without making the row chrome too busy at rest.
private struct KillProcessButton: View {
    let action: () -> Void
    var body: some View {
        HoverIconButton(
            icon: "xmark.circle.fill",
            size: 14,
            idleColor: .secondary,
            hoverColor: .red,
            help: "Quit (SIGTERM)",
            action: action
        )
    }
}

/// Per-allocation palette from the design system. Shared between the
/// 5-tile grid and the segmented allocation bar.
private enum AllocationColor {
    static let app        = Color(red: 0.353, green: 0.690, blue: 1.000)   // #5AB0FF
    static let wired      = Color(red: 1.000, green: 0.624, blue: 0.039)   // #FF9F0A
    static let compressed = Color(red: 1.000, green: 0.271, blue: 0.227)   // #FF453A
    static let cached     = Color(red: 0.188, green: 0.820, blue: 0.345)   // #30D158
    static let free       = Color(red: 0.557, green: 0.553, blue: 0.937)   // #8E8DEF
}
