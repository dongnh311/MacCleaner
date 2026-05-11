import SwiftUI

@MainActor
struct SensorsView: View {

    @EnvironmentObject private var container: AppContainer

    @State private var readings: [SensorReading] = []
    @State private var firstSampleAt: Date?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .refreshTask(every: 3) { await sampleNow() }
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
            .cardStyle(radius: 8, withShadow: false)
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
            LiveSparkline(interval: 3, tint: color(for: reading), fill: true) {
                await container.sensorsService.history(for: reading.descriptor.key)
            }
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

