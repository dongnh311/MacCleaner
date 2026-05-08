import Foundation

/// Live reading for one sensor, ready to render: original descriptor for
/// labelling, current numeric value (post-transform), and raw SMC sample.
struct SensorReading: Identifiable, Sendable {
    var id: String { descriptor.key }
    let descriptor: SensorDescriptor
    let value: Double
    let sampledAt: Date

    var formatted: String {
        switch descriptor.category {
        case .temperature:
            return String(format: "%.0f°C", value)
        case .fan:
            return String(format: "%.0f rpm", value)
        case .power:
            return String(format: "%.1f W", value)
        case .voltage:
            return String(format: "%.2f V", value)
        case .current:
            return String(format: "%.2f A", value)
        case .battery:
            return String(format: "%.0f", value)
        }
    }
}

/// Owns the SMC client and the working set of sensors. On first use it
/// probes every catalog candidate once; whichever come back with a
/// non-zero reading become the live working set. Subsequent samples only
/// re-read the working set so each refresh stays cheap.
actor SensorsService {

    private let client: SMCClient?
    private(set) var workingSet: [SensorDescriptor] = []
    private var probed: Bool = false
    /// Per-sensor 60-sample rolling history. Keyed by SMC key.
    private var historyByKey: [String: [Double]] = [:]
    private let historyCapacity: Int = 60

    init() {
        self.client = try? SMCClient()
    }

    func history(for key: String) -> [Double] {
        historyByKey[key] ?? []
    }

    /// First call: probe the catalog. Subsequent calls: re-read the working
    /// set. Returns readings ordered by category then by descriptor order.
    func sample() async -> [SensorReading] {
        guard let client else { return [] }
        if !probed {
            workingSet = probeCatalog(using: client)
            probed = true
            Log.scanner.info("SensorsService probed: \(self.workingSet.count) live sensors")
        }
        let now = Date()
        var out: [SensorReading] = []
        for desc in workingSet {
            guard let sample = client.read(desc.key) else { continue }
            let value = desc.transform(sample.value)
            historyByKey[desc.key, default: []].append(value)
            if let count = historyByKey[desc.key]?.count, count > historyCapacity {
                historyByKey[desc.key]?.removeFirst(count - historyCapacity)
            }
            out.append(SensorReading(descriptor: desc, value: value, sampledAt: now))
        }
        return out
    }

    /// Force a rescan if the user hot-plugs hardware or unlocks a sensor
    /// (rare, but the SMC catalog can shift after firmware updates).
    func reprobe() {
        probed = false
        workingSet = []
    }

    private func probeCatalog(using client: SMCClient) -> [SensorDescriptor] {
        var keep: [SensorDescriptor] = []
        for desc in SensorCatalog.candidates {
            guard let sample = client.read(desc.key) else { continue }
            let value = desc.transform(sample.value)
            // Reject obvious garbage: zero (sensor unsupported but key
            // existed) and values out of physically plausible bounds.
            switch desc.category {
            case .temperature:
                guard value > 0, value < 130 else { continue }
            case .fan:
                guard value >= 0, value < 20_000 else { continue }
            case .power:
                guard value > 0, value < 500 else { continue }
            case .voltage:
                guard value > 0, value < 50 else { continue }
            case .current:
                guard abs(value) < 50 else { continue }
            case .battery:
                break
            }
            keep.append(desc)
        }
        return keep
    }

    // MARK: - Convenience digests

    /// Average of all CPU-core temperatures, or nil if none surfaced. Used
    /// by the menu bar tile so we show one number, not 8.
    func cpuTemperature() async -> Double? {
        let readings = await sample()
        return Self.cpuTemperature(in: readings)
    }

    func gpuTemperature() async -> Double? {
        let readings = await sample()
        return Self.gpuTemperature(in: readings)
    }

    func fanRPM() async -> Double? {
        let readings = await sample()
        return Self.fanRPM(in: readings)
    }

    /// One sample → CPU/GPU/Fan digests in a single actor hop. Cuts three
    /// consecutive `await sample()` calls from the menu-bar tick down to one.
    func digest() async -> (cpuTemperature: Double?, gpuTemperature: Double?, fanRPM: Double?) {
        let readings = await sample()
        return (
            Self.cpuTemperature(in: readings),
            Self.gpuTemperature(in: readings),
            Self.fanRPM(in: readings)
        )
    }

    // MARK: - Pure aggregations

    private static func cpuTemperature(in readings: [SensorReading]) -> Double? {
        let cpu = readings.filter { $0.descriptor.key.hasPrefix("Tp") || $0.descriptor.key.hasPrefix("TC") }
        guard !cpu.isEmpty else { return nil }
        return cpu.map(\.value).reduce(0, +) / Double(cpu.count)
    }

    private static func gpuTemperature(in readings: [SensorReading]) -> Double? {
        let gpu = readings.filter { $0.descriptor.key.hasPrefix("Tg") || $0.descriptor.key.hasPrefix("TG") }
        guard !gpu.isEmpty else { return nil }
        return gpu.map(\.value).reduce(0, +) / Double(gpu.count)
    }

    private static func fanRPM(in readings: [SensorReading]) -> Double? {
        let fans = readings.filter { $0.descriptor.category == .fan }
        guard !fans.isEmpty else { return nil }
        return fans.map(\.value).max()
    }
}
