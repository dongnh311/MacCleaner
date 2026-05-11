import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var container: AppContainer

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gear") }
            MenuBarSettings()
                .tabItem { Label("Menu Bar", systemImage: "menubar.dock.rectangle") }
            AlertsSettings()
                .tabItem { Label("Alerts", systemImage: "bell.badge") }
            QuarantineSettings()
                .tabItem { Label("Quarantine", systemImage: "tray.full") }
            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 540, height: 420)
    }
}

private struct AlertsSettings: View {

    @ObservedObject private var engine = AlertEngine.shared
    @State private var masterEnabled: Bool = AlertEngine.shared.isEnabled

    var body: some View {
        Form {
            Section {
                Toggle("Enable system alerts", isOn: $masterEnabled)
                    .onChange(of: masterEnabled) { newValue in
                        engine.isEnabled = newValue
                        if newValue {
                            Task { await engine.requestAuthorizationIfNeeded() }
                        }
                    }
                if masterEnabled && !engine.hasNotificationAuthorization {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifications permission needed")
                                .font(.system(size: 12, weight: .medium))
                            Text("Open System Settings → Notifications → MacCleaner to allow alerts.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Open Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            } header: {
                Text("Master switch")
            } footer: {
                Text("Each rule has its own cooldown so you won't get spammed if a metric stays elevated.")
                    .font(.caption2)
            }

            Section {
                ForEach(AlertCatalog.builtins) { rule in
                    Toggle(isOn: Binding(
                        get: { engine.isRuleEnabled(rule.id) },
                        set: { engine.setRule(rule.id, enabled: $0) }
                    )) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(rule.title).font(.system(size: 13))
                            Text(rule.detail).font(.caption2).foregroundStyle(.secondary)
                            if let last = engine.lastFiredAt[rule.id] {
                                Text("Last fired: \(last.formatted(.relative(presentation: .named)))")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .disabled(!masterEnabled)
                }
            } header: {
                Text("Built-in rules")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct MenuBarSettings: View {

    @ObservedObject private var config = MenuBarConfig.shared

    var body: some View {
        Form {
            Section {
                Picker("Display", selection: $config.displayMode) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                Picker("Separator", selection: $config.separator) {
                    ForEach(MenuBarSeparator.allCases) { sep in
                        Text(sep.displayName).tag(sep)
                    }
                }
                .pickerStyle(.menu)
                Picker("Label style", selection: $config.labelStyle) {
                    ForEach(MenuBarLabelStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.menu)
                Text("Hidden removes the menu-bar item entirely. Open the main window or relaunch the app to bring it back.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: {
                Text("Menu bar visibility")
            }

            Section {
                Text("Pick which metrics show next to the icon. Drag to reorder.")
                    .font(.caption).foregroundStyle(.secondary)

                ForEach(MenuBarMetric.allCases) { metric in
                    HStack {
                        Toggle(isOn: Binding(
                            get: { config.isEnabled(metric) },
                            set: { _ in config.toggle(metric) }
                        )) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(metric.displayName).font(.system(size: 13))
                                Text(metric.hint).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if config.isEnabled(metric) {
                            Button {
                                config.move(metric, by: -1)
                            } label: { Image(systemName: "chevron.up") }
                            .buttonStyle(.borderless)
                            .help("Move left")
                            Button {
                                config.move(metric, by: +1)
                            } label: { Image(systemName: "chevron.down") }
                            .buttonStyle(.borderless)
                            .help("Move right")
                        }
                    }
                }
            } header: {
                Text("Menu bar metrics")
            }

            Section {
                if config.enabledMetrics.isEmpty {
                    Text("No metrics enabled — only the ✦ glyph will show.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(config.enabledMetrics.map(\.labelPrefix).joined(separator: " "))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Order preview")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct GeneralSettings: View {
    @AppStorage("appearance.preference") private var appearance: String = "system"
    @AppStorage("startup.runSmartCare") private var runSmartCareOnLaunch: Bool = false
    @AppStorage("language.preference") private var language: String = "system"

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    Text("Match System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                Toggle("Run Smart Care at launch", isOn: $runSmartCareOnLaunch)
            } header: {
                Text("Appearance & startup")
            }

            Section {
                Picker("Language", selection: $language) {
                    Text("Match System").tag("system")
                    Text("English").tag("en")
                    Text("Tiếng Việt").tag("vi")
                }
                .onChange(of: language) { newValue in
                    applyLanguage(newValue)
                }
                Text("Restart MacCleaner for the change to apply across every screen.")
                    .font(.caption2).foregroundStyle(.secondary)
            } header: {
                Text("Language")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    /// AppleLanguages drives every Foundation/SwiftUI localization lookup.
    /// Setting it persists across launches; "system" clears the override
    /// so macOS falls back to the user's system preference order.
    private func applyLanguage(_ tag: String) {
        if tag == "system" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([tag], forKey: "AppleLanguages")
        }
    }
}

private struct QuarantineSettings: View {
    @EnvironmentObject private var container: AppContainer

    @State private var sessions: [(URL, Date, Int64)] = []
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quarantine")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Reveal Folder") {
                    let url = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(".MacCleanerQuarantine")
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                Button("Refresh") { Task { await reload() } }
            }
            Text("Items move to ~/.MacCleanerQuarantine/<timestamp>/ and are auto-purged after \(QuarantineService.retentionDays) days.")
                .font(.caption).foregroundStyle(.secondary)

            if sessions.isEmpty {
                Text(loading ? "Loading…" : "No quarantine sessions")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(sessions.enumerated()), id: \.offset) { (_, row) in
                        HStack {
                            Text(row.0.lastPathComponent)
                                .font(.system(size: 12, design: .monospaced))
                            Spacer()
                            Text(row.1.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(row.2.formattedBytes)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .trailing)
                        }
                    }
                }
                .listStyle(.bordered)
                .frame(maxHeight: .infinity)
            }
        }
        .padding()
        .task { await reload() }
    }

    private func reload() async {
        loading = true
        defer { loading = false }
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".MacCleanerQuarantine")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            sessions = []
            return
        }
        let prepared: [(URL, Date, Int64)] = await withTaskGroup(of: (URL, Date, Int64).self) { group in
            for url in entries {
                group.addTask {
                    let v = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                    let date = v?.contentModificationDate ?? .distantPast
                    let size = await Task.detached(priority: .background) {
                        FileSizeCalculator.walk(directory: url).total
                    }.value
                    return (url, date, size)
                }
            }
            var rows: [(URL, Date, Int64)] = []
            for await row in group { rows.append(row) }
            return rows
        }
        sessions = prepared.sorted { $0.1 > $1.1 }
    }
}

private struct AboutSettings: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            Text("MacCleaner")
                .font(.title.weight(.semibold))
            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?") • build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Personal macOS cleaner — feature-parity with CMM 5")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
