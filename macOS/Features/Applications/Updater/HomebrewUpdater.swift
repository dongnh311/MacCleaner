import Foundation

struct CaskUpdate: Identifiable, Sendable {
    let id: String
    let token: String
    let installedVersion: String
    let availableVersion: String
    let name: String?
}

actor HomebrewUpdater {

    enum UpdaterError: Error, LocalizedError {
        case brewNotFound
        case shellFailed(Int32, String)

        var errorDescription: String? {
            switch self {
            case .brewNotFound:
                return "Homebrew not found. Install via https://brew.sh."
            case .shellFailed(let code, let stderr):
                return "brew exited with code \(code): \(stderr)"
            }
        }
    }

    private nonisolated static func brewPath() -> String? {
        for candidate in ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"] {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    func outdatedCasks() async throws -> [CaskUpdate] {
        guard let brew = Self.brewPath() else { throw UpdaterError.brewNotFound }

        let json = try await Task.detached(priority: .userInitiated) { () throws -> String in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: brew)
            process.arguments = ["outdated", "--cask", "--json=v2", "--greedy-latest"]

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            try process.run()
            let outData = stdout.fileHandleForReading.readDataToEndOfFile()
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let errMsg = String(data: errData, encoding: .utf8) ?? ""

            guard process.terminationStatus == 0 else {
                throw UpdaterError.shellFailed(process.terminationStatus, errMsg)
            }
            return String(data: outData, encoding: .utf8) ?? "{}"
        }.value

        return Self.parseCaskJSON(json)
    }

    func upgradeCask(_ token: String) async throws {
        guard let brew = Self.brewPath() else { throw UpdaterError.brewNotFound }

        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: brew)
            process.arguments = ["upgrade", "--cask", token]
            let stderr = Pipe()
            process.standardError = stderr
            try process.run()
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let errMsg = String(data: errData, encoding: .utf8) ?? ""
            guard process.terminationStatus == 0 else {
                throw UpdaterError.shellFailed(process.terminationStatus, errMsg)
            }
        }.value
    }

    private nonisolated static func parseCaskJSON(_ json: String) -> [CaskUpdate] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let casks = root["casks"] as? [[String: Any]] else {
            return []
        }

        var result: [CaskUpdate] = []
        for entry in casks {
            guard let token = entry["name"] as? String ?? entry["token"] as? String else { continue }

            let installedVersions = (entry["installed_versions"] as? [String]) ?? []
            let installed = installedVersions.first
                ?? (entry["installed"] as? String)
                ?? (entry["installed_version"] as? String)
                ?? "—"

            let available = (entry["current_version"] as? String)
                ?? (entry["latest"] as? String)
                ?? "—"

            let displayName = (entry["full_name"] as? String) ?? token

            result.append(CaskUpdate(
                id: token,
                token: token,
                installedVersion: installed,
                availableVersion: available,
                name: displayName
            ))
        }
        return result.sorted { $0.token.localizedCaseInsensitiveCompare($1.token) == .orderedAscending }
    }
}
