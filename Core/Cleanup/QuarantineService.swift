import Foundation

actor QuarantineService {

    static let retentionDays: Int = 7

    let root: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.root = home.appendingPathComponent(".MacCleanerQuarantine", isDirectory: true)
    }

    struct MoveResult: Sendable {
        let succeeded: [URL: URL]
        let failed: [(URL, String)]
    }

    struct DeleteResult: Sendable {
        let succeeded: [URL]
        let failed: [(URL, String)]
    }

    /// Moves URLs into a timestamped quarantine session. Used for non-cache items.
    func quarantine(_ urls: [URL]) async -> MoveResult {
        let session = root.appendingPathComponent(timestampString(), isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
        } catch {
            Log.scanner.error("quarantine create-dir failed: \(error.localizedDescription, privacy: .public)")
            return MoveResult(succeeded: [:], failed: urls.map { ($0, error.localizedDescription) })
        }

        var succeeded: [URL: URL] = [:]
        var failed: [(URL, String)] = []

        for url in urls {
            if WhitelistGuard.isProtected(url) {
                failed.append((url, "Refused: protected path"))
                Log.scanner.fault("quarantine refused on protected \(url.path, privacy: .public)")
                continue
            }
            let dest = uniqueDestination(in: session, for: url)
            do {
                try FileManager.default.moveItem(at: url, to: dest)
                succeeded[url] = dest
                Log.scanner.info("quarantined \(url.path, privacy: .public) -> \(dest.path, privacy: .public)")
            } catch {
                failed.append((url, error.localizedDescription))
                Log.scanner.error("quarantine failed for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        return MoveResult(succeeded: succeeded, failed: failed)
    }

    /// Permanently removes URLs. Used only for safe cache items where the OS regenerates content.
    func directDelete(_ urls: [URL]) async -> DeleteResult {
        var succeeded: [URL] = []
        var failed: [(URL, String)] = []

        for url in urls {
            if WhitelistGuard.isProtected(url) {
                failed.append((url, "Refused: protected path"))
                Log.scanner.fault("directDelete refused on protected \(url.path, privacy: .public)")
                continue
            }
            do {
                try FileManager.default.removeItem(at: url)
                succeeded.append(url)
                Log.scanner.info("deleted \(url.path, privacy: .public)")
            } catch {
                failed.append((url, error.localizedDescription))
                Log.scanner.error("delete failed for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        return DeleteResult(succeeded: succeeded, failed: failed)
    }

    /// Removes quarantine sessions older than retentionDays.
    func purgeOld() async {
        guard let sessions = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-Double(Self.retentionDays) * 86_400)
        for session in sessions {
            let v = try? session.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modified = v?.contentModificationDate, modified < cutoff else { continue }
            do {
                try FileManager.default.removeItem(at: session)
                Log.scanner.info("purged quarantine session \(session.lastPathComponent, privacy: .public)")
            } catch {
                Log.scanner.error("failed to purge \(session.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func timestampString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.timeZone = .current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    private func uniqueDestination(in session: URL, for url: URL) -> URL {
        var dest = session.appendingPathComponent(url.lastPathComponent)
        var counter = 1
        while FileManager.default.fileExists(atPath: dest.path) {
            let base = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            let name = ext.isEmpty ? "\(base)_\(counter)" : "\(base)_\(counter).\(ext)"
            dest = session.appendingPathComponent(name)
            counter += 1
        }
        return dest
    }
}
