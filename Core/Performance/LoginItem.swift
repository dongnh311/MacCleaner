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
    func toggle(item: LoginItem) async -> Bool {
        guard item.scope == .userAgent else { return false }
        return await Task.detached(priority: .userInitiated) {
            let action = item.isDisabled ? "bootstrap" : "bootout"
            let domain = "gui/\(getuid())"
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            if action == "bootstrap" {
                process.arguments = [action, domain, item.plistURL.path]
            } else {
                process.arguments = [action, "\(domain)/\(item.label)"]
            }
            process.standardError = Pipe()
            process.standardOutput = Pipe()
            do {
                try process.run()
            } catch {
                Log.app.error("launchctl spawn failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
            process.waitUntilExit()
            Log.app.info("launchctl \(action, privacy: .public) \(item.label, privacy: .public) -> exit \(process.terminationStatus)")
            return process.terminationStatus == 0
        }.value
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
