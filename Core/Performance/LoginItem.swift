import Foundation

struct LoginItem: Identifiable, Hashable, Sendable {
    let id: URL
    let plistURL: URL
    let label: String
    let program: String?
    let scope: Scope
    let isDisabled: Bool

    enum Scope: String, Sendable, Hashable {
        case userAgent
        case systemAgent
        case systemDaemon

        var displayName: String {
            switch self {
            case .userAgent:    return "User Agent"
            case .systemAgent:  return "System Agent"
            case .systemDaemon: return "System Daemon"
            }
        }

        var requiresAdmin: Bool { self != .userAgent }
    }
}

actor LoginItemsService {

    func enumerate() async -> [LoginItem] {
        await Task.detached(priority: .userInitiated) {
            Self.collect()
        }.value
    }

    /// Toggles a user-domain LaunchAgent. Returns true on success.
    /// Three things have to happen for the change to stick across reload + reboot:
    ///   1. launchctl bootout / bootstrap — affects the running launchd state
    ///   2. launchctl disable / enable — affects the persistent disable flag
    ///   3. Write `Disabled` key into the plist — what enumerate() reads back
    /// Without (3) the plist still says Disabled=false on next reload, so the
    /// UI checkbox bounced right back to "on".
    func toggle(item: LoginItem) async -> Bool {
        guard item.scope == .userAgent else { return false }
        return await Task.detached(priority: .userInitiated) {
            let nowDisabled = !item.isDisabled
            let domain = "gui/\(getuid())"
            let target = "\(domain)/\(item.label)"

            if nowDisabled {
                _ = Self.runLaunchctl(["bootout", target])           // unload running
                _ = Self.runLaunchctl(["disable", target])           // persistent flag
            } else {
                _ = Self.runLaunchctl(["enable", target])
                _ = Self.runLaunchctl(["bootstrap", domain, item.plistURL.path])
            }

            Self.setPlistDisabled(at: item.plistURL, disabled: nowDisabled)
            Log.app.info("toggled \(item.label, privacy: .public) -> disabled=\(nowDisabled)")
            return true
        }.value
    }

    /// Bootouts the agent and moves its plist to quarantine. The user can
    /// restore from the Quarantine module within retentionDays.
    func remove(item: LoginItem, quarantine: QuarantineService) async -> Bool {
        guard item.scope == .userAgent else { return false }
        let domain = "gui/\(getuid())"
        let target = "\(domain)/\(item.label)"
        _ = Self.runLaunchctl(["bootout", target])
        let result = await quarantine.quarantine([item.plistURL])
        let ok = result.succeeded[item.plistURL] != nil
        Log.app.info("removed \(item.label, privacy: .public) -> \(ok)")
        return ok
    }

    @discardableResult
    private nonisolated static func runLaunchctl(_ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        p.standardError = Pipe()
        p.standardOutput = Pipe()
        do { try p.run() } catch {
            Log.app.error("launchctl spawn failed: \(error.localizedDescription, privacy: .public)")
            return -1
        }
        p.waitUntilExit()
        return p.terminationStatus
    }

    private nonisolated static func setPlistDisabled(at url: URL, disabled: Bool) {
        guard let data = try? Data(contentsOf: url),
              var dict = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else {
            return
        }
        dict["Disabled"] = disabled
        if let out = try? PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0) {
            try? out.write(to: url)
        }
    }

    private nonisolated static func collect() -> [LoginItem] {
        let home = NSHomeDirectory()
        let scopes: [(String, LoginItem.Scope)] = [
            ("\(home)/Library/LaunchAgents", .userAgent),
            ("/Library/LaunchAgents", .systemAgent),
            ("/Library/LaunchDaemons", .systemDaemon)
        ]

        var result: [LoginItem] = []
        for (dir, scope) in scopes {
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: dir),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in urls where url.pathExtension == "plist" {
                guard let item = parse(url: url, scope: scope) else { continue }
                result.append(item)
            }
        }
        return result.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private nonisolated static func parse(url: URL, scope: LoginItem.Scope) -> LoginItem? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        let label = plist["Label"] as? String ?? url.deletingPathExtension().lastPathComponent
        var program = plist["Program"] as? String
        if program == nil, let args = plist["ProgramArguments"] as? [String], let first = args.first {
            program = first
        }
        let disabled = plist["Disabled"] as? Bool ?? false

        return LoginItem(
            id: url,
            plistURL: url,
            label: label,
            program: program,
            scope: scope,
            isDisabled: disabled
        )
    }
}
