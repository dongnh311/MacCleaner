import SwiftUI

/// Tiny line chart for inline use in tiles. Pass an array of values 0–100
/// (or any range — auto-fits) and a tint colour.
struct SparklineView: View {
    let values: [Double]
    var tint: Color = .accentColor
    var fill: Bool = true
    /// If nil, the view auto-fits the sample range; useful for percentages
    /// where you want a fixed 0–100 scale even when current peak is lower.
    var maxValue: Double? = 100

    var body: some View {
        Canvas { ctx, size in
            guard values.count > 1 else { return }
            let bound = maxValue ?? max(1, values.max() ?? 1)
            let stepX = size.width / CGFloat(values.count - 1)
            let path = Path { p in
                for (i, v) in values.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = size.height - CGFloat(min(v, bound) / bound) * size.height
                    if i == 0 { p.move(to: .init(x: x, y: y)) }
                    else      { p.addLine(to: .init(x: x, y: y)) }
                }
            }
            if fill {
                var fillPath = path
                fillPath.addLine(to: .init(x: size.width, y: size.height))
                fillPath.addLine(to: .init(x: 0, y: size.height))
                fillPath.closeSubpath()
                ctx.fill(fillPath, with: .color(tint.opacity(0.18)))
            }
            ctx.stroke(path, with: .color(tint), lineWidth: 1.2)
        }
    }
}
