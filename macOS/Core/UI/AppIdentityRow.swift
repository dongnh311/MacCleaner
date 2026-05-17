import SwiftUI
import AppKit

/// Compact icon + display name + monospaced bundle/identifier row used in
/// Login Items, App Permissions, Malware persistence, etc.
@MainActor
struct AppIdentityCell: View {

    @EnvironmentObject private var container: AppContainer

    let bundleID: String?
    let programPath: String?
    var iconSize: CGFloat = 28
    var fallbackSymbol: String = "app.dashed"

    var body: some View {
        let info = container.appMetadata.resolve(bundleID: bundleID, programPath: programPath)
        return HStack(spacing: 10) {
            AppIconImage(info: info, size: iconSize, fallbackSymbol: fallbackSymbol)
            VStack(alignment: .leading, spacing: 1) {
                Text(info.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if let bid = bundleID, !bid.isEmpty {
                    Text(bid)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if let path = programPath {
                    Text(path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }
}

/// Just the icon, useful when the caller wants its own name layout.
@MainActor
struct AppIconImage: View {

    @EnvironmentObject private var container: AppContainer

    let info: AppMetadataResolver.Info
    var size: CGFloat = 28
    var fallbackSymbol: String = "app.dashed"

    var body: some View {
        if info.hasIcon {
            Image(nsImage: container.appMetadata.icon(for: info, fallbackSymbol: fallbackSymbol))
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22)
                    .fill(Color.secondary.opacity(0.18))
                Image(systemName: fallbackSymbol)
                    .font(.system(size: size * 0.5, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .frame(width: size, height: size)
        }
    }
}
