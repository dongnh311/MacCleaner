import SwiftUI
import AppKit

/// Wraps an `NSVisualEffectView` so SwiftUI can render the same blurred
/// chrome material in every column of `NavigationSplitView`. The system
/// applies a `.sidebar` material to the leading column by default and a
/// different one to the detail column — by overlaying our own material
/// in every column we force them to look identical.
struct UnifiedBackground: NSViewRepresentable {

    var material: NSVisualEffectView.Material = .underWindowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
