import Foundation
import AppKit

enum WhitelistGuard {

    private static let absoluteProtected: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/Library/Apple",
        "/Library/Application Support/Apple",
        "/Library/Frameworks",
        "/Library/PrivilegedHelperTools",
        "/Applications",
        "/private/var/db",
        "/private/var/folders",
        "/private/etc"
    ]

    private static let userSubProtected: [String] = [
        "Documents",
        "Desktop",
        "Movies",
        "Music",
        "Pictures",
        "Downloads",
        ".ssh",
        ".gnupg",
        "Library/Keychains",
        "Library/Mobile Documents",
        "Library/CloudStorage",
        // Android emulator user data (NOT a cache — user's virtual devices,
        // boot images and Play system images live here). Never auto-clean.
        ".android/avd",
        ".android/cache",
        // Android SDK install — wiping it bricks the toolchain.
        "Library/Android"
    ]

    /// Tied paths that must be protected when a particular dev tool is live.
    /// Keys are bundle IDs (matched against NSWorkspace.runningApplications);
    /// values are user-relative paths whose contents the running process maps
    /// into memory or relies on continuously. Deleting them while the app is
    /// up risks SIGBUS / corrupted IDE state / crashed emulator.
    private static let appProtectedExtras: [String: [String]] = [
        // Android Studio + AndroidStudio EAP variants. AS keeps state in
        // /Google/AndroidStudio<ver>/ subfolders — we list the AS-specific
        // path so the ancestor check in pathRelates() also protects the
        // parent /Google directory from being wiped wholesale.
        "com.google.android.studio": [
            ".gradle",
            ".android",
            "Library/Caches/Google/AndroidStudio",
            "Library/Application Support/Google/AndroidStudio",
            "Library/Logs/Google/AndroidStudio",
            "Library/Preferences/com.google.android.studio.plist"
        ],
        "com.google.android.studio.dev": [
            ".gradle",
            ".android",
            "Library/Caches/Google/AndroidStudio",
            "Library/Application Support/Google/AndroidStudio",
            "Library/Logs/Google/AndroidStudio"
        ],
        // Xcode
        "com.apple.dt.Xcode": [
            "Library/Developer/Xcode/DerivedData",
            "Library/Developer/CoreSimulator/Devices",
            "Library/Developer/CoreSimulator/Caches",
            "Library/Caches/com.apple.dt.Xcode"
        ],
        // iOS Simulator
        "com.apple.iphonesimulator": [
            "Library/Developer/CoreSimulator/Devices",
            "Library/Developer/CoreSimulator/Caches"
        ],
        // JetBrains family — IntelliJ and Android Studio share Gradle caches
        "com.jetbrains.intellij": [".gradle", ".m2"],
        "com.jetbrains.intellij.ce": [".gradle", ".m2"],
        "com.jetbrains.AppCode": [".gradle"],
        "com.jetbrains.PyCharm": [".gradle"],
        "com.jetbrains.WebStorm": [".gradle"]
    ]

    /// Names returned by `ps -A -o comm=` (i.e. the executable name) of
    /// non-bundled dev tools we still want to detect. When any of these is
    /// running, we activate the same extras as the matching bundle ID.
    private static let processNameToBundle: [String: String] = [
        "qemu-system-aarch64": "com.google.android.studio",
        "qemu-system-x86_64":  "com.google.android.studio",
        "emulator":            "com.google.android.studio",
        "emulator64-arm64":    "com.google.android.studio",
        "emulator64-crash-service": "com.google.android.studio",
        "studio":              "com.google.android.studio",
        "Simulator":           "com.apple.iphonesimulator",
        "gradle":              "com.google.android.studio",
        "java":                "com.google.android.studio"  // gradle daemon
    ]

    /// Cache populated at clean-time so isProtected() stays cheap. Updated
    /// from the main actor before each batch via `refreshLiveProcesses`.
    nonisolated(unsafe) private static var liveAppBundleIDs: Set<String> = []
    /// Last `ps -A` snapshot kept around so `LiveDevTools.detect()` and
    /// any other caller can read process names without forking ps a
    /// second time. Refreshed in lockstep with `liveAppBundleIDs`.
    nonisolated(unsafe) private static var liveProcessNamesCache: Set<String> = []
    /// Cache stamp so back-to-back delete batches in the same Clean
    /// reuse the snapshot instead of forking ps each time. 30s is short
    /// enough that a user quitting AS mid-clean still sees the change
    /// after the next batch.
    nonisolated(unsafe) private static var lastRefreshAt: Date = .distantPast
    private static let refreshTTL: TimeInterval = 30

    /// Bundle IDs of macOS system processes that hold cache / state files
    /// open the entire time the user is logged in. Wiping these while the
    /// process is live corrupts cfprefsd state and triggers the classic
    /// "System Settings goes blank, Mac freezes, requires restart" symptom.
    /// Match is performed against the last path component (with optional
    /// `.savedState` / `.binarycookies` suffix stripped) of any URL under
    /// `~/Library/`.
    private static let liveSystemBundleIDs: Set<String> = [
        "com.apple.systempreferences",
        "com.apple.preferencepanes",
        "com.apple.cfprefsd",
        "com.apple.dock",
        "com.apple.dock.extra",
        "com.apple.finder",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.WindowServer",
        "com.apple.coreservicesd",
        "com.apple.coreservices.uiagent",
        "com.apple.iconservices",
        "com.apple.iconservices.iconservicesagent",
        "com.apple.iconservices.store",
        "com.apple.QuickLookDaemon",
        "com.apple.quicklook",
        "com.apple.QuickLook",
        "com.apple.Spotlight",
        "com.apple.spotlight",
        "com.apple.bird",
        "com.apple.cloudd",
        "com.apple.cloudphotod",
        "com.apple.CloudKit",
        "CloudKit",
        "com.apple.identityservicesd",
        "com.apple.imagent",
        "com.apple.akd",
        "com.apple.AccountAuthenticator",
        "com.apple.loginwindow",
        "com.apple.SecurityAgent",
        "com.apple.UserNotificationCenter",
        "com.apple.AppStore",
        "com.apple.commerce",
        "com.apple.appstoreagent",
        "com.apple.TCC",
        "com.apple.assistantd",
        "com.apple.Siri",
        "com.apple.touristd",
        "com.apple.universalaccessd"
    ]

    /// Strict check used by deletion paths (directDelete / quarantine) and
    /// per-child filtering in rule scanners. Refuses the URL if it is the
    /// protected path, a descendant of one, OR an ancestor of one (deleting
    /// a parent takes protected children down with it).
    static func isProtected(_ url: URL) -> Bool {
        return checkProtected(url, allowAncestorRefuse: true)
    }

    /// Loose check used at the *root* of a cleanup rule. Allows the rule
    /// to enumerate a directory even when some children are protected —
    /// the per-child filter then refuses the protected entries one-by-one.
    /// Without this split, protecting `~/Library/Caches/Google/AndroidStudio`
    /// would cause `~/Library/Caches` itself to be refused (it's an ancestor),
    /// which silently disables the entire user-cache cleanup rule.
    static func isScanRootProtected(_ url: URL) -> Bool {
        return checkProtected(url, allowAncestorRefuse: false)
    }

    private static func checkProtected(_ url: URL, allowAncestorRefuse: Bool) -> Bool {
        let path = url.standardizedFileURL.path

        if path == "/usr/local" || path.hasPrefix("/usr/local/") {
            return false
        }

        for prefix in absoluteProtected {
            if pathRelates(path: path, to: prefix, allowAncestor: allowAncestorRefuse) {
                return true
            }
        }

        let home = NSHomeDirectory()
        for sub in userSubProtected {
            let full = (home as NSString).appendingPathComponent(sub)
            if pathRelates(path: path, to: full, allowAncestor: allowAncestorRefuse) {
                return true
            }
        }

        let libraryRoot = (home as NSString).appendingPathComponent("Library") + "/"
        if path.hasPrefix(libraryRoot) && matchesLiveSystemBundle(url.lastPathComponent) {
            return true
        }

        if !liveAppBundleIDs.isEmpty {
            let last = url.lastPathComponent
            if liveAppBundleIDs.contains(last) { return true }
            let strip = [".savedState", ".binarycookies", ".plist", ".sfl3", ".sfl2"]
            for s in strip where last.hasSuffix(s) {
                let core = String(last.dropLast(s.count))
                if liveAppBundleIDs.contains(core) { return true }
            }
            for component in url.pathComponents {
                if liveAppBundleIDs.contains(component) { return true }
            }
        }

        for bundleID in liveAppBundleIDs {
            guard let extras = appProtectedExtras[bundleID] else { continue }
            for sub in extras {
                let full = (home as NSString).appendingPathComponent(sub)
                if pathRelates(path: path, to: full, allowAncestor: allowAncestorRefuse) {
                    return true
                }
            }
        }

        return false
    }

    /// `path == protected` or `path` is a descendant of `protected`. When
    /// `allowAncestor` is true, an ancestor of `protected` also matches.
    private static func pathRelates(path: String, to protected: String, allowAncestor: Bool) -> Bool {
        if path == protected { return true }
        if path.hasPrefix(protected + "/") { return true }
        if allowAncestor && protected.hasPrefix(path + "/") { return true }
        return false
    }

    /// Refreshes the cached "live app bundle ID" + process-name sets used
    /// by `isProtected` and `LiveDevTools.detect`. Cached for 30s so
    /// back-to-back delete batches (or popover refreshes) don't re-fork
    /// `ps`. Pass `force: true` when the user explicitly asked for a fresh
    /// snapshot (Quick Clean banner refresh).
    @MainActor
    static func refreshLiveProcesses(force: Bool = false) {
        if !force, Date().timeIntervalSince(lastRefreshAt) < refreshTTL { return }
        var ids = Set<String>()
        for app in NSWorkspace.shared.runningApplications {
            if let id = app.bundleIdentifier { ids.insert(id) }
        }
        let names = liveProcessExecutableNames()
        for name in names {
            if let mapped = processNameToBundle[name] {
                ids.insert(mapped)
            }
        }
        liveAppBundleIDs = ids
        liveProcessNamesCache = names
        lastRefreshAt = Date()
    }

    /// Snapshot of currently running executable names. Reads the cache
    /// populated by `refreshLiveProcesses` — call that first if you need
    /// fresh data. Useful for callers that previously forked ps themselves.
    static func liveProcessNames() -> Set<String> {
        liveProcessNamesCache
    }

    /// Single `ps -A -o comm=` fork. Drains stdout BEFORE waitUntilExit
    /// so a full pipe buffer doesn't deadlock the wait.
    private static func liveProcessExecutableNames() -> Set<String> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-A", "-o", "comm="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            var names = Set<String>()
            for line in output.split(separator: "\n") {
                // The COMM column carries the full path — keep just the leaf.
                if let last = line.split(separator: "/").last {
                    names.insert(String(last).trimmingCharacters(in: .whitespaces))
                }
            }
            return names
        } catch {
            return []
        }
    }

    /// Strips suffixes macOS appends to per-bundle state folders so a name
    /// like `com.apple.systempreferences.savedState` still matches the
    /// `com.apple.systempreferences` entry in liveSystemBundleIDs.
    private static func matchesLiveSystemBundle(_ name: String) -> Bool {
        if liveSystemBundleIDs.contains(name) { return true }
        let strippableSuffixes = [".savedState", ".binarycookies", ".plist", ".sfl3", ".sfl2"]
        for suffix in strippableSuffixes where name.hasSuffix(suffix) {
            let core = String(name.dropLast(suffix.count))
            if liveSystemBundleIDs.contains(core) { return true }
        }
        return false
    }
}
