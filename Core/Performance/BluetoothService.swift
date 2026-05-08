import Foundation
import IOBluetooth

/// One paired Bluetooth device. Battery values are optional because most
/// classic-BT keyboards/mice don't expose any; AirPods report via a few
/// private KVC keys that we sample best-effort.
struct BluetoothDevice: Identifiable, Sendable, Hashable {

    enum Kind: String, Sendable {
        case headphones, keyboard, mouse, gamepad, phone, watch, other
        var symbol: String {
            switch self {
            case .headphones: return "airpodspro"
            case .keyboard:   return "keyboard"
            case .mouse:      return "magicmouse"
            case .gamepad:    return "gamecontroller"
            case .phone:      return "iphone"
            case .watch:      return "applewatch"
            case .other:      return "dot.radiowaves.left.and.right"
            }
        }
    }

    let id: String          // MAC address
    let name: String
    let isConnected: Bool
    let kind: Kind
    /// 0–100, single-battery devices (most non-AirPods).
    let batteryPercent: Int?
    let batteryLeft: Int?
    let batteryRight: Int?
    let batteryCase: Int?

    /// Lowest reported pod when AirPods, else single battery, else nil.
    var displayBattery: Int? {
        let pods = [batteryLeft, batteryRight, batteryCase].compactMap { $0 }.filter { $0 > 0 }
        if !pods.isEmpty { return pods.min() }
        return batteryPercent
    }
}

actor BluetoothService {

    /// Snapshot of all paired devices. Cheap to call (just KVC lookups
    /// on already-cached IOBluetooth objects) — safe to poll every few
    /// seconds from the menu bar loop.
    func snapshot() -> [BluetoothDevice] {
        Self.read()
    }

    private nonisolated static func read() -> [BluetoothDevice] {
        guard let raw = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return [] }
        return raw.map { device in
            let address = device.addressString ?? UUID().uuidString
            let name = device.name ?? "Unknown"
            let connected = device.isConnected()

            // Battery readings via private KVC keys (`batteryPercentSingle`
            // etc.) used to work on older macOS, but Apple withdrew them —
            // calling `value(forKey:)` now raises NSUnknownKeyException and
            // crashes the app. Pure Swift can't catch ObjC exceptions, so
            // until we wire up an ObjC bridging file we just skip battery
            // entirely. AirPods + standard BLE batteries can come back via
            // CoreBluetooth GATT 0x2A19 in a future iteration.
            return BluetoothDevice(
                id: address,
                name: name,
                isConnected: connected,
                kind: kind(for: device, name: name),
                batteryPercent: nil,
                batteryLeft: nil,
                batteryRight: nil,
                batteryCase: nil
            )
        }
        .sorted { lhs, rhs in
            if lhs.isConnected != rhs.isConnected { return lhs.isConnected }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private nonisolated static func kind(for device: IOBluetoothDevice, name: String) -> BluetoothDevice.Kind {
        let major = UInt32(device.classOfDevice) >> 8 & 0x1F
        let minor = UInt32(device.classOfDevice) >> 2 & 0x3F
        switch major {
        case 0x01: return .other       // Computer
        case 0x02: return .phone       // Phone
        case 0x04:                     // Audio/Video
            return .headphones
        case 0x05:                     // Peripheral (keyboard/mouse/joystick)
            switch minor {
            case 0x10: return .keyboard
            case 0x20: return .mouse
            case 0x30: return .keyboard  // keyboard+pointing
            default: return name.lowercased().contains("controller") ? .gamepad : .other
            }
        case 0x07: return .watch
        default:
            let lower = name.lowercased()
            if lower.contains("airpod") || lower.contains("beats") || lower.contains("headphone") { return .headphones }
            if lower.contains("keyboard") { return .keyboard }
            if lower.contains("mouse") || lower.contains("magic") { return .mouse }
            if lower.contains("watch") { return .watch }
            return .other
        }
    }
}
