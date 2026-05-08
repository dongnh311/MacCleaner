import SwiftUI

@MainActor
struct ClockView: View {

    @ObservedObject private var service = ClockService.shared
    @State private var now = Date()
    @State private var ticker: Timer?
    @State private var showingPicker = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .onAppear { start() }
        .onDisappear { stop() }
        .sheet(isPresented: $showingPicker) {
            TimezonePickerSheet { id in
                service.add(id)
                showingPicker = false
            } cancel: {
                showingPicker = false
            }
        }
    }

    private var header: some View {
        ModuleHeader(
            icon: "clock",
            title: "Clock",
            subtitle: "Multiple time zones at a glance"
        ) {
            Toggle("24-hour", isOn: $service.use24Hour)
                .toggleStyle(.switch)
                .controlSize(.small)
            Button { showingPicker = true } label: {
                Label("Add Time Zone", systemImage: "plus")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if service.timezones.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "clock").font(.system(size: 36)).foregroundStyle(.secondary)
                Text("No time zones added").font(.title3)
                Button("Add Time Zone") { showingPicker = true }.buttonStyle(.borderedProminent)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: Spacing.sm) {
                    ForEach(service.timezones, id: \.self) { id in
                        clockCard(identifier: id)
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }

    private func clockCard(identifier: String) -> some View {
        let tz = TimeZone(identifier: identifier) ?? .current
        return HStack(spacing: Spacing.md) {
            Image(systemName: "globe").foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(displayName(tz: tz, identifier: identifier))
                    .font(.system(size: 14, weight: .semibold))
                Text(secondaryLine(tz: tz, identifier: identifier))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatted(now, tz: tz))
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .contentTransition(.numericText())
            Button {
                service.remove(identifier)
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(Spacing.md)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func formatted(_ date: Date, tz: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.dateFormat = service.use24Hour ? "HH:mm:ss" : "h:mm:ss a"
        return f.string(from: date)
    }

    private func displayName(tz: TimeZone, identifier: String) -> String {
        if identifier == TimeZone.current.identifier { return "\(identifier) (Local)" }
        return identifier.replacingOccurrences(of: "_", with: " ")
    }

    private func secondaryLine(tz: TimeZone, identifier: String) -> String {
        let offsetH = Double(tz.secondsFromGMT()) / 3600
        let sign = offsetH >= 0 ? "+" : ""
        let abbreviation = tz.abbreviation() ?? ""
        let offsetText = String(format: "GMT%@%g", sign, offsetH)
        return [abbreviation, offsetText].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func start() {
        now = Date()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in self.now = Date() }
        }
    }

    private func stop() {
        ticker?.invalidate()
        ticker = nil
    }
}

private struct TimezonePickerSheet: View {
    let add: (String) -> Void
    let cancel: () -> Void

    @State private var query: String = ""

    private var allIdentifiers: [String] {
        TimeZone.knownTimeZoneIdentifiers.sorted()
    }

    private var filtered: [String] {
        guard !query.isEmpty else { return allIdentifiers }
        let q = query.lowercased()
        return allIdentifiers.filter { $0.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Time Zone").font(.headline)
                Spacer()
                Button("Cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(12)
            Divider()
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search…", text: $query).textFieldStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            Divider()
            List(filtered, id: \.self) { id in
                Button { add(id) } label: {
                    HStack {
                        Text(id.replacingOccurrences(of: "_", with: " "))
                        Spacer()
                        if let tz = TimeZone(identifier: id) {
                            let h = Double(tz.secondsFromGMT()) / 3600
                            Text(String(format: "GMT%+g", h))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
        }
        .frame(width: 480, height: 480)
    }
}
