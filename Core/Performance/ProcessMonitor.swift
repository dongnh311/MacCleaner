import Foundation

struct ProcessSnapshot: Identifiable, Hashable, Sendable {
    let id: Int32
    let pid: Int32
    let name: String
    let user: String
    let cpuPercent: Double
    let memoryBytes: Int64
    let command: String
}

actor ProcessMonitor {

    func snapshot() async -> [ProcessSnapshot] {
        await Task.detached(priority: .userInitiated) {
            Self.runPS()
        }.value
    }

    func kill(pid: Int32, force: Bool) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            let signal: Int32 = force ? Int32(SIGKILL) : Int32(SIGTERM)
            return Darwin.kill(pid, signal) == 0
        }.value
    }

    private nonisolated static func runPS() -> [ProcessSnapshot] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,rss=,pcpu=,user=,comm="]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            Log.app.error("ps spawn failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
        process.waitUntilExit()

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        var results: [ProcessSnapshot] = []
        results.reserveCapacity(512)

        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Format: pid rss pcpu user comm  (comm may contain spaces — last column)
            let scanner = Scanner(string: trimmed)
            scanner.charactersToBeSkipped = .whitespaces

            var pid: Int32 = 0
            var rssKB: Int64 = 0
            var pcpu: Double = 0
            var user: NSString?

            guard scanner.scanInt32(&pid),
                  scanner.scanInt64(&rssKB),
                  scanner.scanDouble(&pcpu),
                  scanner.scanUpToCharacters(from: .whitespaces, into: &user) else { continue }

            let userStr = (user as String?) ?? ""
            let comm = String(trimmed[scanner.string.index(scanner.string.startIndex, offsetBy: scanner.currentIndex.utf16Offset(in: scanner.string))...])
                .trimmingCharacters(in: .whitespaces)

            let url = URL(fileURLWithPath: comm)
            let displayName = url.pathComponents.contains(where: { $0.hasSuffix(".app") })
                ? (url.pathComponents.first(where: { $0.hasSuffix(".app") })?.replacingOccurrences(of: ".app", with: "") ?? url.lastPathComponent)
                : url.lastPathComponent

            results.append(ProcessSnapshot(
                id: pid,
                pid: pid,
                name: displayName.isEmpty ? comm : displayName,
                user: userStr,
                cpuPercent: pcpu,
                memoryBytes: rssKB * 1024,
                command: comm
            ))
        }

        return results
    }
}
