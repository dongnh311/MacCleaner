import SwiftUI

/// One-line metrics strip for `MenuBarExtra`. Built from concatenated
/// `Text` rather than nested HStacks because the system status item only
/// reliably renders a single Text view — composing with `+` keeps per-
/// segment color tints (the threshold green/orange/red) while still
/// rendering as one piece of text.
///
/// Threshold rule for percent metrics (CPU / RAM / GPU):
///   < 60   → green
///   < 85   → orange
///   ≥ 85   → red
/// Battery flips: low percent = bad.
struct MenuBarStatusLabel: View {

    @ObservedObject var status: MenuBarStatusModel
    @ObservedObject private var config = MenuBarConfig.shared

    var body: some View {
        Text(verbatim: composedString)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
    }

    /// macOS strips per-segment colors from MenuBarExtra labels (template
    /// tinting applied by NSStatusBarButton), so we render one plain
    /// monospaced string. Real colour rendering would require switching
    /// to an NSImage-of-text approach — defer until users actually ask.
    private var composedString: String {
        var pieces: [String] = []
        for metric in config.enabledMetrics {
            // One mandatory space between label and value so 1-digit
            // values (G  9%) and 2-digit values (C 27%) keep matching
            // gaps after the letter.
            pieces.append("\(metric.shortLabel) \(value(for: metric))")
        }
        return pieces.joined(separator: " | ") + "  ✦"
    }

    // MARK: - Formatting

    private func value(for metric: MenuBarMetric) -> String {
        switch metric {
        case .cpu:      return padPercent(status.cpuPercent)
        case .ram:      return padPercent(status.memoryPressurePercent)
        case .gpuUsage: return padPercent(status.gpuPercent)
        case .battery:
            return status.batteryPresent ? padPercent(status.batteryPercent) : " --%"
        case .cpuTemp:
            if let t = status.cpuTemperature { return String(format: "%2.0f°", t) }
            return " --°"
        case .fanRPM:
            if let f = status.fanRPM, f > 0 { return String(format: "%4d", Int(f)) }
            return "----"
        case .netIn:    return padRate(status.netInPerSec)
        case .netOut:   return padRate(status.netOutPerSec)
        }
    }

    private func padPercent(_ n: Int) -> String {
        let v = min(100, max(0, n))
        return String(format: "%3d%%", v)
    }

    /// 5-char compact rate: "   0K", " 47K", " 999K", " 1.0M", " 100M".
    /// Every branch returns exactly 5 chars — MenuBarExtra recomputes the
    /// status-item width on title change, and a shrinking width (kb hits
    /// 1000 → `"1.0M"` was 4 chars) made the whole strip flicker out for
    /// a moment as macOS re-laid out the menu bar.
    private func padRate(_ bytes: UInt64) -> String {
        let v = Double(bytes)
        if v < 1024 { return "   0K" }
        let kb = v / 1024
        if kb < 1000 { return String(format: "%4.0fK", kb) }
        let mb = kb / 1024
        return mb < 10
            ? String(format: "%4.1fM", mb)
            : String(format: "%4.0fM", min(9999, mb))
    }
}
