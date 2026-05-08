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

    private func tint(for metric: MenuBarMetric) -> Color {
        switch metric {
        case .cpu:      return tintForPercent(status.cpuPercent)
        case .ram:      return tintForPercent(status.memoryPressurePercent)
        case .gpuUsage: return tintForPercent(status.gpuPercent)
        case .battery:
            switch status.batteryPercent {
            case 0...20:  return .red
            case 21...40: return .orange
            default:      return .green
            }
        case .cpuTemp:
            guard let t = status.cpuTemperature else { return .secondary }
            switch t {
            case ..<60: return .green
            case ..<80: return .orange
            default:    return .red
            }
        case .fanRPM:   return .primary
        case .netIn:    return .blue
        case .netOut:   return .pink
        }
    }

    private func tintForPercent(_ value: Int) -> Color {
        switch value {
        case ..<60:  return .green
        case ..<85:  return .orange
        default:     return .red
        }
    }

    private func padPercent(_ n: Int) -> String {
        let v = min(100, max(0, n))
        return String(format: "%3d%%", v)
    }

    /// 5-char compact rate: "  0K", " 47K", "999K", "1.2M", "999M".
    /// Tradeoff: less precision for half the menu-bar real estate.
    private func padRate(_ bytes: UInt64) -> String {
        let v = Double(bytes)
        if v < 1024 { return "   0K" }
        let kb = v / 1024
        if kb < 1000 { return String(format: "%4.0fK", kb) }
        let mb = kb / 1024
        return mb < 10 ? String(format: "%.1fM", mb) : String(format: "%4.0fM", min(9999, mb))
    }
}
