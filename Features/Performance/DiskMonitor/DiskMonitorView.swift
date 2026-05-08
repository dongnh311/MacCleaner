import SwiftUI

@MainActor
struct DiskMonitorView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var volumes: [DiskVolume] = []
    @State private var rates: [String: DiskIORate] = [:]
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .onAppear { start() }
        .onDisappear { stop() }
    }

    private var header: some View {
        ModuleHeader(
            icon: "internaldrive",
            title: "Disk Monitor",
            subtitle: "Per-volume free/used + live read/write throughput"
        ) {
            Button { Task { await refresh() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if volumes.isEmpty {
            VStack {
                Spacer()
                ProgressView()
                Text("Reading volumes…").foregroundStyle(.secondary).padding(.top, 8)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    ForEach(volumes) { volume in
                        volumeCard(volume)
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }

    private func volumeCard(_ volume: DiskVolume) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: volume.isInternal ? "internaldrive" : "externaldrive")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(volume.name).font(.system(size: 15, weight: .semibold))
                    HStack(spacing: 4) {
                        Text(volume.mountPath).font(.system(size: 10, design: .monospaced))
                        if let bsd = volume.bsdName {
                            Text("·").foregroundStyle(.tertiary)
                            Text(bsd).font(.system(size: 10, design: .monospaced))
                        }
                        if volume.isReadOnly {
                            Text("RO").font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Color.orange.opacity(0.15))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text(Int64(volume.freeBytes).formattedBytes + " free")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: volume.usedFraction, total: 1)
                .progressViewStyle(.linear)
                .tint(volume.usedFraction > 0.9 ? .red : (volume.usedFraction > 0.7 ? .orange : .blue))

            HStack {
                Text("Used \(Int64(volume.usedBytes).formattedBytes) / \(Int64(volume.totalBytes).formattedBytes)")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let bsd = volume.bsdName,
                   let rate = rates[parent(of: bsd)] {
                    Label(formatRate(rate.bytesReadPerSec), systemImage: "arrow.down")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.blue)
                    Label(formatRate(rate.bytesWrittenPerSec), systemImage: "arrow.up")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.pink)
                }
            }

            if let bsd = volume.bsdName {
                ioSparkline(for: bsd)
            }
        }
        .padding(Spacing.md)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func ioSparkline(for bsd: String) -> some View {
        AsyncSparkline(bsd: bsd)
            .frame(height: 36)
    }

    private func parent(of bsd: String) -> String {
        // Mirror the parent rule from DiskIOService — slice → whole disk.
        guard bsd.hasPrefix("disk") else { return bsd }
        let suffix = bsd.dropFirst("disk".count)
        var num = ""
        for ch in suffix {
            if ch.isNumber { num.append(ch) } else { break }
        }
        return "disk" + num
    }

    private func formatRate(_ bytesPerSec: UInt64) -> String {
        let v = Double(bytesPerSec)
        if v < 1024 { return "\(Int(v)) B/s" }
        if v < 1024 * 1024 { return String(format: "%.0f KB/s", v / 1024) }
        return String(format: "%.1f MB/s", v / (1024 * 1024))
    }

    // MARK: - Lifecycle

    private func start() {
        Task { await refresh() }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in await refresh() }
        }
    }

    private func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refresh() async {
        volumes = await container.diskIOService.volumes()
        let rateList = await container.diskIOService.sampleRates()
        var byBSD: [String: DiskIORate] = [:]
        for r in rateList { byBSD[r.bsdName] = r }
        rates = byBSD
    }
}

/// Wrapper that pulls the rolling rate history out of the actor each tick
/// without making the parent view itself responsible for storage.
private struct AsyncSparkline: View {
    let bsd: String
    @EnvironmentObject private var container: AppContainer
    @State private var read: [Double] = []
    @State private var write: [Double] = []
    @State private var timer: Timer?

    var body: some View {
        let maxVal = max(1024.0, (read.max() ?? 0), (write.max() ?? 0))
        return ZStack {
            SparklineView(values: read, tint: .blue, fill: true, maxValue: maxVal)
            SparklineView(values: write, tint: .pink, fill: false, maxValue: maxVal)
        }
        .onAppear { start() }
        .onDisappear { timer?.invalidate() }
    }

    private func start() {
        Task { await reload() }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in await reload() }
        }
    }

    private func reload() async {
        let h = await container.diskIOService.history(for: bsd)
        read = h.read
        write = h.write
    }
}
