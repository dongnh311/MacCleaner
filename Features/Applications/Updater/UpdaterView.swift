import SwiftUI
import AppKit

@MainActor
struct UpdaterView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var phase: Phase = .idle
    @State private var caskUpdates: [CaskUpdate] = []
    @State private var sparkleUpdates: [SparkleUpdate] = []
    @State private var lastError: String?
    @State private var brewMissing = false
    @State private var upgradingCasks = Set<String>()

    enum Phase { case idle, checking, ready }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
    }

    private var header: some View {
        ModuleHeader(
            icon: "arrow.triangle.2.circlepath",
            title: "Updater",
            subtitle: "Homebrew casks + Sparkle apps",
            accent: .indigo
        ) {
            Button {
                check()
            } label: {
                Label(phase == .ready ? "Re-check" : "Check Now", systemImage: "arrow.clockwise")
            }
            .disabled(phase == .checking)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 56)).foregroundStyle(.tint)
                Text("Press Check Now to look for updates").foregroundStyle(.secondary)
                if let lastError {
                    Text(lastError).font(.caption).foregroundStyle(.red).padding(.top, 4)
                }
                Spacer()
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .checking:
            VStack { Spacer(); ProgressView().controlSize(.large); Text("Checking…").foregroundStyle(.secondary).padding(.top, 8); Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if brewMissing {
                        Label("Homebrew not detected — cask updates skipped. Install from https://brew.sh.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    caskSection
                    sparkleSection
                    if caskUpdates.isEmpty && sparkleUpdates.isEmpty && !brewMissing {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill").font(.system(size: 36)).foregroundStyle(.green)
                            Text("Everything up to date").font(.title3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private var caskSection: some View {
        if !caskUpdates.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("HOMEBREW CASKS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(caskUpdates.count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 0) {
                    ForEach(caskUpdates) { cask in
                        HStack(spacing: 10) {
                            Image(systemName: "shippingbox").foregroundStyle(.brown)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cask.name ?? cask.token).font(.system(size: 13, weight: .medium))
                                Text("\(cask.installedVersion) → \(cask.availableVersion)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if upgradingCasks.contains(cask.token) {
                                ProgressView().controlSize(.small)
                            } else {
                                Button("Upgrade") { upgrade(cask) }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        if cask.id != caskUpdates.last?.id { Divider() }
                    }
                }
                .cardStyle(radius: 8, withShadow: false)
            }
        }
    }

    @ViewBuilder
    private var sparkleSection: some View {
        if !sparkleUpdates.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("SPARKLE APPS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(sparkleUpdates.count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 0) {
                    ForEach(sparkleUpdates) { upd in
                        HStack(spacing: 10) {
                            Image(systemName: "app.gift").foregroundStyle(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(upd.app.name).font(.system(size: 13, weight: .medium))
                                Text("\(upd.installedVersion) → \(upd.latestVersion)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let url = upd.downloadURL {
                                Button("Download") { NSWorkspace.shared.open(url) }
                            }
                            if let url = upd.releaseNotesURL {
                                Button("Notes") { NSWorkspace.shared.open(url) }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        if upd.id != sparkleUpdates.last?.id { Divider() }
                    }
                }
                .cardStyle(radius: 8, withShadow: false)
            }
        }
    }

    private func check() {
        Task { @MainActor in
            phase = .checking
            caskUpdates = []
            sparkleUpdates = []
            lastError = nil
            brewMissing = false

            let installed = await container.appScanner.scan()

            do {
                caskUpdates = try await container.homebrewUpdater.outdatedCasks()
            } catch HomebrewUpdater.UpdaterError.brewNotFound {
                brewMissing = true
            } catch {
                lastError = error.localizedDescription
            }

            sparkleUpdates = await container.sparkleUpdater.checkUpdates(for: installed)
            phase = .ready
            Log.app.info("Updater: \(caskUpdates.count) cask + \(sparkleUpdates.count) sparkle updates")
        }
    }

    private func upgrade(_ cask: CaskUpdate) {
        Task { @MainActor in
            upgradingCasks.insert(cask.token)
            do {
                try await container.homebrewUpdater.upgradeCask(cask.token)
                caskUpdates.removeAll { $0.id == cask.id }
            } catch {
                lastError = error.localizedDescription
            }
            upgradingCasks.remove(cask.token)
        }
    }
}
