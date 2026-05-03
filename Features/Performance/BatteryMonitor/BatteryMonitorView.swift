import SwiftUI

@MainActor
struct BatteryMonitorView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var stats: BatteryStats = .empty
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    if !stats.isPresent {
                        VStack(spacing: 8) {
                            Image(systemName: "bolt.slash").font(.system(size: 44)).foregroundStyle(.secondary)
                            Text("No battery detected").font(.title3)
                            Text("Battery info is only available on laptops.").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        gauge
                        details
                    }
                }
                .padding(16)
            }
        }
        .onAppear { start() }
        .onDisappear { stop() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: stats.isCharging ? "battery.100.bolt" : batterySymbol)
                .font(.system(size: 28))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Battery").font(.title2.weight(.semibold))
                Text("Live IOKit power source data").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var gauge: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(stats.percentage)%")
                    .font(.system(size: 44, weight: .semibold, design: .monospaced))
                    .foregroundStyle(percentColor)
                Text(stats.isCharging ? "Charging" : (stats.isPowerAdapterConnected ? "On AC" : "On battery"))
                    .font(.callout).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(stats.percentage), total: 100)
                .progressViewStyle(.linear)
                .tint(percentColor)
            HStack {
                if let mins = stats.timeToEmptyMinutes {
                    Text("\(mins / 60)h \(mins % 60)m to empty")
                        .font(.caption).foregroundStyle(.secondary)
                } else if let mins = stats.timeToFullMinutes {
                    Text("\(mins / 60)h \(mins % 60)m to full")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HEALTH").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            VStack(spacing: 0) {
                row("Cycle count", stats.cycleCount.map(String.init) ?? "—")
                Divider()
                row("Maximum capacity", stats.healthPercent.map { "\($0)%" } ?? "—")
                Divider()
                row("Condition", stats.condition ?? "Unknown")
                Divider()
                row("Charging", stats.isCharging ? "Yes" : "No")
                Divider()
                row("Power adapter", stats.isPowerAdapterConnected ? "Connected" : "Disconnected")
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption)
            Spacer()
            Text(value).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
    }

    private var batterySymbol: String {
        switch stats.percentage {
        case 0...10:  return "battery.0percent"
        case 11...30: return "battery.25percent"
        case 31...60: return "battery.50percent"
        case 61...85: return "battery.75percent"
        default:      return "battery.100percent"
        }
    }

    private var percentColor: Color {
        switch stats.percentage {
        case 0...20:  return .red
        case 21...40: return .orange
        default:      return .green
        }
    }

    private func start() {
        Task { await refresh() }
        let timer = Timer(timeInterval: 5.0, repeats: true) { _ in
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
        stats = await container.batteryService.snapshot()
    }
}
