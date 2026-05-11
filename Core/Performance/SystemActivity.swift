import Foundation
import Darwin

/// Boot time + uptime + recent sleep counts. Read via sysctl + pmset log
/// parsing — both unprivileged. The pmset call falls back to "unknown"
/// when the binary isn't reachable (sandbox, stripped systems).
struct SystemActivity: Sendable, Hashable {
    let bootedAt: Date
    let uptimeSeconds: TimeInterval
    /// Best-effort count of sleep events (Notifications + display sleep)
    /// in the last 24 hours; nil if pmset wasn't usable.
    let sleepEventsLast24h: Int?

    var formattedUptime: String {
        let total = Int(uptimeSeconds)
        let days = total / 86_400
        let hours = (total % 86_400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

actor SystemActivityService {

    /// `pmset -g log` can return tens of thousands of lines on a long-uptime
    /// machine and parsing it on every snapshot blocks a fork for ~100ms.
    /// The sleep count doesn't change between events anyway, so cache it for
    /// 5 minutes — well below the rate at which the user opens the battery
    /// panel.
    private var cachedSleepEvents: Int?
    private var cachedSleepEventsAt: Date = .distantPast
    private let sleepCacheTTL: TimeInterval = 300

    func snapshot() -> SystemActivity {
        let boot = Self.bootTime()
        let uptime = Date().timeIntervalSince(boot)
        let sleeps = sleepEventsLast24hCached()
        return SystemActivity(bootedAt: boot, uptimeSeconds: uptime, sleepEventsLast24h: sleeps)
    }

    private func sleepEventsLast24hCached() -> Int? {
        if Date().timeIntervalSince(cachedSleepEventsAt) < sleepCacheTTL {
            return cachedSleepEvents
        }
        let value = Self.sleepEventsLast24h()
        cachedSleepEvents = value
        cachedSleepEventsAt = Date()
        return value
    }

    /// Read kern.boottime via sysctl. Returns now if the call ever fails —
    /// uptime would be zero, which is the safest user-visible default.
    private nonisolated static func bootTime() -> Date {
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        let mibCount = UInt32(mib.count)
        var tv = timeval()
        var size = MemoryLayout<timeval>.stride
        let ok = mib.withUnsafeMutableBufferPointer { mibPtr in
            sysctl(mibPtr.baseAddress, mibCount, &tv, &size, nil, 0) == 0
        }
        guard ok else { return Date() }
        let seconds = TimeInterval(tv.tv_sec) + TimeInterval(tv.tv_usec) / 1_000_000
        return Date(timeIntervalSince1970: seconds)
    }

    /// Parse `pmset -g log` for sleep entries within the last 24h. Format:
    /// timestamp tab "Sleep" / "Wake" tab reason. We just count "Sleep".
    private nonisolated static func sleepEventsLast24h() -> Int? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "log"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let text = String(data: data, encoding: .utf8) else { return nil }

        let cutoff = Date().addingTimeInterval(-86_400)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"

        var count = 0
        for line in text.split(separator: "\n") {
            // Each log line begins with timestamp like
            // "2026-05-08 14:00:00 +0700"
            guard line.count >= 25 else { continue }
            let stamp = String(line.prefix(25))
            guard let ts = formatter.date(from: stamp), ts >= cutoff else { continue }
            // Look for tab-delimited fields containing "Sleep"
            let body = line.dropFirst(25)
            if body.contains("\tSleep\t") || body.contains(" Sleep ") {
                count += 1
            }
        }
        return count
    }
}
