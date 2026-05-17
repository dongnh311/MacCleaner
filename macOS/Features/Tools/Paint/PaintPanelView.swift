import SwiftUI

@MainActor
struct PaintPanelView: View {

    @ObservedObject var state: PaintState
    @State private var tab: Tab = .layers

    enum Tab: String, CaseIterable, Identifiable {
        case layers = "Layers"
        case history = "History"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in Text(t.rawValue).tag(t) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(Spacing.sm)

            Divider()

            switch tab {
            case .layers:  LayersTab(state: state)
            case .history: HistoryTab(state: state)
            }
        }
        .frame(width: 240)
        .background(Color.secondary.opacity(0.04))
    }
}

// MARK: - Layers

@MainActor
private struct LayersTab: View {

    @ObservedObject var state: PaintState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { state.addLayer() } label: {
                    Label("Add", systemImage: "plus.rectangle")
                }
                .controlSize(.small)
                Spacer()
                Text("\(state.layers.count) layer\(state.layers.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.sm)
            Divider()

            // Top of the list = topmost layer (visually on top of the
            // canvas), so reverse the layers array for display.
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(state.layers.reversed()) { layer in
                        LayerRow(
                            state: state,
                            layer: layer,
                            isActive: state.activeLayer.id == layer.id
                        )
                        Divider()
                    }
                }
            }
        }
    }
}

@MainActor
private struct LayerRow: View {

    @ObservedObject var state: PaintState
    let layer: PaintLayer
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button { state.toggleLayerVisibility(id: layer.id) } label: {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .foregroundStyle(layer.isVisible ? .primary : .secondary)
                    .frame(width: 18)
            }
            .buttonStyle(.plain)
            .help(layer.isVisible ? "Hide layer" : "Show layer")

            Text(layer.name)
                .font(.system(size: 12))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button { state.deleteLayer(id: layer.id) } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            }
            .buttonStyle(.plain)
            .disabled(state.layers.count <= 1)
            .help("Delete layer")
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.18) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { state.setActive(layerID: layer.id) }
    }
}

// MARK: - History

@MainActor
private struct HistoryTab: View {

    @ObservedObject var state: PaintState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(state.historyLabels.count) entr\(state.historyLabels.count == 1 ? "y" : "ies")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Undo") { state.undo() }
                    .controlSize(.small)
                    .disabled(!state.canUndo)
                Button("Redo") { state.redo() }
                    .controlSize(.small)
                    .disabled(!state.canRedo)
            }
            .padding(Spacing.sm)
            Divider()

            if state.historyLabels.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "clock")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("No history yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Newest first.
                        ForEach(Array(state.historyLabels.enumerated().reversed()), id: \.offset) { (idx, label) in
                            HistoryRow(
                                label: label,
                                index: idx,
                                onRevert: { state.revertToHistory(index: idx) }
                            )
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

@MainActor
private struct HistoryRow: View {
    let label: String
    let index: Int
    let onRevert: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.uturn.backward.circle")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 12))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { onRevert() } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            }
            .buttonStyle(.plain)
            .help("Revert to before this action — drops every entry above this one")
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { onRevert() }
    }
}
