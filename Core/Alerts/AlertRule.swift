import Foundation

/// Rolled-up snapshot the alert engine evaluates each tick. Aggregates the
/// numbers we already publish from `MenuBarStatusModel` plus a couple of
/// process-monitor figures the engine fetches directly. Keep this struct
/// `Sendable` so it can cross the actor boundary cheaply.
struct AlertSnapshot: Sendable {
    let cpuPercent: Int
    let memoryPressurePercent: Int
    let diskFreeBytes: Int64
    let batteryPercent: Int
    let batteryPresent: Bool
    let cpuTemperature: Double?
    let fanRPM: Double?
    let topProcessRSSBytes: Int64
    let topProcessName: String?
    let timestamp: Date
}

/// One alert rule in the engine. `evaluate` returns true when the metric
/// is currently breaching; `cooldown` is the minimum delay between two
/// consecutive notifications for the same rule, so we don't spam.
struct AlertRule: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
    let cooldown: TimeInterval
    /// Some rules need state across ticks (e.g. "sustained for 30s") —
    /// store under the rule id in `AlertEngine.state`. Static rules just
    /// look at the current snapshot.
    let evaluate: @Sendable (AlertSnapshot, inout AlertState) -> Bool

    static func == (lhs: AlertRule, rhs: AlertRule) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Per-rule scratch storage — currently only "first time the metric crossed"
/// timestamp, used by the sustained-CPU rule.
struct AlertState: Sendable {
    var firstBreach: Date?
}

enum AlertCatalog {

    /// Static built-in rule set — users can disable per-rule but not
    /// re-author. Future Tier 4 work could surface a rule editor.
    static let builtins: [AlertRule] = [

        AlertRule(
            id: "cpu.sustained_high",
            title: "CPU pegged at high load",
            detail: "CPU has been ≥90% for 30+ seconds.",
            cooldown: 600
        ) { snap, state in
            if snap.cpuPercent >= 90 {
                if state.firstBreach == nil { state.firstBreach = snap.timestamp }
                if let first = state.firstBreach,
                   snap.timestamp.timeIntervalSince(first) >= 30 {
                    state.firstBreach = nil
                    return true
                }
                return false
            } else {
                state.firstBreach = nil
                return false
            }
        },

        AlertRule(
            id: "cpu.temp_high",
            title: "CPU running hot",
            detail: "CPU temperature is above 95°C.",
            cooldown: 600
        ) { snap, _ in
            (snap.cpuTemperature ?? 0) >= 95
        },

        AlertRule(
            id: "battery.critical",
            title: "Battery critical",
            detail: "Less than 10% remaining.",
            cooldown: 1800
        ) { snap, _ in
            snap.batteryPresent && snap.batteryPercent <= 10
        },

        AlertRule(
            id: "disk.low",
            title: "Disk almost full",
            detail: "Less than 5 GB free on the boot volume.",
            cooldown: 3600
        ) { snap, _ in
            snap.diskFreeBytes < 5 * 1024 * 1024 * 1024
        },

        AlertRule(
            id: "memory.pressure_high",
            title: "Memory pressure high",
            detail: "Compressed + wired + active is above 90% of physical RAM.",
            cooldown: 1200
        ) { snap, _ in
            snap.memoryPressurePercent >= 90
        },

        AlertRule(
            id: "process.heavy",
            title: "Process eating RAM",
            detail: "A single process is using more than 4 GB resident.",
            cooldown: 1800
        ) { snap, _ in
            snap.topProcessRSSBytes > 4 * 1024 * 1024 * 1024
        }
    ]
}
