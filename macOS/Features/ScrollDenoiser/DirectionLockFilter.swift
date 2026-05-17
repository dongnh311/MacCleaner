import Foundation

/// Settings for the direction-lock scroll filter. Tunable from the UI
/// and persisted to UserDefaults.
struct DirectionLockSettings: Equatable, Codable, Sendable {
    /// Lock window after a tick when wheel is moving at a low tick rate.
    var minLockMs: Int = 30
    /// Lock window when wheel is moving fast (>= fastThreshold ticks per windowMs).
    var maxLockMs: Int = 120
    /// Number of ticks within `windowMs` that classifies the wheel as "fast".
    var fastThreshold: Int = 5
    /// Sliding window for tick-rate measurement.
    var windowMs: Int = 100
    /// Idle time before the locked direction is fully released.
    var releaseMs: Int = 200

    static let `default` = DirectionLockSettings()
}

/// Filters out reverse-direction scroll ticks emitted by cheap encoders
/// when the wheel is spun fast. The encoder physically aliases at high
/// rotational speed and reports back-and-forth ticks even though the
/// wheel is moving one way; this filter keeps the dominant direction
/// for a short lock window and drops the obvious noise.
///
/// Thread-safe: the CGEventTap callback fires on a CFRunLoop thread,
/// and the SwiftUI controller reads stats from MainActor.
final class DirectionLockFilter: @unchecked Sendable {

    private let lock = NSLock()
    private var settings: DirectionLockSettings
    private var lockedSign: Int = 0
    private var lockUntil: TimeInterval = 0
    private var lastTickTime: TimeInterval = 0
    // Only timestamps matter — the `fast` classifier counts how many ticks
    // fell inside `windowMs`; their direction is irrelevant.
    private var recentTickTimes: [TimeInterval] = []
    private var _totalTicks = 0
    private var _droppedTicks = 0

    init(settings: DirectionLockSettings = .default) {
        self.settings = settings
    }

    struct Stats: Equatable, Sendable {
        let total: Int
        let dropped: Int
    }

    func snapshot() -> Stats {
        lock.lock(); defer { lock.unlock() }
        return Stats(total: _totalTicks, dropped: _droppedTicks)
    }

    func update(settings: DirectionLockSettings) {
        lock.lock(); defer { lock.unlock() }
        self.settings = settings
    }

    func resetCounters() {
        lock.lock(); defer { lock.unlock() }
        _totalTicks = 0
        _droppedTicks = 0
    }

    /// Returns true if the tick should pass through, false to drop it.
    func shouldPass(delta: Int, now: TimeInterval) -> Bool {
        guard delta != 0 else { return true }
        lock.lock(); defer { lock.unlock() }
        _totalTicks += 1
        let sign = delta > 0 ? 1 : -1

        let windowSec = Double(settings.windowMs) / 1000
        // Entries are appended in monotonic time order, so expired ones are
        // always at the head — trim from the front instead of scanning the
        // whole array. Keeps the hot path O(k) where k is the number
        // of just-expired entries (almost always 0 or 1).
        while let oldest = recentTickTimes.first, now - oldest > windowSec {
            recentTickTimes.removeFirst()
        }

        let releaseSec = Double(settings.releaseMs) / 1000
        if now - lastTickTime > releaseSec {
            lockedSign = 0
            lockUntil = 0
        }

        let lockSec: Double = {
            let ms = recentTickTimes.count >= settings.fastThreshold ? settings.maxLockMs : settings.minLockMs
            return Double(ms) / 1000
        }()

        // The defer fires on every return — including the "drop" path — so
        // a dropped opposite tick still counts toward the fast-rate window
        // and extends the lock implicitly via its successor.
        defer {
            lastTickTime = now
            recentTickTimes.append(now)
        }

        if lockedSign == 0 {
            lockedSign = sign
            lockUntil = now + lockSec
            return true
        }

        if sign == lockedSign {
            lockUntil = max(lockUntil, now + lockSec)
            return true
        }

        // Opposite direction
        if now < lockUntil {
            _droppedTicks += 1
            return false
        }

        // Lock expired — legitimate reversal
        lockedSign = sign
        lockUntil = now + lockSec
        return true
    }
}
