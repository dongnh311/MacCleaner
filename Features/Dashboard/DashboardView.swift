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
    @State private var ticking: Bool = false

    private let columns = [
        GridItem(.flexible(minimum: 200), spacing: Spacing.md),
        GridItem(.flexible(minimum: 200), spacing: Spacing.md)
    ]
    private let historyCap = 60

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeader(
                icon: "square.grid.2x2",
                title: "Dashboard",
                subtitle: "Live system metrics — refreshes every second"
            ) {
                Text(ticking ? "● live" : "● paused")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(ticking ? .green : .secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background((ticking ? Color.green : Color.secondary).opacity(0.12))
                    .clipShape(Capsule())
            }

            ScrollView {
                VStack(spacing: Spacing.md) {
                    heroDiskCard
                    LazyVGrid(columns: columns, spacing: Spacing.md) {
                        cpuCard
                        memoryCard
                        if battery.isPresent {
                            batteryCard
                        }
                        healthCard
                    }
                    topProcessesCard
                }
                .padding(Spacing.lg)
            }
        }
        .task {
            ticking = true
            // First sample immediately so the disk + processes appear quickly.
            await refresh()
            // Subsequent samples on a 1s loop. Loop ends when view disappears
            // (Task is cancelled by .task lifecycle).
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                await refresh()
            }
            ticking = false
        }
    }

    // MARK: - Hero Disk Card (full width, with progress ring)

    private var heroDiskCard: some View {
        HStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: disk.totalBytes > 0 ? CGFloat(disk.usedPercent / 100) : 0)
                    .stroke(diskRingColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth, value: disk.usedPercent)
                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", disk.usedPercent))
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .contentTransition(.numericText())
                    Text("used")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 4) {
                Text("STARTUP DISK")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Text(disk.freeBytes.formattedBytes)
                    .font(.system(size: 30, weight: .semibold, design: .monospaced))
                    .contentTransition(.numericText())
                Text("free of \(disk.totalBytes.formattedBytes)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                ProgressView(value: disk.usedPercent, total: 100)
                    .progressViewStyle(.linear)
                    .tint(diskRingColor)
                    .frame(maxWidth: 360)
            }
            Spacer()
        }
        .padding(Spacing.lg)
        .cardStyle()
    }

    private var diskRingColor: Color {
        switch disk.usedPercent {
        case ..<60:  return .green
        case ..<85:  return .orange
        default:     return .red
        }
    }

    // MARK: - CPU

    private var cpuCard: some View {
        StatCard(title: "CPU", icon: "cpu", accent: .teal) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.1f", cpuHistory.last?.usagePercent ?? 0))
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Chart {
                    ForEach(cpuHistory.indices, id: \.self) { i in
                        let s = cpuHistory[i]
                        AreaMark(
                            x: .value("t", i),
                            yStart: .value("min", 0),
                            yEnd: .value("usage", s.usagePercent)
                        )
                        .foregroundStyle(LinearGradient(
                            colors: [Color.teal.opacity(0.5), Color.teal.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .interpolationMethod(.monotone)
                        LineMark(
                            x: .value("t", i),
                            y: .value("usage", s.usagePercent)
                        )
                        .foregroundStyle(Color.teal)
                        .interpolationMethod(.monotone)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 60)
            }
        }
    }

    // MARK: - Memory

    private var memoryCard: some View {
        StatCard(title: "Memory", icon: "memorychip", accent: .purple) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    if let mem = memory {
                        Text(String(format: "%.1f", Double(mem.used) / 1_073_741_824))
                            .font(.system(size: 28, weight: .semibold, design: .monospaced))
                            .contentTransition(.numericText())
                        Text("/ \(String(format: "%.1f", Double(mem.total) / 1_073_741_824)) GB")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("—").font(.system(size: 28, weight: .semibold, design: .monospaced))
                    }
                    Spacer()
                    if let mem = memory {
                        Text(String(format: "%.0f%%", mem.pressurePercent))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                Chart {
                    ForEach(memHistory.indices, id: \.self) { i in
                        let s = memHistory[i]
                        AreaMark(x: .value("t", i), yStart: .value("min", 0), yEnd: .value("p", s.percent))
                            .foregroundStyle(LinearGradient(
                                colors: [Color.purple.opacity(0.5), Color.purple.opacity(0.05)],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .interpolationMethod(.monotone)
                        LineMark(x: .value("t", i), y: .value("p", s.percent))
                            .foregroundStyle(Color.purple)
                            .interpolationMethod(.monotone)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 60)
            }
        }
    }

    // MARK: - Battery

    private var batteryCard: some View {
        StatCard(title: "Battery", icon: battery.isCharging ? "battery.100.bolt" : "battery.75percent", accent: .green) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(battery.percentage)")
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if battery.isCharging {
                        Image(systemName: "bolt.fill").foregroundStyle(.yellow).font(.caption)
                    }
                }
                ProgressView(value: Double(battery.percentage), total: 100)
                    .progressViewStyle(.linear)
                HStack(spacing: 12) {
                    if let h = battery.healthPercent { Text("Capacity \(h)%").font(.caption2).foregroundStyle(.secondary) }
                    if let c = battery.cycleCount { Text("Cycles \(c)").font(.caption2).foregroundStyle(.secondary) }
                }
            }
        }
    }

    // MARK: - Health

    private var healthCard: some View {
        let pressure = memory?.pressurePercent ?? 0
        let cpu = cpuHistory.last?.usagePercent ?? 0
        let isOK = pressure < 80 && cpu < 80
        return StatCard(title: "Health", icon: isOK ? "heart.fill" : "exclamationmark.triangle.fill", accent: isOK ? .pink : .orange) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: isOK ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(isOK ? .green : .orange)
                    Text(isOK ? "Good" : "Under load")
                        .font(.system(size: 22, weight: .semibold))
                }
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 3) {
                    GridRow {
                        Text("CPU").font(.caption).foregroundStyle(.secondary)
                        Text(String(format: "%.1f%%", cpu)).font(.system(.caption, design: .monospaced))
                    }
                    GridRow {
                        Text("Pressure").font(.caption).foregroundStyle(.secondary)
                        Text(String(format: "%.1f%%", pressure)).font(.system(.caption, design: .monospaced))
                    }
                    GridRow {
                        Text("Disk").font(.caption).foregroundStyle(.secondary)
                        Text(String(format: "%.0f%%", disk.usedPercent)).font(.system(.caption, design: .monospaced))
                    }
                    if battery.isPresent {
                        GridRow {
                            Text("Battery").font(.caption).foregroundStyle(.secondary)
                            Text("\(battery.percentage)%").font(.system(.caption, design: .monospaced))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Top Processes

    private var topProcessesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionHeading("Top processes", count: topProcesses.count)
                Spacer()
                Text("by CPU")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                if topProcesses.isEmpty {
                    Text("Loading…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.lg)
                } else {
                    ForEach(Array(topProcesses.prefix(8).enumerated()), id: \.element.id) { (idx, proc) in
                        HStack(spacing: 8) {
                            Text("\(idx + 1)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .frame(width: 18, alignment: .trailing)
                            Text(proc.name)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Text(proc.user)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: "%.1f%%", proc.cpuPercent))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(proc.cpuPercent > 50 ? .red : (proc.cpuPercent > 10 ? .orange : .primary))
                                .frame(width: 60, alignment: .trailing)
                            Text(proc.memoryBytes.formattedBytes)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 6)
                        if idx < min(topProcesses.count - 1, 7) {
                            Divider()
                        }
                    }
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Refresh

    private func refresh() async {
        // Disk + memory + battery are fast (sync or near-instant Mach calls).
        // Run them inline to update the UI immediately.
        disk = container.systemMetrics.sampleDisk()
        memory = await container.memoryService.snapshot()
        battery = await container.batteryService.snapshot()

        // CPU sampling computes a delta from the previous sample, so the very
        // first sample reads as 0% — still useful for kick-starting the chart.
        let cpu = await container.systemMetrics.sampleCPU()
        cpuHistory.append(cpu)
        if cpuHistory.count > historyCap { cpuHistory.removeFirst(cpuHistory.count - historyCap) }
        if let mem = memory {
            memHistory.append((Date(), mem.pressurePercent))
            if memHistory.count > historyCap { memHistory.removeFirst(memHistory.count - historyCap) }
        }

        // Process snapshot shells out to ps — slowest call (~100ms).
        topProcesses = await container.processMonitor.snapshot()
            .sorted { $0.cpuPercent > $1.cpuPercent }
    }
}

// MARK: - StatCard

private struct StatCard<Content: View>: View {
    let title: String
    let icon: String
    let accent: Color
    let content: () -> Content

    init(title: String, icon: String, accent: Color = .accentColor, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.accent = accent
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(accent)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            content()
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Usage Trends

/// Long-window analytics view backed by the `app_usage_hourly` table.
/// Surfaces three insights:
/// - which apps the user actually uses (by total minutes seen)
/// - which background apps are quietly racking up hours (data-risk
///   candidates — they're up but don't have a Dock window)
/// - which apps hold the most RAM on average when running
///
/// Data appears as the AppUsageLogger flushes — first partial flush
/// after ~5 minutes of MacCleaner runtime, full hour after the next
/// hour-roll. The card states cover both empty + ready cases.
@MainActor
struct UsageTrendsView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var days: Int = 7
    @State private var topByPresence: [UsageAggregate] = []
    @State private var topBackground: [UsageAggregate] = []
    @State private var topByMemory: [UsageAggregate] = []
    @State private var lastSeenMap: [String: Int] = [:]
    @State private var installedApps: [InstalledApp] = []
    @State private var loading = false

    private static let ranges: [(label: String, days: Int)] = [
        ("7 days", 7), ("30 days", 30), ("90 days", 90)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeader(
                icon: "chart.line.uptrend.xyaxis",
                title: "Usage Trends",
                subtitle: "Long-window analytics — apps you actually use, background runners, RAM hogs"
            ) {
                Picker("Range", selection: $days) {
                    ForEach(Self.ranges, id: \.days) { Text($0.label).tag($0.days) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
                Button {
                    Task { await load(rescanInstalledApps: true) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(loading)
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    explainer
                    // Two independent columns rather than LazyVGrid so each
                    // card sits flush against the one above — Memory hogs
                    // doesn't get stretched to match Unused apps' height.
                    HStack(alignment: .top, spacing: Spacing.lg) {
                        VStack(spacing: Spacing.lg) {
                            usageCard(title: "Most-used apps",
                                      subtitle: "Total time foreground/background",
                                      symbol: "clock.fill",
                                      tint: .blue,
                                      rows: topByPresence,
                                      metric: .duration)
                            usageCard(title: "Memory hogs (avg)",
                                      subtitle: "Highest avg RAM while running",
                                      symbol: "memorychip",
                                      tint: .pink,
                                      rows: topByMemory,
                                      metric: .memory)
                        }
                        VStack(spacing: Spacing.lg) {
                            usageCard(title: "Background runners",
                                      subtitle: "Hidden / menu-bar apps by uptime",
                                      symbol: "shield.lefthalf.filled",
                                      tint: .orange,
                                      rows: topBackground,
                                      metric: .duration)
                            unusedCard
                        }
                    }
                }
                .padding(Spacing.xl)
            }
        }
        // Auto-refresh every 60s so the latest tick flush is picked up
        // without the user clicking Refresh. Re-keys on `days` so the
        // loop restarts on time-window change. Installed-app scan only
        // runs on first iteration (cheap DB queries on subsequent ticks).
        .task(id: days) {
            var first = true
            while !Task.isCancelled {
                await load(rescanInstalledApps: first)
                first = false
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            }
        }
    }

    private var explainer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text("Stats only count time MacCleaner was running. First samples flush after ~5 minutes; full hours land on the next hour-roll. Old data drops after 90 days.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private enum Metric { case duration, memory }

    @ViewBuilder
    private func usageCard(title: String, subtitle: String, symbol: String,
                           tint: Color, rows: [UsageAggregate], metric: Metric) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: symbol).foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
            if rows.isEmpty {
                Text("No data in this window yet")
                    .font(.caption).foregroundStyle(.tertiary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 4) {
                    ForEach(rows.prefix(8)) { row in
                        usageRow(row, metric: metric, tint: tint)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func usageRow(_ row: UsageAggregate, metric: Metric, tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(row.name).font(.system(size: 12))
                .lineLimit(1).truncationMode(.middle)
            if row.isBackground {
                Text("BG")
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 3).padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.18))
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
            }
            Spacer(minLength: 6)
            Text(metricValue(row, metric: metric))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(tint)
        }
    }

    private func metricValue(_ row: UsageAggregate, metric: Metric) -> String {
        switch metric {
        case .duration:
            let hours = Double(row.totalMinutes) / 60
            if hours < 1 { return "\(row.totalMinutes)m" }
            return String(format: "%.1fh", hours)
        case .memory:
            return row.avgMemoryBytes.formattedBytes
        }
    }

    /// Apps the user has installed but the logger hasn't seen in this
    /// window (or has never seen). Cross-references AppScanner output
    /// against `lastSeenPerApp()` — anything missing OR older than the
    /// cutoff lands here, sorted by how long it's been stale.
    private var unusedCard: some View {
        let cutoff = AppDatabase.currentHour() - days * 24
        let unused: [InstalledApp] = installedApps
            .filter { app in
                guard let bid = app.bundleID, !bid.isEmpty else { return false }
                // Skip MacCleaner itself — it's always running when this view loads.
                if bid == Bundle.main.bundleIdentifier { return false }
                let last = lastSeenMap[bid] ?? 0
                return last < cutoff
            }
            .sorted { (a, b) in
                let la = lastSeenMap[a.bundleID ?? ""] ?? 0
                let lb = lastSeenMap[b.bundleID ?? ""] ?? 0
                return la < lb
            }
            .prefix(8)
            .map { $0 }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "moon.zzz").foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Unused apps").font(.system(size: 13, weight: .semibold))
                    Text("Installed but not seen in this window")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
            if installedApps.isEmpty {
                Text("Scanning installed apps…")
                    .font(.caption).foregroundStyle(.tertiary)
                    .padding(.vertical, 12)
            } else if unused.isEmpty {
                Text("Everything has been used recently 🎉")
                    .font(.caption).foregroundStyle(.tertiary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 4) {
                    ForEach(unused) { app in
                        unusedRow(app)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func unusedRow(_ app: InstalledApp) -> some View {
        let last = lastSeenMap[app.bundleID ?? ""] ?? 0
        let staleness: String = {
            if last == 0 { return "never" }
            let currentHour = AppDatabase.currentHour()
            let hoursAgo = currentHour - last
            if hoursAgo < 24 { return "\(hoursAgo)h ago" }
            return "\(hoursAgo / 24)d ago"
        }()
        return HStack(spacing: 8) {
            Text(app.name).font(.system(size: 12))
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 6)
            Text(staleness)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.purple)
        }
    }

    private func load(rescanInstalledApps: Bool) async {
        loading = true
        // DB queries are cheap; AppScanner walks every .app bundle on
        // disk and is expensive (~tens of thousands of inodes). Only
        // re-scan when the user explicitly hits Refresh or on first
        // mount — the installed-app list barely changes between ticks.
        async let presence = (try? await container.db.topUsageByPresence(days: days, limit: 8, backgroundOnly: false)) ?? []
        async let bg = (try? await container.db.topUsageByPresence(days: days, limit: 8, backgroundOnly: true)) ?? []
        async let memory = (try? await container.db.topUsageByMemory(days: days, limit: 8)) ?? []
        async let lastSeen = (try? await container.db.lastSeenPerApp()) ?? [:]
        if rescanInstalledApps {
            async let apps = container.appScanner.scan()
            installedApps = await apps
        }
        topByPresence = await presence
        topBackground = await bg
        topByMemory = await memory
        lastSeenMap = await lastSeen
        loading = false
    }
}
