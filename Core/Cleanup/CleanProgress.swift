import Foundation
import SwiftUI
import Combine

/// Per-item progress callback fired by deletion paths. The handler receives
/// the URL just acted on (whether the action succeeded or failed) so the UI
/// can advance a counter and show the current item's name.
typealias CleanProgressHandler = @Sendable (_ url: URL) -> Void

/// Observable progress state shared between a deletion task and its UI.
///
/// `start(total:)` is called by the UI right before kicking off the work;
/// the deletion service then pumps `tick(url:)` once per item. The tracker
/// exposes a `@Sendable` handler via `makeHandler()` that bounces back to the
/// MainActor — call sites just hand that to the service and bind the
/// tracker to the view.
@MainActor
final class CleanProgressTracker: ObservableObject {

    @Published private(set) var isActive: Bool = false
    @Published private(set) var current: Int = 0
    @Published private(set) var total: Int = 0
    @Published private(set) var currentName: String = ""

    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1.0, Double(current) / Double(total))
    }

    var percentText: String {
        guard total > 0 else { return "—" }
        return "\(Int((fraction * 100).rounded()))%"
    }

    func start(total: Int) {
        self.total = max(0, total)
        self.current = 0
        self.currentName = ""
        self.isActive = total > 0
    }

    func tick(url: URL) {
        if total > 0 {
            current = min(total, current + 1)
        } else {
            current += 1
        }
        currentName = url.lastPathComponent
    }

    func finish() {
        isActive = false
    }

    /// Returns a Sendable callback safe to pass into actor-isolated services.
    /// Each call hops to the main actor and ticks the counter.
    nonisolated func makeHandler() -> CleanProgressHandler {
        { [weak self] url in
            Task { @MainActor [weak self] in
                self?.tick(url: url)
            }
        }
    }
}

/// Compact progress strip shown inline with action bars during a delete.
/// Pass `tint` to match the surrounding module accent colour.
struct CleanProgressFooter: View {
    @ObservedObject var tracker: CleanProgressTracker
    var tint: Color = .accentColor

    var body: some View {
        if tracker.isActive {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Deleting")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(tracker.currentName.isEmpty ? "—" : tracker.currentName)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    Text("\(tracker.current)/\(tracker.total)  •  \(tracker.percentText)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                ProgressView(value: tracker.fraction)
                    .progressViewStyle(.linear)
                    .tint(tint)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(tint.opacity(0.07))
            .overlay(
                Rectangle()
                    .fill(tint.opacity(0.20))
                    .frame(height: 0.5),
                alignment: .top
            )
            .transition(.opacity)
        }
    }
}
