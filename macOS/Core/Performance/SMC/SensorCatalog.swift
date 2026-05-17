import Foundation

/// Descriptor for one SMC key we want to probe at startup. The catalog covers
/// both Apple Silicon (M-series) and Intel keys; whichever ones return a
/// valid reading on the running machine become live sensors. Keys that are
/// silently absent on a given SoC are simply dropped from the working set.
struct SensorDescriptor: Hashable, Sendable {

    enum Category: String, CaseIterable, Sendable {
        case temperature
        case fan
        case power
        case voltage
        case current
        case battery

        var symbol: String {
            switch self {
            case .temperature:  return "thermometer.medium"
            case .fan:          return "fanblades"
            case .power:        return "bolt.fill"
            case .voltage:      return "bolt"
            case .current:      return "bolt.batteryblock"
            case .battery:      return "battery.100percent.bolt"
            }
        }

        var displayName: String {
            switch self {
            case .temperature:  return "Temperature"
            case .fan:          return "Fan"
            case .power:        return "Power"
            case .voltage:      return "Voltage"
            case .current:      return "Current"
            case .battery:      return "Battery"
            }
        }
    }

    let key: String
    let label: String
    let category: Category
    let unit: String

    /// `value` comes in the SMC's native scale; some keys need a multiplier
    /// (e.g. millivolts → volts). The transform is applied right after read.
    let transform: @Sendable (Double) -> Double

    init(key: String, label: String, category: Category, unit: String,
         transform: @escaping @Sendable (Double) -> Double = { $0 }) {
        self.key = key
        self.label = label
        self.category = category
        self.unit = unit
        self.transform = transform
    }

    static func == (lhs: SensorDescriptor, rhs: SensorDescriptor) -> Bool {
        lhs.key == rhs.key
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
}

enum SensorCatalog {

    /// Curated set of SMC keys covering both M-series and Intel. Apple's
    /// keys are not formally documented; this list is the same one used by
    /// every open-source SMC tool (Stats / iStat / smckit). Anything that
    /// fails the kSMCGetKeyInfo probe at startup is dropped — so listing
    /// extras is harmless.
    static let candidates: [SensorDescriptor] = [
        // — Temperatures (Apple Silicon) —
        .init(key: "Tp01", label: "CPU performance core 1", category: .temperature, unit: "°C"),
        .init(key: "Tp05", label: "CPU performance core 2", category: .temperature, unit: "°C"),
        .init(key: "Tp09", label: "CPU performance core 3", category: .temperature, unit: "°C"),
        .init(key: "Tp0D", label: "CPU performance core 4", category: .temperature, unit: "°C"),
        .init(key: "Tp0b", label: "CPU efficiency core 1", category: .temperature, unit: "°C"),
        .init(key: "Tp0f", label: "CPU efficiency core 2", category: .temperature, unit: "°C"),
        .init(key: "Tg05", label: "GPU 1", category: .temperature, unit: "°C"),
        .init(key: "Tg0D", label: "GPU 2", category: .temperature, unit: "°C"),
        .init(key: "Tg0L", label: "GPU 3", category: .temperature, unit: "°C"),
        .init(key: "Tg0T", label: "GPU 4", category: .temperature, unit: "°C"),
        .init(key: "Tm02", label: "DRAM", category: .temperature, unit: "°C"),
        .init(key: "TaLP", label: "Airflow left", category: .temperature, unit: "°C"),
        .init(key: "TaRF", label: "Airflow right", category: .temperature, unit: "°C"),
        .init(key: "TH0x", label: "NAND", category: .temperature, unit: "°C"),
        .init(key: "TB1T", label: "Battery 1", category: .temperature, unit: "°C"),
        .init(key: "TB2T", label: "Battery 2", category: .temperature, unit: "°C"),

        // — Temperatures (Intel fallbacks) —
        .init(key: "TC0P", label: "CPU proximity", category: .temperature, unit: "°C"),
        .init(key: "TC0D", label: "CPU die", category: .temperature, unit: "°C"),
        .init(key: "TG0P", label: "GPU proximity", category: .temperature, unit: "°C"),
        .init(key: "TG0D", label: "GPU die", category: .temperature, unit: "°C"),
        .init(key: "TA0P", label: "Ambient", category: .temperature, unit: "°C"),
        .init(key: "TB0T", label: "Battery", category: .temperature, unit: "°C"),

        // — Fan RPM —
        .init(key: "F0Ac", label: "Fan 1", category: .fan, unit: "rpm"),
        .init(key: "F1Ac", label: "Fan 2", category: .fan, unit: "rpm"),
        .init(key: "F2Ac", label: "Fan 3", category: .fan, unit: "rpm"),

        // — Power (Watts) —
        .init(key: "PSTR", label: "System total", category: .power, unit: "W"),
        .init(key: "PCPC", label: "CPU package", category: .power, unit: "W"),
        .init(key: "PCPG", label: "GPU package", category: .power, unit: "W"),
        .init(key: "PDTR", label: "DC In", category: .power, unit: "W"),
        .init(key: "PPBR", label: "Battery", category: .power, unit: "W"),

        // — Voltage —
        .init(key: "VP0R", label: "12V rail", category: .voltage, unit: "V"),
        .init(key: "Vp0C", label: "CPU core", category: .voltage, unit: "V"),

        // — Battery telemetry —
        .init(key: "B0AC", label: "Battery amperage", category: .current, unit: "A",
              transform: { $0 / 1000.0 })
    ]
}
