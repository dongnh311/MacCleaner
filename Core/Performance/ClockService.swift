import Foundation
import Combine

/// User-selected list of timezones to surface in the Clock module + popover.
/// Identifiers are TZ database names ("Asia/Ho_Chi_Minh", "America/New_York")
/// so they survive DST changes and locale moves.
@MainActor
final class ClockService: ObservableObject {

    static let shared = ClockService()

    @Published var timezones: [String] {
        didSet { persist() }
    }

    @Published var use24Hour: Bool {
        didSet { UserDefaults.standard.set(use24Hour, forKey: Self.use24Key) }
    }

    private static let storageKey = "ClockService.timezones.v1"
    private static let use24Key = "ClockService.use24Hour"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode([String].self, from: data) {
            self.timezones = stored
        } else {
            // Reasonable default for someone in Vietnam: home, common dev
            // timezones, US East/West. User can prune in Settings.
            self.timezones = [
                TimeZone.current.identifier,
                "Asia/Ho_Chi_Minh",
                "America/New_York",
                "America/Los_Angeles",
                "Europe/London"
            ].uniqued()
        }
        self.use24Hour = UserDefaults.standard.object(forKey: Self.use24Key) as? Bool ?? true
    }

    func add(_ identifier: String) {
        guard !timezones.contains(identifier),
              TimeZone(identifier: identifier) != nil else { return }
        timezones.append(identifier)
    }

    func remove(_ identifier: String) {
        timezones.removeAll { $0 == identifier }
    }

    func move(from source: IndexSet, to destination: Int) {
        timezones.move(fromOffsets: source, toOffset: destination)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(timezones) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
