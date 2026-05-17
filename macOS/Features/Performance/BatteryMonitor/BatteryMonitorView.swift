import SwiftUI

@MainActor
struct BatteryMonitorView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var stats: BatteryStats = .empty
    @State private var activity: SystemActivity?

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
                    activityCard
                }
                .padding(16)
            }
        }
        .refreshTask(every: 5) { await refresh() }
    }

    private var header: some View {
        ModuleHeader(
            icon: stats.isCharging ? "battery.100.bolt" : batterySymbol,
            title: "Battery",
            subtitle: "Live IOKit power source data",
            accent: .teal
        )
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
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else if let mins = stats.timeToFullMinutes {
                    Text("\(mins / 60)h \(mins % 60)m to full")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(16)
        .cardStyle(radius: 8, withShadow: false)
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
            .cardStyle(radius: Radius.md, withShadow: false)
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

    @ViewBuilder
    private var activityCard: some View {
        if let activity {
            VStack(alignment: .leading, spacing: 6) {
                Text("SYSTEM ACTIVITY").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    row("Uptime", activity.formattedUptime)
                    Divider()
                    row("Booted at", activity.bootedAt.formatted(date: .abbreviated, time: .shortened))
                    if let count = activity.sleepEventsLast24h {
                        Divider()
                        row("Sleeps (last 24h)", "\(count)")
                    }
                }
                .cardStyle(radius: Radius.md, withShadow: false)
            }
        }
    }

    private var percentColor: Color {
        switch stats.percentage {
        case 0...20:  return .red
        case 21...40: return .orange
        default:      return .green
        }
    }

    private func refresh() async {
        async let s = container.batteryService.snapshot()
        async let a = container.systemActivityService.snapshot()
        let (newStats, newActivity) = await (s, a)
        stats = newStats
        activity = newActivity
    }
}
