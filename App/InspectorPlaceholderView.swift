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
            }

            if recents.isEmpty {
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
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(recents, id: \.id) { row in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(row.module)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.tint)
                                    Spacer()
                                    Text(row.bytesTotal.formattedBytes)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Text(row.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                if row.itemsScanned > 0 {
                                    Text("\(row.itemsScanned) item\(row.itemsScanned == 1 ? "" : "s") · \(row.status)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }

            Spacer()

            Button {
                Task { await reload() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .controlSize(.small)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await reload() }
    }

    private func reload() async {
        do {
            recents = try await container.db.recentScans(limit: 12)
        } catch {
            Log.db.error("Inspector recent scans failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
