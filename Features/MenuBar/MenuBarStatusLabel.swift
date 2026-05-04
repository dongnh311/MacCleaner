import SwiftUI

/// The view shown in the menu bar itself — sparkles icon plus a compact
/// realtime metrics strip (CPU%, MEM%, SSD%, ↓in ↑out).
struct MenuBarStatusLabel: View {

    @ObservedObject var status: MenuBarStatusModel

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "sparkles")
            Text(metricStrip)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
    }

    private var metricStrip: String {
        let cpu = String(format: "%2d", status.cpuPercent)
        let mem = String(format: "%2d", status.memoryPressurePercent)
        let dsk = String(format: "%2d", status.diskUsedPercent)
        let net = "↓\(MenuBarStatusModel.compactRate(status.netInPerSec)) ↑\(MenuBarStatusModel.compactRate(status.netOutPerSec))"
        return "C\(cpu) M\(mem) D\(dsk) \(net)"
    }
}
