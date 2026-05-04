import SwiftUI
import AppKit

@MainActor
struct MenuBarPopoverView: View {

    @EnvironmentObject private var container: AppContainer
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            protectionCard
            tileGrid
            footer
        }
        .padding(12)
        .frame(width: 340)
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
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - Tile grid

    private var tileGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            diskTile
            memoryTile
            batteryTile
            cpuTile
            networkTile
            quickActionTile
        }
    }

    private var status: MenuBarStatusModel { container.menuBarStatus }

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
        Tile(
            icon: "cpu",
            iconColor: .teal,
            title: "CPU",
            primary: "\(status.cpuPercent)%",
            primaryColor: status.cpuPercent > 85 ? .orange : .secondary,
            secondary: "Load",
            actionTitle: nil
        ) {
            container.pendingNavigation = .processMonitor
            openMainWindow()
        }
    }

    private var networkTile: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "wifi")
                    .foregroundStyle(.cyan)
                    .font(.system(size: 14))
                Text("Network")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            HStack(spacing: 4) {
                Image(systemName: "arrow.up").foregroundStyle(.secondary)
                Text(formattedRate(status.netOutPerSec))
                    .font(.system(size: 11, design: .monospaced))
            }
            HStack(spacing: 4) {
                Image(systemName: "arrow.down").foregroundStyle(.secondary)
                Text(formattedRate(status.netInPerSec))
                    .font(.system(size: 11, design: .monospaced))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
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
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
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
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Settings…")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Quit MacCleaner")
        }
    }

    // MARK: - Helpers

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let existing = NSApp.windows.first(where: { $0.canBecomeMain && $0.contentViewController != nil }) {
            existing.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
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
        let v = Double(bytes)
        if v < 1024 { return "0 B/s" }
        if v < 1024 * 1024 { return "\(Int(v / 1024)) KB/s" }
        let mb = v / (1024 * 1024)
        return mb < 10 ? String(format: "%.1f MB/s", mb) : "\(Int(mb)) MB/s"
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
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
    }
}
