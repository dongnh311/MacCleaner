import SwiftUI

enum Spacing {
    static let xxs: CGFloat = 2
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Radius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 6
    static let lg: CGFloat = 10
    static let xl: CGFloat = 14
}

extension View {
    /// Runs `action` once on appear, then again every `interval` seconds
    /// while the view is visible. The sleep loop lives inside SwiftUI's
    /// `.task` so it cancels cleanly on disappear and on view replacement —
    /// no `Timer` retain dance, no manual invalidate(), no `@State` slot.
    /// Failures or cancellations exit the loop silently; the next appear
    /// restarts it.
    func refreshTask(every interval: TimeInterval, action: @escaping @MainActor () async -> Void) -> some View {
        self.task {
            await action()
            let nanos = UInt64(interval * 1_000_000_000)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: nanos)
                if Task.isCancelled { break }
                await action()
            }
        }
    }

    /// Card surface — subtle background + rounded corners + low-elevation
    /// shadow. Set `withShadow: false` for the flat look used by Performance
    /// monitors (matching the surrounding chrome — no elevation).
    func cardStyle(radius: CGFloat = Radius.lg, withShadow: Bool = true) -> some View {
        self
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: withShadow ? Color.black.opacity(0.05) : .clear,
                    radius: withShadow ? 4 : 0,
                    x: 0,
                    y: withShadow ? 1 : 0)
    }

    /// Hero gradient backdrop — used behind module icons.
    func heroIconBackdrop(color: Color) -> some View {
        self
            .padding(14)
            .background(
                LinearGradient(
                    colors: [color.opacity(0.18), color.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(color.opacity(0.25), lineWidth: 0.5)
            )
    }
}

extension Font {
    static let titleLarge = Font.system(size: 22, weight: .semibold)
    static let titleMedium = Font.system(size: 17, weight: .semibold)
    static let titleSmall = Font.system(size: 13, weight: .semibold)
    static let mono = Font.system(.body, design: .monospaced)
    static let monoSmall = Font.system(size: 11, design: .monospaced)
}

extension Color {
    /// Threshold tint for percent metrics (CPU, RAM, GPU). Battery uses
    /// the inverse — see `batteryTint`.
    static func percentTint(_ value: Int) -> Color {
        switch value {
        case ..<60:  return .green
        case ..<85:  return .orange
        default:     return .red
        }
    }

    /// Battery percent: low is bad, high is good.
    static func batteryTint(_ percent: Int) -> Color {
        switch percent {
        case 0...20:  return .red
        case 21...40: return .orange
        default:      return .green
        }
    }

    /// Temperature in °C — looser than percentTint because thermal limits
    /// kick in around 95°C, not at 85.
    static func temperatureTint(_ celsius: Double?) -> Color {
        guard let t = celsius else { return .secondary }
        switch t {
        case ..<60: return .green
        case ..<80: return .orange
        default:    return .red
        }
    }
}

extension UInt64 {
    /// Human-friendly bytes-per-second: "0", "47K", "1.2M". Compact form,
    /// no padding — for tile labels and inline text.
    var formattedRate: String {
        let v = Double(self)
        if v < 1024 { return "0" }
        if v < 1024 * 1024 { return "\(Int(v / 1024))K" }
        let mb = v / (1024 * 1024)
        return mb < 10 ? String(format: "%.1fM", mb) : "\(Int(mb))M"
    }

    /// Verbose bytes-per-second with units: "0 B/s", "47 KB/s", "1.20 MB/s".
    /// For full-size views where the user expects unit suffixes.
    var formattedRateVerbose: String {
        let v = Double(self)
        if v < 1024 { return "\(Int(v)) B/s" }
        if v < 1024 * 1024 { return String(format: "%.0f KB/s", v / 1024) }
        return String(format: "%.2f MB/s", v / (1024 * 1024))
    }

    /// Bytes formatted via `Int64.formattedBytes` — avoids the
    /// `Int64(uint)` cast at every call site.
    var formattedBytes: String {
        let clamped = Swift.min(UInt64(Int64.max), self)
        return Int64(clamped).formattedBytes
    }
}
