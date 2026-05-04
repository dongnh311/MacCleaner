import Foundation
import AppKit

/// Resolves a bundle identifier or executable path into a friendly display
/// name and an icon. Used everywhere a list shows a `com.foo.bar`-style
/// identifier — Login Items, App Permissions, Malware persistence, etc.
///
/// Lookup order:
///   1. NSWorkspace.urlForApplication(withBundleIdentifier:) — works for any
///      installed `.app` registered with LaunchServices.
///   2. Walk the program path up to a containing `.app` bundle.
///   3. Best-effort guess from the bundle ID's vendor segment or from a
///      vendor folder under `/Library/Application Support`.
@MainActor
final class AppMetadataResolver: ObservableObject {

    struct Info: Sendable, Hashable {
        let displayName: String
        let appURL: URL?
        /// True if backed by a real `.app` bundle (so it has a proper icon).
        let isApp: Bool

        var hasIcon: Bool { appURL != nil }
    }

    private var cache: [String: Info] = [:]
    private var iconCache: [String: NSImage] = [:]

    func resolve(bundleID: String?, programPath: String?) -> Info {
        let key = "\(bundleID ?? "")|\(programPath ?? "")"
        if let hit = cache[key] { return hit }

        if let bid = bundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            let info = makeAppInfo(appURL: url)
            cache[key] = info
            return info
        }

        if let path = programPath, let appURL = Self.findContainingAppBundle(path: path) {
            let info = makeAppInfo(appURL: appURL)
            cache[key] = info
            return info
        }

        let info = Info(
            displayName: Self.deriveDisplayName(bundleID: bundleID, programPath: programPath),
            appURL: nil,
            isApp: false
        )
        cache[key] = info
        return info
    }

    /// Cheap icon lookup keyed by app URL — `NSWorkspace.icon(forFile:)` is
    /// already cached by the OS but we cache here to avoid the syscall in
    /// long lists that re-render.
    func icon(for info: Info, fallbackSymbol: String = "app.dashed") -> NSImage {
        if let url = info.appURL {
            if let cached = iconCache[url.path] { return cached }
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 64, height: 64)
            iconCache[url.path] = icon
            return icon
        }
        if let symbol = NSImage(systemSymbolName: fallbackSymbol, accessibilityDescription: nil) {
            return symbol
        }
        return NSImage()
    }

    // MARK: - Helpers

    private func makeAppInfo(appURL: URL) -> Info {
        let bundle = Bundle(url: appURL)
        let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? appURL.deletingPathExtension().lastPathComponent
        return Info(displayName: name, appURL: appURL, isApp: true)
    }

    private static func findContainingAppBundle(path: String) -> URL? {
        var url = URL(fileURLWithPath: path)
        for _ in 0..<12 {
            if url.pathExtension == "app" { return url }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { return nil }
            url = parent
        }
        return nil
    }

    /// "/Library/Application Support/Fortinet/FortiClient/bin/foo" → "Fortinet"
    /// "com.fortinet.fctctl" → "Fortinet"
    /// "/usr/local/bin/watchman" → "watchman"
    private static func deriveDisplayName(bundleID: String?, programPath: String?) -> String {
        if let path = programPath {
            let comps = URL(fileURLWithPath: path).pathComponents
            if let i = comps.firstIndex(of: "Application Support"), i + 1 < comps.count {
                return comps[i + 1]
            }
            if let i = comps.firstIndex(of: "PrivilegedHelperTools"), i + 1 < comps.count {
                let last = comps[i + 1]
                let parts = last.split(separator: ".")
                if parts.count >= 2 { return String(parts[1]).capitalized }
                return last
            }
            if comps.contains("bin") || comps.contains("sbin") {
                return URL(fileURLWithPath: path).lastPathComponent
            }
        }
        if let bid = bundleID {
            let parts = bid.split(separator: ".")
            if parts.count >= 2 {
                return String(parts[1]).capitalized
            }
            return bid
        }
        return programPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Unknown"
    }
}
