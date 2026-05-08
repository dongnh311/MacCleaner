import SwiftUI

@MainActor
struct NetworkView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var interfaces: [NetworkInterfaceInfo] = []
    @State private var publicIP: PublicIPSnapshot?
    @State private var publicIPEnabled: Bool = PublicIPService.isEnabled
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    chartCard
                    publicIPCard
                    interfacesCard
                }
                .padding(Spacing.lg)
            }
        }
        .onAppear { start() }
        .onDisappear { stop() }
    }

    private var header: some View {
        ModuleHeader(
            icon: "wifi",
            title: "Network",
            subtitle: "Throughput, interfaces, public IP — last 60s rolling"
        ) {
            if container.menuBarStatus.isVPNActive {
                Label("VPN", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Capsule())
            }
            Button { Task { await refresh() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                metricBlock(label: "Download", value: container.menuBarStatus.netInPerSec, color: .blue)
                metricBlock(label: "Upload", value: container.menuBarStatus.netOutPerSec, color: .pink)
            }
            // Stack download + upload — different tints, same Y axis (max
            // of both buffers) so peaks aren't visually misleading.
            let inH = container.menuBarStatus.netInHistory
            let outH = container.menuBarStatus.netOutHistory
            let maxVal = max(1, (inH.max() ?? 1), (outH.max() ?? 1))
            ZStack {
                SparklineView(values: inH, tint: .blue, fill: true, maxValue: maxVal)
                SparklineView(values: outH, tint: .pink, fill: false, maxValue: maxVal)
            }
            .frame(height: 110)
            HStack {
                Text("0").font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary)
                Spacer()
                Text(formatRate(UInt64(maxVal)))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(Spacing.md)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func metricBlock(label: String, value: UInt64, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Text(formatRate(value))
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var publicIPCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "globe").foregroundStyle(.tint)
                Text("PUBLIC IP").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: $publicIPEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: publicIPEnabled) { newValue in
                        PublicIPService.isEnabled = newValue
                        if newValue { Task { await refreshPublicIP(force: true) } }
                        else        { publicIP = nil }
                    }
            }
            if !publicIPEnabled {
                Text("Disabled — toggle on to fetch from api.ipify.org. Off by default for privacy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let publicIP {
                row("IPv4", publicIP.ipv4 ?? "—")
                Divider()
                row("IPv6", publicIP.ipv6 ?? "—")
                Text("Refreshed \(publicIP.fetchedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Fetching…").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(Spacing.md)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var interfacesCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right").foregroundStyle(.tint)
                Text("INTERFACES").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
            }
            VStack(spacing: 0) {
                ForEach(interfaces) { iface in
                    interfaceRow(iface)
                    if iface.id != interfaces.last?.id { Divider() }
                }
                if interfaces.isEmpty {
                    Text("No active interfaces").font(.caption).foregroundStyle(.secondary).padding(8)
                }
            }
        }
        .padding(Spacing.md)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func interfaceRow(_ iface: NetworkInterfaceInfo) -> some View {
        HStack {
            Image(systemName: iface.isPhysical ? "wifi" : "lock.shield")
                .foregroundStyle(iface.isPhysical ? .blue : .green)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(iface.name).font(.system(size: 13, design: .monospaced))
                    if !iface.isPhysical {
                        Text("VPN").font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
                Text("In \(Int64(iface.bytesInTotal).formattedBytes) · Out \(Int64(iface.bytesOutTotal).formattedBytes)")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption)
            Spacer()
            Text(value).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
    }

    // MARK: - Lifecycle

    private func start() {
        Task { await refresh() }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            Task { @MainActor in await refresh() }
        }
    }

    private func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refresh() async {
        interfaces = await container.networkSpeedService.interfaces()
        await refreshPublicIP(force: false)
    }

    private func refreshPublicIP(force: Bool) async {
        publicIP = await container.publicIPService.fetch(force: force)
    }

    private func formatRate(_ bytesPerSec: UInt64) -> String {
        let v = Double(bytesPerSec)
        if v < 1024 { return "\(Int(v)) B/s" }
        if v < 1024 * 1024 { return String(format: "%.0f KB/s", v / 1024) }
        let mb = v / (1024 * 1024)
        return String(format: "%.2f MB/s", mb)
    }
}
