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

/// Shared backdrop for in-app detail / info sheets so popups blend with
/// the main window's `unifiedBackdrop` (NSVisualEffectView + accent
/// gradient). Apply via `.background(PopupBackground())`. Skip for system
/// confirmation dialogs and error alerts — those keep their native chrome.
struct PopupBackground: View {

    var accent: Color = .accentColor

    var body: some View {
        ZStack {
            UnifiedBackground(material: .underWindowBackground)
            LinearGradient(
                colors: [accent.opacity(0.18), accent.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}
