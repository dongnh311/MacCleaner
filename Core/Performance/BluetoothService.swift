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

            // KVC battery keys — AirPods family + some other Apple peripherals.
            // None of these are documented; we try them in order and accept
            // the first non-zero. They return 0–100 as NSNumber.
            let single = batteryValue(device, "batteryPercentSingle")
            let left   = batteryValue(device, "batteryPercentLeft")
            let right  = batteryValue(device, "batteryPercentRight")
            let caseB  = batteryValue(device, "batteryPercentCase")
            // Generic Bluetooth Battery Service GATT char (0x2A19) gets
            // surfaced via "batteryPercent" on some Macs.
            let generic = batteryValue(device, "batteryPercent")

            return BluetoothDevice(
                id: address,
                name: name,
                isConnected: connected,
                kind: kind(for: device, name: name),
                batteryPercent: single ?? generic,
                batteryLeft: left,
                batteryRight: right,
                batteryCase: caseB
            )
        }
        .sorted { lhs, rhs in
            if lhs.isConnected != rhs.isConnected { return lhs.isConnected }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// Try multiple KVC keys safely; returns nil for any non-numeric / 0 value.
    private nonisolated static func batteryValue(_ device: IOBluetoothDevice, _ key: String) -> Int? {
        // `value(forKey:)` throws ObjC exception for unknown keys — wrap in
        // perform with try? equivalent. IOBluetoothDevice inherits NSObject,
        // and all known battery keys are valid KVC keys on Apple peripherals
        // even when they return zero, so a plain `value(forKey:)` is safe.
        if let n = device.value(forKey: key) as? NSNumber {
            let v = n.intValue
            return v > 0 ? min(100, v) : nil
        }
        return nil
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
