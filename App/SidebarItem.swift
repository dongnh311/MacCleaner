import Foundation
import SwiftUI

enum SidebarSection: String, CaseIterable, Hashable {
    case scan = "SCAN"
    case cleanup = "CLEANUP"
    case protection = "PROTECTION"
    case performance = "PERFORMANCE"
    case applications = "APPLICATIONS"
    case files = "FILES"
    case tools = "TOOLS"
}

enum SidebarItem: String, CaseIterable, Hashable, Identifiable {
    case smartCare
    case dashboard
    case quickClean
    case systemJunk
    case mailAttachments
    case photoJunk
    case trashBins
    case malware
    case privacy
    case appPermissions
    case maintenance
    case loginItems
    case processMonitor
    case memory
    case battery
    case sensors
    case network
    case bluetooth
    case diskMonitor
    case uninstaller
    case updater
    case spaceLens
    case largeOldFiles
    case duplicates
    case similarPhotos
    case shredder
    case quarantine
    case myTools
    case clock
    case paint

    var id: String { rawValue }

    var section: SidebarSection {
        switch self {
        case .smartCare, .dashboard: return .scan
        case .quickClean, .systemJunk, .mailAttachments, .photoJunk, .trashBins: return .cleanup
        case .malware, .privacy, .appPermissions: return .protection
        case .maintenance, .loginItems, .processMonitor, .memory, .battery, .sensors, .network, .bluetooth, .diskMonitor: return .performance
        case .uninstaller, .updater: return .applications
        case .spaceLens, .largeOldFiles, .duplicates, .similarPhotos: return .files
        case .shredder, .quarantine, .myTools, .clock, .paint: return .tools
        }
    }

    var title: String {
        switch self {
        case .smartCare: return "Smart Care"
        case .dashboard: return "Dashboard"
        case .quickClean: return "Quick Clean"
        case .systemJunk: return "System Junk"
        case .mailAttachments: return "Mail Attachments"
        case .photoJunk: return "Photo Junk"
        case .trashBins: return "Trash Bins"
        case .malware: return "Malware Removal"
        case .privacy: return "Privacy"
        case .appPermissions: return "App Permissions"
        case .maintenance: return "Maintenance"
        case .loginItems: return "Login Items"
        case .processMonitor: return "Process Monitor"
        case .memory: return "Memory"
        case .battery: return "Battery"
        case .sensors: return "Sensors"
        case .network: return "Network"
        case .bluetooth: return "Bluetooth"
        case .diskMonitor: return "Disk Monitor"
        case .uninstaller: return "Uninstaller"
        case .updater: return "Updater"
        case .spaceLens: return "Space Lens"
        case .largeOldFiles: return "Large & Old"
        case .duplicates: return "Duplicates"
        case .similarPhotos: return "Similar Photos"
        case .shredder: return "Shredder"
        case .quarantine: return "Quarantine"
        case .myTools: return "My Tools"
        case .clock: return "Clock"
        case .paint: return "Paint"
        }
    }

    var symbol: String {
        switch self {
        case .smartCare: return "sparkles"
        case .dashboard: return "square.grid.2x2"
        case .quickClean: return "bolt.circle"
        case .systemJunk: return "trash.circle"
        case .mailAttachments: return "envelope.badge"
        case .photoJunk: return "photo.stack"
        case .trashBins: return "trash"
        case .malware: return "shield.lefthalf.filled"
        case .privacy: return "eye.slash"
        case .appPermissions: return "lock.shield"
        case .maintenance: return "wrench.and.screwdriver"
        case .loginItems: return "power"
        case .processMonitor: return "cpu"
        case .memory: return "memorychip"
        case .battery: return "battery.75percent"
        case .sensors: return "thermometer.medium"
        case .network: return "wifi"
        case .bluetooth: return "dot.radiowaves.left.and.right"
        case .diskMonitor: return "internaldrive"
        case .uninstaller: return "xmark.bin"
        case .updater: return "arrow.triangle.2.circlepath"
        case .spaceLens: return "chart.pie"
        case .largeOldFiles: return "doc.text.magnifyingglass"
        case .duplicates: return "doc.on.doc"
        case .similarPhotos: return "photo.on.rectangle.angled"
        case .shredder: return "scissors"
        case .quarantine: return "archivebox"
        case .myTools: return "star"
        case .clock: return "clock"
        case .paint: return "paintbrush.pointed"
        }
    }

    /// Per-section accent — keeps the sidebar visually scannable.
    var accentColor: Color {
        switch section {
        case .scan:         return .accentColor
        case .cleanup:      return .orange
        case .protection:   return .red
        case .performance:  return .teal
        case .applications: return .indigo
        case .files:        return .purple
        case .tools:        return .pink
        }
    }

    /// Keyboard shortcut for ⌘1..⌘9 navigation (top-level sidebar items).
    var keyboardShortcut: KeyEquivalent? {
        switch self {
        case .smartCare:      return "1"
        case .dashboard:      return "2"
        case .quickClean:     return "3"
        case .systemJunk:     return "4"
        case .malware:        return "5"
        case .maintenance:    return "6"
        case .uninstaller:    return "7"
        case .spaceLens:      return "8"
        case .myTools:        return "9"
        default:              return nil
        }
    }
}
