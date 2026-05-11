import Foundation
import SwiftUI
import Combine

/// One metric a user can toggle in or out of the menu bar label. The order
/// in which the user enables them is preserved (first-on shows leftmost).
enum MenuBarMetric: String, CaseIterable, Identifiable, Codable, Sendable {
    case cpu
    case ram
    case netIn
    case netOut
    case battery
    case cpuTemp
    case gpuUsage
    case fanRPM

    var id: String { rawValue }

    /// Short label shown on the menu bar before the value.
    var labelPrefix: String {
        switch self {
        case .cpu:      return "CPU"
        case .ram:      return "RAM"
        case .netIn:    return "↓"
        case .netOut:   return "↑"
        case .battery:  return "BAT"
        case .cpuTemp:  return "T"
        case .gpuUsage: return "GPU"
        case .fanRPM:   return "FAN"
        }
    }

    /// One-letter compact label for the menu bar strip.
    var shortLabel: String {
        switch self {
        case .cpu:      return "C"
        case .ram:      return "R"
        case .gpuUsage: return "G"
        case .battery:  return "B"
        case .cpuTemp:  return "T"
        case .fanRPM:   return "F"
        case .netIn:    return "↓"
        case .netOut:   return "↑"
        }
    }

    /// Friendly title for the Settings checklist.
    var displayName: String {
        switch self {
        case .cpu:      return "CPU usage (%)"
        case .ram:      return "RAM pressure (%)"
        case .netIn:    return "Network download"
        case .netOut:   return "Network upload"
        case .battery:  return "Battery (%)"
        case .cpuTemp:  return "CPU temperature"
        case .gpuUsage: return "GPU usage (%)"
        case .fanRPM:   return "Fan RPM"
        }
    }

    var hint: String {
        switch self {
        case .cpu:      return "Total CPU load across all cores."
        case .ram:      return "Memory pressure (active + wired + compressed)."
        case .netIn:    return "Aggregate Wi-Fi/Ethernet download speed."
        case .netOut:   return "Aggregate Wi-Fi/Ethernet upload speed."
        case .battery:  return "Battery percent. Hidden on desktops."
        case .cpuTemp:  return "Average across CPU thermal sensors. Requires SMC."
        case .gpuUsage: return "From IORegistry AGX/IOAccelerator. Apple Silicon only."
        case .fanRPM:   return "Highest fan RPM. Hidden on fanless models."
        }
    }
}

/// User-configurable menu-bar layout — what shows, in which order. Backed
/// by UserDefaults and exposed as an ObservableObject so toggles in
/// Settings re-render the label live.
@MainActor
final class MenuBarConfig: ObservableObject {

    static let shared = MenuBarConfig()

    @Published var enabledMetrics: [MenuBarMetric] {
        didSet { persist() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: DefaultsKeys.menuBarEnabledMetrics),
           let stored = try? JSONDecoder().decode([MenuBarMetric].self, from: data) {
            self.enabledMetrics = stored
        } else {
            // Stats-style default: three percent metrics + network. SSD /
            // battery dropped because percentages don't add much info on
            // top of the disk + battery tiles inside the popover. Upload
            // rate listed before download to match the user's preferred
            // strip order (`↑` left of `↓`).
            self.enabledMetrics = [.cpu, .ram, .gpuUsage, .netOut, .netIn]
        }
    }

    func toggle(_ metric: MenuBarMetric) {
        if let idx = enabledMetrics.firstIndex(of: metric) {
            enabledMetrics.remove(at: idx)
        } else {
            enabledMetrics.append(metric)
        }
    }

    func isEnabled(_ metric: MenuBarMetric) -> Bool {
        enabledMetrics.contains(metric)
    }

    func move(_ metric: MenuBarMetric, by delta: Int) {
        guard let idx = enabledMetrics.firstIndex(of: metric) else { return }
        let newIdx = max(0, min(enabledMetrics.count - 1, idx + delta))
        guard newIdx != idx else { return }
        enabledMetrics.remove(at: idx)
        enabledMetrics.insert(metric, at: newIdx)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(enabledMetrics) {
            UserDefaults.standard.set(data, forKey: DefaultsKeys.menuBarEnabledMetrics)
        }
    }
}
