import Foundation

/// One snapshot of the user's external IP, or nil if disabled / offline.
/// Hostname / country are best-effort enrichments — the IP itself is the
/// authoritative bit.
struct PublicIPSnapshot: Sendable, Hashable {
    let ipv4: String?
    let ipv6: String?
    let fetchedAt: Date
}

/// OPT-IN public-IP fetcher. The user has to flip a switch in Settings
/// before this hits the network — privacy by default. We use ipify.org
/// because it's the simplest unauthenticated endpoint; users who don't
/// trust it can leave the toggle off.
actor PublicIPService {

    private static let ipifyV4 = URL(string: "https://api.ipify.org?format=text")!
    private static let ipifyV6 = URL(string: "https://api64.ipify.org?format=text")!
    private static let cacheTTL: TimeInterval = 300  // 5 min — IPs don't churn

    /// User-facing toggle persisted in UserDefaults. Reading it doesn't
    /// trigger a network call by itself — the caller must explicitly
    /// invoke `fetch()` after enabling.
    nonisolated static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "PublicIPService.enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "PublicIPService.enabled") }
    }

    private var cached: PublicIPSnapshot?

    /// Returns a fresh snapshot if the toggle is on, the cache is stale,
    /// and we can reach the endpoint. Returns the cached value otherwise.
    /// Returns nil when the toggle is off — never silently fetches.
    func fetch(force: Bool = false) async -> PublicIPSnapshot? {
        guard Self.isEnabled else { return nil }
        if !force, let cached, Date().timeIntervalSince(cached.fetchedAt) < Self.cacheTTL {
            return cached
        }

        async let v4Task = fetchOne(Self.ipifyV4)
        async let v6Task = fetchOne(Self.ipifyV6)
        let (v4, v6) = await (v4Task, v6Task)

        let snap = PublicIPSnapshot(ipv4: v4, ipv6: v6, fetchedAt: Date())
        cached = snap
        return snap
    }

    func cachedSnapshot() -> PublicIPSnapshot? { cached }

    private func fetchOne(_ url: URL) async -> String? {
        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let s = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? nil : s
        } catch {
            return nil
        }
    }
}
