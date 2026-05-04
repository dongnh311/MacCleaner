import SwiftUI

struct InspectorPlaceholderView: View {

    @EnvironmentObject private var container: AppContainer
    @State private var recents: [ScanHistoryRow] = []

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.tint)
                Text("Recent activity")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    Task { await reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)

            if recents.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(recents, id: \.id) { row in
                            ActivityRow(row: row)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(activityBackdrop)
        .task { await reload() }
    }

    private var activityBackdrop: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.06), Color.clear, Color.purple.opacity(0.04)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No scans yet")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Run any module to populate this panel.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xl)
    }

    private func reload() async {
        do {
            recents = try await container.db.recentScans(limit: 30)
        } catch {
            Log.db.error("Inspector recent scans failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Row

private struct ActivityRow: View {
    let row: ScanHistoryRow

    var body: some View {
        let meta = ModuleMeta.lookup(row.module)
        return HStack(spacing: 10) {
            ZStack {
                Circle().fill(meta.color.opacity(0.18)).frame(width: 32, height: 32)
                Image(systemName: meta.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(meta.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(meta.displayName)
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(row.bytesTotal.formattedBytes)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text(row.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                HStack(spacing: 6) {
                    if row.itemsScanned > 0 {
                        Text("\(row.itemsScanned) item\(row.itemsScanned == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    statusBadge(row.status)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(meta.color.opacity(0.25), lineWidth: 0.5)
                )
        )
    }

    @ViewBuilder
    private func statusBadge(_ status: String) -> some View {
        let color: Color = {
            switch status {
            case "completed": return .green
            case "scanned":   return .blue
            case "partial":   return .orange
            default:          return .secondary
            }
        }()
        Text(status.uppercased())
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Module metadata

/// Maps the free-form `module` string in scan_history to a sidebar item's
/// symbol/colour/title so each activity row gets the right accent.
private struct ModuleMeta {
    let displayName: String
    let symbol: String
    let color: Color

    static func lookup(_ raw: String) -> ModuleMeta {
        if let item = SidebarItem(rawValue: raw) {
            return ModuleMeta(displayName: item.title, symbol: item.symbol, color: item.accentColor)
        }
        switch raw {
        case "SmartCare":
            return ModuleMeta(displayName: "Smart Care", symbol: "sparkles", color: .accentColor)
        case "QuickClean":
            return ModuleMeta(displayName: "Quick Clean", symbol: "bolt.circle", color: .orange)
        case "SmartCare.cleanSafe":
            return ModuleMeta(displayName: "Smart Care · Clean Safe", symbol: "leaf.fill", color: .green)
        default:
            return ModuleMeta(displayName: raw, symbol: "doc", color: .secondary)
        }
    }
}
