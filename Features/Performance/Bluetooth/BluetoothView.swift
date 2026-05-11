import SwiftUI

@MainActor
struct BluetoothView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var devices: [BluetoothDevice] = []

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .refreshTask(every: 5) { await refresh() }
    }

    private var header: some View {
        ModuleHeader(
            icon: "dot.radiowaves.left.and.right",
            title: "Bluetooth",
            subtitle: "Paired devices, battery levels"
        ) {
            Button { Task { await refresh() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if devices.isEmpty {
            VStack(spacing: Spacing.sm) {
                Spacer()
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 36)).foregroundStyle(.secondary)
                Text("No paired devices").font(.title3)
                Text("Pair Bluetooth devices in System Settings; they'll appear here.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: Spacing.sm) {
                    ForEach(devices) { device in
                        deviceCard(device)
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }

    private func deviceCard(_ device: BluetoothDevice) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle().fill(device.isConnected ? Color.blue.opacity(0.18) : Color.secondary.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: symbol(for: device.kind))
                    .font(.system(size: 18))
                    .foregroundStyle(device.isConnected ? .blue : .secondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name).font(.system(size: 14, weight: .semibold))
                HStack(spacing: 6) {
                    Circle().fill(device.isConnected ? Color.green : Color.secondary)
                        .frame(width: 6, height: 6)
                    Text(device.isConnected ? "Connected" : "Not connected")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.tertiary)
                    Text(device.id).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            batteryBlock(for: device)
        }
        .padding(Spacing.md)
        .cardStyle(radius: 8, withShadow: false)
    }

    @ViewBuilder
    private func batteryBlock(for device: BluetoothDevice) -> some View {
        if device.batteryLeft != nil || device.batteryRight != nil || device.batteryCase != nil {
            HStack(spacing: 6) {
                if let l = device.batteryLeft { batteryPill(symbol: "ear", value: l) }
                if let r = device.batteryRight { batteryPill(symbol: "ear.fill", value: r) }
                if let c = device.batteryCase { batteryPill(symbol: "case", value: c) }
            }
        } else if let pct = device.batteryPercent {
            batteryPill(symbol: "battery.100", value: pct)
        } else if device.isConnected {
            Text("—").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private func batteryPill(symbol: String, value: Int) -> some View {
        let tint: Color = {
            switch value {
            case ..<20: return .red
            case ..<50: return .orange
            default: return .green
            }
        }()
        return HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 10)).foregroundStyle(tint)
            Text("\(value)%").font(.system(size: 11, design: .monospaced)).foregroundStyle(tint)
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }

    private func refresh() async {
        devices = await container.bluetoothService.snapshot()
    }

    /// SF Symbol picked at the view layer — keeps the Core service free of
    /// UI vocabulary.
    private func symbol(for kind: BluetoothDevice.Kind) -> String {
        switch kind {
        case .headphones: return "airpodspro"
        case .keyboard:   return "keyboard"
        case .mouse:      return "magicmouse"
        case .gamepad:    return "gamecontroller"
        case .phone:      return "iphone"
        case .watch:      return "applewatch"
        case .other:      return "dot.radiowaves.left.and.right"
        }
    }
}
