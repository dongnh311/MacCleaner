import AppKit
import Foundation
import SwiftUI

/// An app the user has explicitly added to the cleanup whitelist.
/// `bundleID` is the protection key (matches the names macOS uses for
/// per-app `Library/*` folders); `name` is display-only.
struct ProtectedApp: Codable, Hashable, Identifiable, Sendable {
    let bundleID: String
    let name: String
    var id: String { bundleID }
}

/// Source of truth for user-added protected paths and apps. Built-in
/// protections (Apple system, hardcoded dev-tool tied paths) stay in
/// `WhitelistGuard` because they're safety-critical and should not be
/// disable-able. This class only adds *more* protections on top.
@MainActor
final class ProtectionConfig: ObservableObject {

    static let shared = ProtectionConfig()

    @Published private(set) var customPaths: [String] = []
    @Published private(set) var customApps: [ProtectedApp] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: DefaultsKeys.whitelistCustomPaths),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.customPaths = decoded
        }
        if let data = UserDefaults.standard.data(forKey: DefaultsKeys.whitelistCustomApps),
           let decoded = try? JSONDecoder().decode([ProtectedApp].self, from: data) {
            self.customApps = decoded
        }
        WhitelistGuard.reloadCustomConfig()
    }

    // MARK: - Paths

    func addPath(_ path: String) {
        let normalized = (path as NSString).expandingTildeInPath
        guard !customPaths.contains(normalized) else { return }
        customPaths.append(normalized)
        persistPaths()
    }

    func removePath(_ path: String) {
        customPaths.removeAll { $0 == path }
        persistPaths()
    }

    // MARK: - Apps

    /// Reads the bundle at `url` (typically picked from /Applications)
    /// and adds its bundle ID to the protection list. Returns false if
    /// the URL isn't a valid app bundle or the app is already added.
    @discardableResult
    func addApp(at url: URL) -> Bool {
        guard let bundle = Bundle(url: url) else { return false }
        guard let id = bundle.bundleIdentifier, !id.isEmpty else { return false }
        guard !customApps.contains(where: { $0.bundleID == id }) else { return false }
        let name = (bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle.infoDictionary?["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        customApps.append(ProtectedApp(bundleID: id, name: name))
        persistApps()
        return true
    }

    func removeApp(_ bundleID: String) {
        customApps.removeAll { $0.bundleID == bundleID }
        persistApps()
    }

    // MARK: - Persistence

    private func persistPaths() {
        if let data = try? JSONEncoder().encode(customPaths) {
            UserDefaults.standard.set(data, forKey: DefaultsKeys.whitelistCustomPaths)
        }
        WhitelistGuard.reloadCustomPaths()
    }

    private func persistApps() {
        if let data = try? JSONEncoder().encode(customApps) {
            UserDefaults.standard.set(data, forKey: DefaultsKeys.whitelistCustomApps)
        }
        WhitelistGuard.reloadCustomApps()
    }
}
