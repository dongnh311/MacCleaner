import SwiftUI

struct PermissionsWizardSheet: View {

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var statuses: [PermissionType: PermissionStatus] = [:]
    @State private var refreshing = false

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 8) {
                ForEach(PermissionType.allCases) { type in
                    PermissionRow(
                        type: type,
                        status: statuses[type] ?? .unknown
                    ) {
                        PermissionsService.openSettings(for: type)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            Divider()

            HStack {
                Button {
                    Task { await refresh() }
                } label: {
                    Label("Re-check", systemImage: "arrow.clockwise")
                }
                .disabled(refreshing)

                Spacer()

                Button("Skip for now") { dismiss() }

                Button("Continue") {
                    UserDefaults.standard.set(true, forKey: "onboarding.completed")
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 520)
        .task { await refresh() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 44))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            Text("Grant permissions")
                .font(.title2.weight(.semibold))
            Text("MacCleaner needs the following to fully analyse your Mac. You can skip and grant later from Settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(.top, 28)
        .padding(.bottom, 20)
        .padding(.horizontal, 24)
    }

    private func refresh() async {
        refreshing = true
        defer { refreshing = false }
        statuses = await container.permissions.refreshAll()
    }
}

private struct PermissionRow: View {
    let type: PermissionType
    let status: PermissionStatus
    let onAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(type.title)
                    .font(.body.weight(.medium))
                Text(type.rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button(buttonTitle, action: onAction)
                .controlSize(.small)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var iconName: String {
        switch status {
        case .granted: return "checkmark.circle.fill"
        case .denied:  return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch status {
        case .granted: return .green
        case .denied:  return .red
        case .unknown: return .secondary
        }
    }

    private var buttonTitle: String {
        status == .granted ? "Open Settings" : "Grant"
    }
}
