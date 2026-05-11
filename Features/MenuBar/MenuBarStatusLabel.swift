import AppKit
import SwiftUI

/// One-line metrics strip for `MenuBarExtra`. Built as a SwiftUI `Text`
/// with per-segment colours, then rasterised via `ImageRenderer` so the
/// menu bar doesn't strip per-glyph styling (which it does for raw
/// `Text` labels). `isTemplate = false` on the resulting `NSImage`
/// keeps the threshold colours intact.
///
/// Threshold rule for percent metrics (CPU / RAM / GPU / SSD):
///   < 60   → green
///   < 85   → orange
///   ≥ 85   → red
/// Battery flips: low percent = bad.
@MainActor
private enum RenderCache {
    static var key: String?
    static var image: NSImage?
}

struct MenuBarStatusLabel: View {

    @ObservedObject var status: MenuBarStatusModel
    @ObservedObject private var config = MenuBarConfig.shared
    @Environment(\.colorScheme) private var colorScheme

    /// Match macOS's native menu-bar font height. 14pt sits at the same
    /// cap-height as the system clock + battery on a Retina display.
    private let fontSize: CGFloat = 14
    /// SF Pro Regular for visual parity with the system clock + battery
    /// text, with `.monospacedDigit()` so 0-9 + the figure-space
    /// padding (`\u{2007}`) are uniform width — letter glyphs stay
    /// proportional which keeps the strip from looking blocky.
    private var labelFont: Font {
        .system(size: fontSize, weight: .regular).monospacedDigit()
    }

    var body: some View {
        if let img = renderedImage() {
            Image(nsImage: img)
        } else {
            labelText.font(labelFont)
        }
    }

    // MARK: - Image rendering

    private func renderedImage() -> NSImage? {
        // The label re-evaluates on every `@Published` change of
        // `MenuBarStatusModel` — many of those fields (top processes,
        // history arrays) don't affect what we draw, and even when
        // values DO change they're often equal frame-to-frame. Rasterise
        // only when the cache key (content + colour scheme) actually
        // moves; skip the ~5-15 ms ImageRenderer round-trip otherwise.
        let key = cacheKey
        if let img = RenderCache.image, RenderCache.key == key { return img }
        let view = labelText
            .font(labelFont)
            .fixedSize()
            .environment(\.colorScheme, colorScheme)
        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let img = renderer.nsImage else { return nil }
        // `false` keeps our threshold colours; `true` would force the
        // status bar to tint everything monochrome.
        img.isTemplate = false
        RenderCache.key = key
        RenderCache.image = img
        return img
    }

    /// Same data flow as `labelText` but flattened to a plain string —
    /// colours derive deterministically from values which are already in
    /// the string, so cache identity holds without re-checking colours.
    /// `colorScheme` is included so dark/light switches re-render.
    private var cacheKey: String {
        let segments = config.enabledMetrics.map { metric -> String in
            let label = config.labelStyle == .full ? metric.labelPrefix : metric.shortLabel
            return "\(label) \(value(for: metric))"
        }
        let joined = segments.joined(separator: config.separator.rendered)
        let body: String
        switch config.displayMode {
        case .iconOnly:      body = "✦"
        case .infoOnly:      body = joined
        case .full, .hidden: body = "\(joined)  ✦"
        }
        return "\(body)|\(colorScheme == .dark ? "d" : "l")"
    }

    // MARK: - Text composition

    private var labelText: Text {
        switch config.displayMode {
        case .iconOnly:
            return Text("✦").foregroundColor(.primary)
        case .infoOnly:
            return joinedPieces()
        case .full, .hidden:
            return joinedPieces() + Text("  ✦").foregroundColor(.primary)
        }
    }

    /// Walks `enabledMetrics` and concatenates each metric segment with
    /// the configured separator. Each segment carries its own threshold
    /// colour for the value while keeping labels / units neutral.
    private func joinedPieces() -> Text {
        var out = Text("")
        let separator = Text(config.separator.rendered).foregroundColor(.primary)
        for (idx, metric) in config.enabledMetrics.enumerated() {
            if idx > 0 { out = out + separator }
            out = out + segment(for: metric)
        }
        return out
    }

    private func segment(for metric: MenuBarMetric) -> Text {
        let label = config.labelStyle == .full ? metric.labelPrefix : metric.shortLabel
        let val = value(for: metric)
        let labelPart = Text(label).foregroundColor(.primary)
        let valPart = Text(val).foregroundColor(valueColor(for: metric))
        let gap = Text(" ").foregroundColor(.primary)
        return labelPart + gap + valPart
    }

    // MARK: - Threshold colour

    private func valueColor(for metric: MenuBarMetric) -> Color {
        switch metric {
        case .cpu:       return thresholdColor(percent: status.cpuPercent)
        case .ram:       return thresholdColor(percent: status.memoryPressurePercent)
        case .gpuUsage:  return thresholdColor(percent: status.gpuPercent)
        case .diskUsage: return thresholdColor(percent: status.diskUsedPercent)
        case .battery:
            return status.batteryPresent
                ? batteryColor(percent: status.batteryPercent)
                : .secondary
        case .cpuTemp, .fanRPM, .netIn, .netOut:
            return .primary
        }
    }

    private func thresholdColor(percent: Int) -> Color {
        switch percent {
        case ..<60: return .green
        case ..<85: return .orange
        default:    return .red
        }
    }

    /// Inverted scale for battery — low = bad.
    private func batteryColor(percent: Int) -> Color {
        switch percent {
        case ...20: return .red
        case ...50: return .orange
        default:    return .green
        }
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
        case .netIn:     return padRate(status.netInPerSec)
        case .netOut:    return padRate(status.netOutPerSec)
        case .diskUsage: return padPercent(status.diskUsedPercent)
        }
    }

    /// Figure space (U+2007) — same advance width as a digit when the
    /// font has the monospaced-digit OpenType feature on. Padding with
    /// regular spaces wouldn't align because SF Pro's space is narrower
    /// than a digit.
    private static let figureSpace = "\u{2007}"

    private func leftPad(_ s: String, to width: Int) -> String {
        let n = max(0, width - s.count)
        return String(repeating: Self.figureSpace, count: n) + s
    }

    private func padPercent(_ n: Int) -> String {
        let v = min(100, max(0, n))
        return leftPad("\(v)%", to: 4)
    }

    /// 4-char compact rate: "  0K", " 47K", "999K", "  1M", "999M".
    /// 3 digits max before the K/M unit — past 999K we round straight
    /// to the megabyte (precision below 1 MB/s isn't actionable in a
    /// menu-bar glance).
    private func padRate(_ bytes: UInt64) -> String {
        let v = Double(bytes)
        if v < 1024 { return leftPad("0K", to: 4) }
        let kb = Int((v / 1024).rounded())
        if kb < 1000 { return leftPad("\(kb)K", to: 4) }
        let mb = Int(min(999, (v / (1024 * 1024)).rounded()))
        return leftPad("\(mb)M", to: 4)
    }
}
