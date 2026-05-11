import SwiftUI
import AppKit

@MainActor
struct MenuBarPopoverView: View {

    @EnvironmentObject private var container: AppContainer
    @ObservedObject var status: MenuBarStatusModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            protectionCard
            tileGrid
            topProcessesCard
            footer
        }
        .padding(12)
        .frame(width: 340)
    }

    private var topProcessesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "chart.bar.xaxis").foregroundStyle(.tint).font(.system(size: 11))
                Text("TOP PROCESSES").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Button("Open") {
                    container.pendingNavigation = .processMonitor
                    openMainWindow()
                }
                .font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(.tint)
            }
            HStack(alignment: .top, spacing: 12) {
                processColumn(
                    title: "CPU",
                    rows: status.topByCPU.map { ($0.name, String(format: "%.0f%%", $0.cpuPercent)) }
                )
                processColumn(
                    title: "RAM",
                    rows: status.topByRAM.map { ($0.name, $0.memoryBytes.formattedBytes) }
                )
            }
        }
        .padding(10)
        .cardStyle(radius: 10, withShadow: false)
    }

    private func processColumn(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
            if rows.isEmpty {
                Text("—").font(.system(size: 11)).foregroundStyle(.tertiary)
            } else {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 4) {
                        Text(row.0)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 4)
                        Text(row.1)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Mac Overview")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Protection card

    private var protectionCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.green)
                Text("Protection")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Label("Protected", systemImage: "checkmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
            }
            Text("Persistence inspector available")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            HStack {
                Text("Quarantine retention 7 days")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Check Now") {
                    container.pendingNavigation = .malware
                    openMainWindow()
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
        }
        .padding(10)
        .cardStyle(radius: 10, withShadow: false)
    }

    // MARK: - Tile grid

    private var tileGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            diskTile
            memoryTile
            batteryTile
            cpuTile
            gpuTile
            sensorsTile
            networkTile
            quickActionTile
        }
    }

    private var gpuTile: some View {
        Button {
            container.pendingNavigation = .sensors
            openMainWindow()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "display")
                        .foregroundStyle(.purple)
                        .font(.system(size: 14))
                    Text("GPU")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(status.gpuPercent)%")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(status.gpuPercent > 85 ? .orange : .secondary)
                }
                Text(status.gpuTemperature.map { String(format: "%.0f°C", $0) } ?? "—")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(status.gpuPercent), total: 100)
                    .progressViewStyle(.linear)
                    .tint(.purple)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .cardStyle(radius: 10, withShadow: false)
        }
        .buttonStyle(.plain)
    }

    private var sensorsTile: some View {
        Button {
            container.pendingNavigation = .sensors
            openMainWindow()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "thermometer.medium")
                        .foregroundStyle(sensorTint)
                        .font(.system(size: 14))
                    Text("Sensors")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                }
                Text(sensorPrimary)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(sensorTint)
                    .contentTransition(.numericText())
                Text(sensorSecondary)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .cardStyle(radius: 10, withShadow: false)
        }
        .buttonStyle(.plain)
    }

    private var sensorPrimary: String {
        if let cpu = status.cpuTemperature {
            return String(format: "%.0f°C", cpu)
        }
        return "—"
    }

    private var sensorSecondary: String {
        var bits: [String] = []
        if let gpu = status.gpuTemperature { bits.append(String(format: "GPU %.0f°", gpu)) }
        if let fan = status.fanRPM, fan > 0 { bits.append(String(format: "Fan %.0f rpm", fan)) }
        return bits.isEmpty ? "Tap to open" : bits.joined(separator: " · ")
    }

    private var sensorTint: Color {
        guard let t = status.cpuTemperature else { return .secondary }
        switch t {
        case ..<60: return .green
        case ..<80: return .orange
        default:    return .red
        }
    }

    private var diskTile: some View {
        Tile(
            icon: "internaldrive",
            iconColor: .blue,
            title: "Macintosh HD",
            primary: "Available: \(status.diskFreeBytes.formattedBytes)",
            primaryColor: .orange,
            actionTitle: "Free Up"
        ) {
            container.pendingNavigation = .quickClean
            openMainWindow()
        }
    }

    private var memoryTile: some View {
        Tile(
            icon: "memorychip",
            iconColor: .indigo,
            title: "Memory",
            primary: "Available: \(status.memoryFreeBytes.formattedBytes)",
            primaryColor: status.memoryPressurePercent > 85 ? .orange : .secondary,
            actionTitle: "Free Up"
        ) {
            container.pendingNavigation = .memory
            openMainWindow()
        }
    }

    private var batteryTile: some View {
        Tile(
            icon: status.batteryCharging ? "battery.100.bolt" : batterySymbol(percent: status.batteryPercent),
            iconColor: status.batteryPercent < 20 ? .red : .green,
            title: "Battery",
            primary: status.batteryPresent ? "\(status.batteryPercent)%" : "—",
            primaryColor: .secondary,
            secondary: status.batteryPresent ? (status.batteryCharging ? "Charging" : "Not charging") : "No battery",
            actionTitle: nil
        )
    }

    private var cpuTile: some View {
        Button {
            container.pendingNavigation = .processMonitor
            openMainWindow()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .foregroundStyle(.teal)
                        .font(.system(size: 14))
                    Text("CPU")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(status.cpuPercent)%")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(status.cpuPercent > 85 ? .orange : .secondary)
                }
                Text("\(status.perCorePercent.count) cores · last 60s")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                SparklineView(values: status.cpuHistory, tint: .teal, maxValue: 100)
                    .frame(height: 26)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .cardStyle(radius: 10, withShadow: false)
        }
        .buttonStyle(.plain)
    }

    private var networkTile: some View {
        Button {
            container.pendingNavigation = .network
            openMainWindow()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "wifi")
                        .foregroundStyle(.cyan)
                        .font(.system(size: 14))
                    Text("Network")
                        .font(.system(size: 12, weight: .semibold))
                    if status.isVPNActive {
                        Text("VPN")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.green.opacity(0.18))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down").foregroundStyle(.blue).font(.system(size: 9))
                    Text(formattedRate(status.netInPerSec))
                        .font(.system(size: 11, design: .monospaced))
                    Image(systemName: "arrow.up").foregroundStyle(.pink).font(.system(size: 9))
                    Text(formattedRate(status.netOutPerSec))
                        .font(.system(size: 11, design: .monospaced))
                }
                let inH = status.netInHistory
                let outH = status.netOutHistory
                let maxVal = max(1024.0, (inH.max() ?? 0), (outH.max() ?? 0))
                ZStack {
                    SparklineView(values: inH, tint: .blue, fill: true, maxValue: maxVal)
                    SparklineView(values: outH, tint: .pink, fill: false, maxValue: maxVal)
                }
                .frame(height: 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .cardStyle(radius: 10, withShadow: false)
        }
        .buttonStyle(.plain)
    }

    private var quickActionTile: some View {
        Button {
            container.pendingNavigation = .quickClean
            openMainWindow()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 14))
                    Text("Quick Clean")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                }
                Text("Caches & logs")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("Open →")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .cardStyle(radius: 10, withShadow: false)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                container.pendingNavigation = .smartCare
                container.smartCareAutoRunToken = UUID()
                openMainWindow()
            } label: {
                Label("Run Smart Care", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                AppPresenter.openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Settings…")

            Button {
                AppPresenter.confirmAndQuit()
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Quit MacCleaner completely (close menu bar too)")
        }
    }

    // MARK: - Helpers

    private func openMainWindow() {
        AppPresenter.showMainWindow(openWindow: openWindow)
    }

    private func batterySymbol(percent: Int) -> String {
        switch percent {
        case ..<10:  return "battery.0percent"
        case ..<25:  return "battery.25percent"
        case ..<60:  return "battery.50percent"
        case ..<85:  return "battery.75percent"
        default:     return "battery.100percent"
        }
    }

    private func formattedRate(_ bytes: UInt64) -> String {
        bytes.formattedRateVerbose
    }
}

// MARK: - Tile

private struct Tile: View {

    let icon: String
    let iconColor: Color
    let title: String
    let primary: String
    let primaryColor: Color
    var secondary: String? = nil
    let actionTitle: String?
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            Text(primary)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(primaryColor)
            if let secondary {
                Text(secondary)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .cardStyle(radius: 10, withShadow: false)
    }
}
