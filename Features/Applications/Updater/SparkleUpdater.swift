import Foundation

struct SparkleUpdate: Identifiable, Sendable {
    let id: String
    let app: InstalledApp
    let installedVersion: String
    let latestVersion: String
    let downloadURL: URL?
    let releaseNotesURL: URL?
}

actor SparkleUpdater {

    enum UpdaterError: Error, LocalizedError {
        case noFeed
        case fetchFailed(String)
        case parseFailed

        var errorDescription: String? {
            switch self {
            case .noFeed:                return "No Sparkle feed declared"
            case .fetchFailed(let msg):  return "Failed to fetch feed: \(msg)"
            case .parseFailed:           return "Could not parse feed"
            }
        }
    }

    /// Checks all apps with a Sparkle feed URL. Returns updates whose advertised
    /// version is newer than what's installed.
    func checkUpdates(for apps: [InstalledApp]) async -> [SparkleUpdate] {
        let withFeed = apps.compactMap { app -> (InstalledApp, URL)? in
            guard let s = app.sparkleFeedURL, let u = URL(string: s) else { return nil }
            return (app, u)
        }

        return await withTaskGroup(of: SparkleUpdate?.self) { group in
            for (app, feed) in withFeed {
                group.addTask {
                    await Self.checkSingle(app: app, feed: feed)
                }
            }
            var updates: [SparkleUpdate] = []
            for await u in group {
                if let u { updates.append(u) }
            }
            return updates.sorted { $0.app.name.localizedCaseInsensitiveCompare($1.app.name) == .orderedAscending }
        }
    }

    private nonisolated static func checkSingle(app: InstalledApp, feed: URL) async -> SparkleUpdate? {
        do {
            let (data, response) = try await URLSession.shared.data(from: feed)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                Log.app.warning("Sparkle feed \(feed.absoluteString, privacy: .public) returned \(http.statusCode)")
                return nil
            }
            guard let parsed = SparkleAppcastParser.parse(data: data) else { return nil }
            guard let installed = app.version, isVersion(parsed.version, newerThan: installed) else {
                return nil
            }
            return SparkleUpdate(
                id: app.bundleID ?? app.url.path,
                app: app,
                installedVersion: installed,
                latestVersion: parsed.version,
                downloadURL: parsed.downloadURL,
                releaseNotesURL: parsed.releaseNotesURL
            )
        } catch {
            Log.app.warning("Sparkle check failed for \(app.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Compare semantic versions. Falls back to lexical compare for non-numeric parts.
    private nonisolated static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let parts: (String) -> [Int] = { v in
            v.split(whereSeparator: { !$0.isNumber }).map { Int($0) ?? 0 }
        }
        let pa = parts(a)
        let pb = parts(b)
        for i in 0..<max(pa.count, pb.count) {
            let ai = i < pa.count ? pa[i] : 0
            let bi = i < pb.count ? pb[i] : 0
            if ai != bi { return ai > bi }
        }
        return false
    }
}

// MARK: - Appcast XML parsing

struct SparkleAppcastEntry: Sendable {
    let version: String
    let downloadURL: URL?
    let releaseNotesURL: URL?
}

private final class SparkleAppcastParser: NSObject, XMLParserDelegate {

    static func parse(data: Data) -> SparkleAppcastEntry? {
        let p = SparkleAppcastParser()
        let parser = XMLParser(data: data)
        parser.delegate = p
        guard parser.parse() else { return nil }
        return p.bestEntry
    }

    private struct Item {
        var sparkleVersion: String?
        var sparkleShortVersion: String?
        var enclosureVersion: String?
        var downloadURL: URL?
        var releaseNotesURL: URL?
        var pubDate: Date?
    }

    private var current: Item?
    private var currentElement: String = ""
    private var currentText: String = ""
    private var entries: [SparkleAppcastEntry] = []

    var bestEntry: SparkleAppcastEntry? {
        entries.max { lhs, rhs in
            isOlder(lhs.version, rhs.version)
        }
    }

    private func isOlder(_ a: String, _ b: String) -> Bool {
        let parts: (String) -> [Int] = { v in
            v.split(whereSeparator: { !$0.isNumber }).map { Int($0) ?? 0 }
        }
        let pa = parts(a)
        let pb = parts(b)
        for i in 0..<max(pa.count, pb.count) {
            let ai = i < pa.count ? pa[i] : 0
            let bi = i < pb.count ? pb[i] : 0
            if ai != bi { return ai < bi }
        }
        return false
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = qName ?? elementName
        currentText = ""

        if elementName == "item" {
            current = Item()
        }

        if elementName == "enclosure", current != nil {
            if let v = attributeDict["sparkle:shortVersionString"] ?? attributeDict["sparkle:version"] {
                current?.enclosureVersion = v
            }
            if let urlStr = attributeDict["url"], let u = URL(string: urlStr) {
                current?.downloadURL = u
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let qn = qName ?? elementName

        switch qn {
        case "sparkle:version":
            current?.sparkleVersion = trimmed
        case "sparkle:shortVersionString":
            current?.sparkleShortVersion = trimmed
        case "sparkle:releaseNotesLink":
            current?.releaseNotesURL = URL(string: trimmed)
        case "item":
            if let item = current {
                let version = item.sparkleShortVersion ?? item.sparkleVersion ?? item.enclosureVersion ?? ""
                if !version.isEmpty {
                    entries.append(SparkleAppcastEntry(
                        version: version,
                        downloadURL: item.downloadURL,
                        releaseNotesURL: item.releaseNotesURL
                    ))
                }
            }
            current = nil
        default:
            break
        }
        currentText = ""
    }
}
