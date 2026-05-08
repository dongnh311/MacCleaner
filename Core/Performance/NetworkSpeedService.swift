import Foundation
import Darwin

struct NetworkSample: Sendable, Hashable {
    let bytesInPerSec: UInt64
    let bytesOutPerSec: UInt64
    /// True if a `utun*` tunnel interface is currently present — best-effort
    /// VPN detection without needing NetworkExtension entitlements.
    let isVPNActive: Bool

    static let zero = NetworkSample(bytesInPerSec: 0, bytesOutPerSec: 0, isVPNActive: false)
}

struct NetworkInterfaceInfo: Sendable, Hashable, Identifiable {
    var id: String { name }
    let name: String
    let isPhysical: Bool
    let bytesInTotal: UInt64
    let bytesOutTotal: UInt64
}

/// Reads cumulative byte counters from physical network interfaces (en*) and
/// derives a per-second rate by diffing successive samples. Skips loopback,
/// VPN tunnels and AWDL/llw/anpi virtual interfaces. Also keeps a 60-sample
/// rolling history for sparkline rendering.
actor NetworkSpeedService {

    private var last: (bytesIn: UInt64, bytesOut: UInt64, at: Date)?
    private var inHistory: [Double] = []
    private var outHistory: [Double] = []
    private let historyCapacity: Int = 60

    func sample() -> NetworkSample {
        let snapshot = Self.readInterfaceTotals()
        let now = Date()
        defer { last = (snapshot.bytesIn, snapshot.bytesOut, now) }
        guard let last else { return NetworkSample(bytesInPerSec: 0, bytesOutPerSec: 0, isVPNActive: snapshot.vpnActive) }
        let dt = now.timeIntervalSince(last.at)
        guard dt > 0 else { return NetworkSample(bytesInPerSec: 0, bytesOutPerSec: 0, isVPNActive: snapshot.vpnActive) }
        let inDelta = snapshot.bytesIn >= last.bytesIn ? snapshot.bytesIn - last.bytesIn : 0
        let outDelta = snapshot.bytesOut >= last.bytesOut ? snapshot.bytesOut - last.bytesOut : 0
        let inRate = UInt64(Double(inDelta) / dt)
        let outRate = UInt64(Double(outDelta) / dt)

        appendHistory(in: Double(inRate), out: Double(outRate))
        return NetworkSample(bytesInPerSec: inRate, bytesOutPerSec: outRate, isVPNActive: snapshot.vpnActive)
    }

    func history() -> (inHistory: [Double], outHistory: [Double]) {
        (inHistory, outHistory)
    }

    /// Sample + post-sample history snapshot in one actor hop. Saves a
    /// suspension on the menu-bar tick (which fetches both each second).
    func sampleWithHistory() -> (sample: NetworkSample, inHistory: [Double], outHistory: [Double]) {
        let snap = sample()
        return (snap, inHistory, outHistory)
    }

    func interfaces() -> [NetworkInterfaceInfo] {
        Self.readInterfaceList()
    }

    private func appendHistory(in inRate: Double, out outRate: Double) {
        inHistory.append(inRate)
        outHistory.append(outRate)
        if inHistory.count > historyCapacity {
            inHistory.removeFirst(inHistory.count - historyCapacity)
        }
        if outHistory.count > historyCapacity {
            outHistory.removeFirst(outHistory.count - historyCapacity)
        }
    }

    private struct InterfaceTotals {
        let bytesIn: UInt64
        let bytesOut: UInt64
        let vpnActive: Bool
    }

    private nonisolated static func readInterfaceTotals() -> InterfaceTotals {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else {
            return InterfaceTotals(bytesIn: 0, bytesOut: 0, vpnActive: false)
        }
        defer { freeifaddrs(ifaddr) }

        var inSum: UInt64 = 0
        var outSum: UInt64 = 0
        var vpn = false
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            defer { ptr = cur.pointee.ifa_next }
            guard let addr = cur.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            let name = String(cString: cur.pointee.ifa_name)
            if name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp") {
                vpn = true
                continue
            }
            // Whitelist Ethernet/Wi-Fi (en*) only — that excludes lo0/utun/awdl/llw/anpi/bridge/gif/stf.
            guard name.hasPrefix("en") else { continue }
            if let raw = cur.pointee.ifa_data {
                let data = raw.assumingMemoryBound(to: if_data.self)
                inSum &+= UInt64(data.pointee.ifi_ibytes)
                outSum &+= UInt64(data.pointee.ifi_obytes)
            }
        }
        return InterfaceTotals(bytesIn: inSum, bytesOut: outSum, vpnActive: vpn)
    }

    /// Full per-interface list for the Network page. Returns physical (en*)
    /// and tunnel (utun*) interfaces with their cumulative byte counts.
    private nonisolated static func readInterfaceList() -> [NetworkInterfaceInfo] {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }

        var byName: [String: NetworkInterfaceInfo] = [:]
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            defer { ptr = cur.pointee.ifa_next }
            guard let addr = cur.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            let name = String(cString: cur.pointee.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("utun") || name.hasPrefix("ppp") || name.hasPrefix("ipsec") else { continue }
            let physical = name.hasPrefix("en")
            if let raw = cur.pointee.ifa_data {
                let data = raw.assumingMemoryBound(to: if_data.self)
                byName[name] = NetworkInterfaceInfo(
                    name: name,
                    isPhysical: physical,
                    bytesInTotal: UInt64(data.pointee.ifi_ibytes),
                    bytesOutTotal: UInt64(data.pointee.ifi_obytes)
                )
            }
        }
        return byName.values.sorted { $0.name < $1.name }
    }
}
