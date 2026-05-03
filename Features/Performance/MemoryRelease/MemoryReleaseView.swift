import SwiftUI
import AppKit

@MainActor
struct MemoryReleaseView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var stats: MemoryStats?
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                if let stats {
                    VStack(spacing: 16) {
                        gauge(stats: stats)
                        breakdown(stats: stats)
                        actions
                    }
                    .padding(16)
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                }
            }
        }
        .onAppear { start() }
        .onDisappear { stop() }
    }

    private var header: some View {
        ModuleHeader(
            icon: "memorychip",
            title: "Memory",
            subtitle: "Live RAM breakdown via host_statistics64"
        )
    }

    private func gauge(stats: MemoryStats) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(stats.used.formattedBytes)").font(.system(size: 36, weight: .semibold, design: .monospaced))
                Text("of \(stats.total.formattedBytes) used")
                    .font(.callout).foregroundStyle(.secondary)
            }
            HStack(spacing: 0) {
                segment(width: ratio(stats.wired, total: stats.total), color: .red)
                segment(width: ratio(stats.active, total: stats.total), color: .orange)
                segment(width: ratio(stats.compressed, total: stats.total), color: .purple)
                segment(width: ratio(stats.inactive, total: stats.total), color: .yellow)
                segment(width: ratio(stats.free, total: stats.total), color: .green)
            }
            .frame(height: 16)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            HStack(spacing: 12) {
                legend(color: .red, label: "Wired", value: stats.wired)
                legend(color: .orange, label: "Active", value: stats.active)
                legend(color: .purple, label: "Compressed", value: stats.compressed)
                legend(color: .yellow, label: "Inactive", value: stats.inactive)
                legend(color: .green, label: "Free", value: stats.free)
            }
            .font(.caption)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func breakdown(stats: MemoryStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DETAILS").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            VStack(spacing: 0) {
                row(label: "Total RAM", value: stats.total.formattedBytes)
                Divider()
                row(label: "Used (Wired + Active + Compressed)", value: (stats.wired + stats.active + stats.compressed).formattedBytes)
                Divider()
                row(label: "Pressure", value: String(format: "%.1f%%", stats.pressurePercent))
                Divider()
                row(label: "App memory", value: stats.appMemory.formattedBytes)
                Divider()
                row(label: "Page size", value: "\(stats.pageSize) bytes")
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FREEING MEMORY").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Text("macOS auto-manages memory pressure. Manually purging is rarely needed and requires admin (`sudo purge`). Use the Maintenance tab to copy that command into Terminal.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button {
                        if let url = URL(string: "/Applications/Utilities/Activity Monitor.app") {
                            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                        }
                    } label: {
                        Label("Open Activity Monitor", systemImage: "arrow.up.right.square")
                    }
                }
            }
            .padding(12)
            .background(Color.blue.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func segment(width: Double, color: Color) -> some View {
        GeometryReader { proxy in
            color.frame(width: proxy.size.width * width)
        }.frame(width: nil)
            .layoutPriority(width)
    }

    private func legend(color: Color, label: String, value: Int64) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption)
            Text(value.formattedBytes).font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
        }
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.caption)
            Spacer()
            Text(value).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
    }

    private func ratio(_ part: Int64, total: Int64) -> Double {
        guard total > 0 else { return 0 }
        return Double(part) / Double(total)
    }

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
        stats = await container.memoryService.snapshot()
    }
}
