import SwiftUI

@MainActor
struct ProcessMonitorView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var processes: [ProcessSnapshot] = []
    @State private var search: String = ""
    @State private var sortOrder: [KeyPathComparator<ProcessSnapshot>] = [.init(\.cpuPercent, order: .reverse)]
    @State private var refreshTimer: Timer?
    @State private var killingPIDs = Set<Int32>()

    private var filtered: [ProcessSnapshot] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let base = q.isEmpty ? processes : processes.filter {
            $0.name.lowercased().contains(q) ||
            $0.user.lowercased().contains(q) ||
            String($0.pid).contains(q)
        }
        return base.sorted(using: sortOrder)
    }

    private var totalCPU: Double {
        processes.reduce(0) { $0 + $1.cpuPercent }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            toolbar
            Divider()
            table
            Divider()
            footer
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    private var header: some View {
        ModuleHeader(
            icon: "cpu",
            title: "Process Monitor",
            subtitle: "Live snapshot — refreshes every 2 seconds"
        ) {
            Text("\(processes.count) running")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Filter by name, user, PID…", text: $search).textFieldStyle(.plain)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    private var table: some View {
        Table(filtered, sortOrder: $sortOrder) {
            TableColumn("PID", value: \.pid) { p in
                Text("\(p.pid)").font(.system(.body, design: .monospaced))
            }.width(min: 60, ideal: 70)
            TableColumn("Name", value: \.name) { p in
                HStack(spacing: 6) {
                    Text(p.name).lineLimit(1)
                    if killingPIDs.contains(p.pid) {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            TableColumn("CPU%", value: \.cpuPercent) { p in
                Text(String(format: "%.1f", p.cpuPercent))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(p.cpuPercent > 50 ? .red : (p.cpuPercent > 10 ? .orange : .primary))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }.width(min: 60, ideal: 70)
            TableColumn("Memory", value: \.memoryBytes) { p in
                Text(p.memoryBytes.formattedBytes)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }.width(min: 80, ideal: 100)
            TableColumn("User", value: \.user) { p in
                Text(p.user).foregroundStyle(.secondary)
            }.width(min: 80, ideal: 100)
        }
        .contextMenu(forSelectionType: Int32.self) { ids in
            Button("Quit") { kill(pids: ids, force: false) }
                .disabled(ids.isEmpty)
            Button("Force Quit", role: .destructive) { kill(pids: ids, force: true) }
                .disabled(ids.isEmpty)
        }
    }

    private var footer: some View {
        HStack {
            Text("Total CPU: \(String(format: "%.1f", totalCPU))%")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("Tip: right-click rows to Quit / Force Quit. System processes need admin.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(.regularMaterial)
    }

    private func startTimer() {
        Task { await refresh() }
        let timer = Timer(timeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in await refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refresh() async {
        processes = await container.processMonitor.snapshot()
    }

    private func kill(pids: Set<Int32>, force: Bool) {
        for pid in pids {
            killingPIDs.insert(pid)
            Task { @MainActor in
                let ok = await container.processMonitor.kill(pid: pid, force: force)
                killingPIDs.remove(pid)
                Log.app.info("kill pid=\(pid) force=\(force) ok=\(ok)")
            }
        }
    }
}
