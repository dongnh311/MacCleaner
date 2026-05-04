import SwiftUI

/// Realtime metrics in the menu bar — single Text(verbatim:) in SF Mono.
/// Each value is space-padded to a fixed character width, so the whole strip
/// is always the same number of glyphs and SF Mono guarantees equal width per
/// glyph. Result: layout never reflows on tick.
///
///   ✦ CPU   5% RAM  78% In   0K Out  47K
///   ✦ CPU 100% RAM  78% In 999M Out 1.2M
struct MenuBarStatusLabel: View {

    @ObservedObject var status: MenuBarStatusModel

    var body: some View {
        Text(verbatim: combined)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .fixedSize()
    }

    private var combined: String {
        let cpu = padPercent(status.cpuPercent)
        let ram = padPercent(status.memoryPressurePercent)
        let inR = padRate(status.netInPerSec)
        let outR = padRate(status.netOutPerSec)
        return "CPU \(cpu) RAM \(ram) In \(inR) Out \(outR) ✦"
    }

    /// Always 4 chars, space-padded: "  0%", " 30%", "100%".
    private func padPercent(_ n: Int) -> String {
        let v = min(100, max(0, n))
        return String(format: "%3d", v) + "%"
    }

    /// Always 4 chars, space-padded: "  0K", " 47K", "999K", "  1M", "999M".
    /// Switches K → M at 1000K so the digits never overflow the slot.
    private func padRate(_ bytes: UInt64) -> String {
        let v = Double(bytes)
        if v < 1024 { return "  0K" }
        let kb = Int(v / 1024)
        if kb < 1000 { return String(format: "%3dK", kb) }
        let mb = Int(v / (1024 * 1024))
        return mb < 1000 ? String(format: "%3dM", mb) : "999M"
    }
}
