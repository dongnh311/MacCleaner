import Foundation
import SwiftUI

/// Per-module scan-result cache. Lets a CleanupModuleView preserve its results
/// when the user navigates to another module and back, instead of re-scanning
/// from scratch. Stored entries also remember when they were captured so the
/// view can show "scanned X minutes ago" + offer a rescan.
@MainActor
final class CleanupResultsCache: ObservableObject {

    struct Entry {
        let items: [CleanableItem]
        let scannedAt: Date
    }

    @Published private(set) var entries: [String: Entry] = [:]

    func get(scannerID: String) -> Entry? {
        entries[scannerID]
    }

    func set(scannerID: String, items: [CleanableItem]) {
        entries[scannerID] = Entry(items: items, scannedAt: Date())
    }

    func update(scannerID: String, items: [CleanableItem]) {
        guard let existing = entries[scannerID] else {
            entries[scannerID] = Entry(items: items, scannedAt: Date())
            return
        }
        entries[scannerID] = Entry(items: items, scannedAt: existing.scannedAt)
    }

    func clear(scannerID: String) {
        entries.removeValue(forKey: scannerID)
    }
}
