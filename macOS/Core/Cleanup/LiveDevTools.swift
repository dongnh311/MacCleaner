import Foundation
import AppKit
import SwiftUI

/// One running developer tool / IDE that the cleanup engine will refuse to
/// touch while it's alive. Surfaced to the UI so the user can SEE the
/// protection working before they hit Clean.
struct DetectedDevTool: Identifiable, Hashable {
    let id: String          // canonical bundle ID
    let name: String        // human-readable
    let symbol: String      // SF Symbol
    let hints: [String]     // tilde-paths the user can recognise
}

enum LiveDevTools {

    /// Public read-only list of every dev tool we know how to protect.
    /// Used by the Settings UI to render the "always-on protections"
    /// section so it matches the protection set in
    /// `WhitelistGuard.appProtectedExtras` exactly.
    static var builtIns: [DetectedDevTool] {
        catalog.values.sorted { $0.name < $1.name }
    }

    private static let catalog: [String: DetectedDevTool] = [
        "com.google.android.studio": .init(
            id: "com.google.android.studio",
            name: "Android Studio",
            symbol: "hammer.fill",
            hints: ["~/.gradle", "~/.android", "~/Library/Caches/Google/AndroidStudio"]
        ),
        "com.google.android.studio.dev": .init(
            id: "com.google.android.studio.dev",
            name: "Android Studio EAP",
            symbol: "hammer.fill",
            hints: ["~/.gradle", "~/.android"]
        ),
        "com.apple.dt.Xcode": .init(
            id: "com.apple.dt.Xcode",
            name: "Xcode",
            symbol: "swift",
            hints: ["~/Library/Developer/Xcode/DerivedData", "~/Library/Developer/CoreSimulator/Devices"]
        ),
        "com.apple.iphonesimulator": .init(
            id: "com.apple.iphonesimulator",
            name: "iOS Simulator",
            symbol: "iphone",
            hints: ["~/Library/Developer/CoreSimulator/Devices"]
        ),
        "com.jetbrains.intellij": .init(
            id: "com.jetbrains.intellij",
            name: "IntelliJ IDEA",
            symbol: "hammer.fill",
            hints: ["~/.gradle", "~/.m2"]
        ),
        "com.jetbrains.intellij.ce": .init(
            id: "com.jetbrains.intellij.ce",
            name: "IntelliJ IDEA CE",
            symbol: "hammer.fill",
            hints: ["~/.gradle", "~/.m2"]
        ),
        "com.jetbrains.AppCode": .init(
            id: "com.jetbrains.AppCode",
            name: "AppCode",
            symbol: "hammer.fill",
            hints: ["~/.gradle"]
        ),
        "com.jetbrains.PyCharm": .init(
            id: "com.jetbrains.PyCharm",
            name: "PyCharm",
            symbol: "hammer.fill",
            hints: ["~/.gradle"]
        ),
        "com.jetbrains.WebStorm": .init(
            id: "com.jetbrains.WebStorm",
            name: "WebStorm",
            symbol: "hammer.fill",
            hints: ["~/.gradle"]
        )
    ]

    /// Snapshot of detectable dev tools currently up on the user's machine.
    /// Drives both the visible banner and (via the same cache) the runtime
    /// guard — no drift, no double-fork. The single `ps` invocation lives
    /// in `WhitelistGuard.refreshLiveProcesses`; we just read its cache.
    @MainActor
    static func detect() -> [DetectedDevTool] {
        // Force a fresh `ps` here — the 30s TTL is a perf optimisation
        // for back-to-back scan batches, but `detect()` is the call we
        // make right before the user sees the confirm dialog (and
        // before delete runs). A stale cache here = false negatives =
        // protections silently skipped = killed emulators.
        WhitelistGuard.refreshLiveProcesses(force: true)
        var tools: [DetectedDevTool] = []
        var seen = Set<String>()
        for app in NSWorkspace.shared.runningApplications {
            guard let id = app.bundleIdentifier, let entry = catalog[id], !seen.contains(id) else { continue }
            tools.append(entry)
            seen.insert(id)
        }
        // Non-bundled processes (qemu, gradle daemon) — surface as a single
        // "Android emulator" entry whose absence from NSWorkspace would
        // otherwise hide it from the user.
        let processNames = WhitelistGuard.liveProcessNames()
        let qemuProcesses: Set<String> = [
            "qemu-system-aarch64", "qemu-system-x86_64",
            "emulator", "emulator64-arm64", "emulator64-crash-service"
        ]
        if !processNames.isDisjoint(with: qemuProcesses), !seen.contains("android.emulator.qemu") {
            tools.append(.init(
                id: "android.emulator.qemu",
                name: "Android Emulator",
                symbol: "iphone.gen3",
                hints: ["~/.android/avd", "~/.android/cache"]
            ))
        }
        return tools
    }
}

/// Banner shown above the Clean action bar when known dev tools are alive.
/// Communicates that protection is active so the user doesn't suspect the
/// cleaner of trashing their build environment.
struct RunningDevToolsBanner: View {
    let tools: [DetectedDevTool]

    var body: some View {
        if !tools.isEmpty {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Running: \(tools.map(\.name).joined(separator: ", "))")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Caches & data for these tools will be skipped to avoid crashing the IDE or killing the emulator.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.green.opacity(0.10))
            .overlay(
                Rectangle().fill(Color.green.opacity(0.25)).frame(height: 0.5),
                alignment: .top
            )
        }
    }
}
