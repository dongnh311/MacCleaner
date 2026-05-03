import SwiftUI

@MainActor
struct MyToolsView: View {

    @EnvironmentObject private var container: AppContainer

    let onNavigate: (SidebarItem) -> Void

    @State private var editing = false

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "star")
                .font(.system(size: 28))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("My Tools").font(.title2.weight(.semibold))
                Text("Pinned modules — your shortcuts").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button(editing ? "Done" : "Edit") {
                editing.toggle()
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if container.myToolsStore.tools.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(container.myToolsStore.tools) { tool in
                            ToolCard(
                                tool: tool,
                                editing: editing
                            ) {
                                if let item = SidebarItem(rawValue: tool.module) {
                                    onNavigate(item)
                                }
                            } onRemove: {
                                container.myToolsStore.remove(id: tool.id)
                            }
                        }
                    }
                }

                if editing {
                    Divider().padding(.vertical, 8)
                    Text("AVAILABLE MODULES")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(SidebarItem.allCases.filter { !container.myToolsStore.contains($0) }) { item in
                            AddToolCard(item: item) {
                                container.myToolsStore.toggle(item: item)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "star").font(.system(size: 56)).foregroundStyle(.tint)
            Text("Pin tools you reach for often").font(.title3).foregroundStyle(.secondary)
            Button("Edit pins") { editing = true }.buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

private struct ToolCard: View {
    let tool: PinnedTool
    let editing: Bool
    let onTap: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    Image(systemName: tool.symbol)
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                    Text(tool.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if editing {
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AddToolCard: View {
    let item: SidebarItem
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            VStack(spacing: 8) {
                Image(systemName: item.symbol)
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                Text(item.title)
                    .font(.system(size: 11))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Image(systemName: "plus.circle").font(.system(size: 18)).foregroundStyle(.tint)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(.secondary.opacity(0.4))
            )
        }
        .buttonStyle(.plain)
    }
}
