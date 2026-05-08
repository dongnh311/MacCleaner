import SwiftUI

@MainActor
struct SensorsView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var readings: [SensorReading] = []
    @State private var refreshTimer: Timer?
    @State private var firstSampleAt: Date?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .onAppear { start() }
        .onDisappear { stop() }
    }

    private var header: some View {
        ModuleHeader(
            icon: "thermometer.medium",
            title: "Sensors",
            subtitle: "Live SMC readings — temperatures, fans, power, voltage"
        ) {
            Button { Task { await sampleNow() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r")
        }
    }

    @ViewBuilder
    private var content: some View {
        if firstSampleAt == nil {
            VStack(spacing: Spacing.sm) {
                Spacer()
                ProgressView().controlSize(.large)
                Text("Probing SMC keys…").foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if readings.isEmpty {
            VStack(spacing: Spacing.sm) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("No SMC sensors available")
                    .font(.title3)
                Text("AppleSMC declined every catalog key. Some VMs and stripped-down installs hide the service entirely.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(SensorDescriptor.Category.allCases, id: \.self) { cat in
                        let bucket = readings.filter { $0.descriptor.category == cat }
                        if !bucket.isEmpty {
                            section(title: cat.displayName, symbol: cat.symbol, readings: bucket)
                        }
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }

    private func section(title: String, symbol: String, readings: [SensorReading]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: symbol).foregroundStyle(.tint)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                ForEach(readings) { r in
                    row(reading: r)
                    if r.id != readings.last?.id { Divider() }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
        }
    }

    private func row(reading: SensorReading) -> some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 1) {
                Text(reading.descriptor.label)
                    .font(.system(size: 13))
                Text(reading.descriptor.key)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            SensorSparkline(key: reading.descriptor.key, tint: color(for: reading))
                .frame(width: 80, height: 22)
            Text(reading.formatted)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(color(for: reading))
                .contentTransition(.numericText())
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 8)
    }

    private func color(for reading: SensorReading) -> Color {
        switch reading.descriptor.category {
        case .temperature:
            switch reading.value {
            case ..<60:   return .green
            case ..<80:   return .orange
            default:      return .red
            }
        case .fan:        return reading.value > 0 ? .blue : .secondary
        case .power:      return reading.value > 50 ? .orange : .primary
        default:          return .primary
        }
    }

    // MARK: - Lifecycle

    private func start() {
        Task { await sampleNow() }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in await sampleNow() }
        }
    }

    private func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func sampleNow() async {
        let next = await container.sensorsService.sample()
        self.readings = next.sorted { lhs, rhs in
            if lhs.descriptor.category == rhs.descriptor.category {
                return lhs.descriptor.label < rhs.descriptor.label
            }
            return categoryOrder(lhs.descriptor.category) < categoryOrder(rhs.descriptor.category)
        }
        if firstSampleAt == nil { firstSampleAt = Date() }
    }

    private func categoryOrder(_ c: SensorDescriptor.Category) -> Int {
        switch c {
        case .temperature: return 0
        case .fan:         return 1
        case .power:       return 2
        case .voltage:     return 3
        case .current:     return 4
        case .battery:     return 5
        }
    }
}

/// Pulls the per-sensor history out of `SensorsService` on a 3-second tick
/// without forcing the parent view to plumb the buffers itself. Lightweight
/// — just a Sparkline backed by a small @State buffer.
private struct SensorSparkline: View {
    let key: String
    let tint: Color
    @EnvironmentObject private var container: AppContainer
    @State private var values: [Double] = []
    @State private var ticker: Timer?

    var body: some View {
        SparklineView(values: values, tint: tint, fill: true, maxValue: nil)
            .onAppear { start() }
            .onDisappear { ticker?.invalidate() }
    }

    private func start() {
        Task { await reload() }
        ticker = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            Task { @MainActor in await reload() }
        }
    }

    private func reload() async {
        values = await container.sensorsService.history(for: key)
    }
}
