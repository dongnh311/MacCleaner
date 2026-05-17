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
    case diskUsage

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
        case .diskUsage:return "SSD"
        }
    }

    /// One-letter compact label for the menu bar strip.
    var shortLabel: String {
        switch self {
        case .cpu:       return "C"
        case .ram:       return "R"
        case .gpuUsage:  return "G"
        case .battery:   return "B"
        case .cpuTemp:   return "T"
        case .fanRPM:    return "F"
        case .netIn:     return "↓"
        case .netOut:    return "↑"
        case .diskUsage: return "S"
        }
    }

    /// Friendly title for the Settings checklist.
    var displayName: String {
        switch self {
        case .cpu:       return "CPU usage (%)"
        case .ram:       return "RAM pressure (%)"
        case .netIn:     return "Network download"
        case .netOut:    return "Network upload"
        case .battery:   return "Battery (%)"
        case .cpuTemp:   return "CPU temperature"
        case .gpuUsage:  return "GPU usage (%)"
        case .fanRPM:    return "Fan RPM"
        case .diskUsage: return "Disk usage (%)"
        }
    }

    var hint: String {
        switch self {
        case .cpu:       return "Total CPU load across all cores."
        case .ram:       return "Memory pressure (active + wired + compressed)."
        case .netIn:     return "Aggregate Wi-Fi/Ethernet download speed."
        case .netOut:    return "Aggregate Wi-Fi/Ethernet upload speed."
        case .battery:   return "Battery percent. Hidden on desktops."
        case .cpuTemp:   return "Average across CPU thermal sensors. Requires SMC."
        case .gpuUsage:  return "From IORegistry AGX/IOAccelerator. Apple Silicon only."
        case .fanRPM:    return "Highest fan RPM. Hidden on fanless models."
        case .diskUsage: return "Used percentage of the startup disk."
        }
    }
}

enum MenuBarLabelStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case short  // "C 27%"  — single-letter prefix (default, narrowest)
    case full   // "CPU 27%" — 3-letter prefix, easier to read but wider

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .short: return "Short (C / R / G)"
        case .full:  return "Full (CPU / RAM / GPU)"
        }
    }
}

enum MenuBarSeparator: String, CaseIterable, Identifiable, Codable, Sendable {
    case pipe   // " | "  — explicit dividers (default)
    case space  // "  "   — just whitespace, more compact

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .pipe:  return "Pipe ( | )"
        case .space: return "Space"
        }
    }
    var rendered: String {
        switch self {
        case .pipe:  return " | "
        case .space: return "  "
        }
    }
}

/// What the menu-bar status item shows. `hidden` removes the item from
/// the menu bar entirely (the app stays running — quit via the popover
/// power button or Cmd+Q from the main window).
enum MenuBarDisplayMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case full      // info strip + ✦ icon (default)
    case infoOnly  // info strip only
    case iconOnly  // ✦ icon only
    case hidden    // not in the menu bar

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .full:     return "Info + Icon"
        case .infoOnly: return "Info only"
        case .iconOnly: return "Icon only"
        case .hidden:   return "Hidden"
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

    @Published var displayMode: MenuBarDisplayMode {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: DefaultsKeys.menuBarDisplayMode)
        }
    }

    @Published var separator: MenuBarSeparator {
        didSet {
            UserDefaults.standard.set(separator.rawValue, forKey: DefaultsKeys.menuBarSeparator)
        }
    }

    @Published var labelStyle: MenuBarLabelStyle {
        didSet {
            UserDefaults.standard.set(labelStyle.rawValue, forKey: DefaultsKeys.menuBarLabelStyle)
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: DefaultsKeys.menuBarEnabledMetrics),
           let stored = try? JSONDecoder().decode([MenuBarMetric].self, from: data) {
            self.enabledMetrics = stored
        } else {
            // Stats-style default: three percent metrics + SSD + network.
            // SSD sits before the network pair so the order goes from
            // "system load" → "storage" → "throughput", which is how
            // users typically scan left-to-right.
            self.enabledMetrics = [.cpu, .ram, .gpuUsage, .diskUsage, .netOut, .netIn]
        }
        let raw = UserDefaults.standard.string(forKey: DefaultsKeys.menuBarDisplayMode)
        self.displayMode = raw.flatMap(MenuBarDisplayMode.init(rawValue:)) ?? .full
        let sep = UserDefaults.standard.string(forKey: DefaultsKeys.menuBarSeparator)
        self.separator = sep.flatMap(MenuBarSeparator.init(rawValue:)) ?? .pipe
        let style = UserDefaults.standard.string(forKey: DefaultsKeys.menuBarLabelStyle)
        self.labelStyle = style.flatMap(MenuBarLabelStyle.init(rawValue:)) ?? .short
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
