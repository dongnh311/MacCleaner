import Foundation
import SwiftUI

struct PinnedTool: Codable, Sendable, Identifiable, Hashable {
    let id: UUID
    let module: String
    let title: String
    let symbol: String
}

@MainActor
final class MyToolsStore: ObservableObject {

    @Published private(set) var tools: [PinnedTool] = []

    init() {
        load()
    }

    var sidebarItems: [PinnedTool] {
        // Map from SidebarItem to PinnedTool defaults for first-launch suggestions
        SidebarItem.allCases.map { PinnedTool(id: UUID(), module: $0.rawValue, title: $0.title, symbol: $0.symbol) }
    }

    func toggle(item: SidebarItem) {
        if let idx = tools.firstIndex(where: { $0.module == item.rawValue }) {
            tools.remove(at: idx)
        } else {
            tools.append(PinnedTool(id: UUID(), module: item.rawValue, title: item.title, symbol: item.symbol))
        }
        save()
    }

    func contains(_ item: SidebarItem) -> Bool {
        tools.contains { $0.module == item.rawValue }
    }

    func remove(id: UUID) {
        tools.removeAll { $0.id == id }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        tools.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKeys.myToolsPinned) else { return }
        if let decoded = try? JSONDecoder().decode([PinnedTool].self, from: data) {
            tools = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(tools) {
            UserDefaults.standard.set(data, forKey: DefaultsKeys.myToolsPinned)
        }
    }
}
