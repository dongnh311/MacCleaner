import Foundation
import Darwin

struct NetworkSample: Sendable, Hashable {
    let bytesInPerSec: UInt64
    let bytesOutPerSec: UInt64

    static let zero = NetworkSample(bytesInPerSec: 0, bytesOutPerSec: 0)
}

/// Reads cumulative byte counters from physical network interfaces (en*) and
/// derives a per-second rate by diffing successive samples. Skips loopback,
/// VPN tunnels and AWDL/llw/anpi virtual interfaces.
actor NetworkSpeedService {

    private var last: (bytesIn: UInt64, bytesOut: UInt64, at: Date)?

    func sample() -> NetworkSample {
        let totals = Self.readInterfaceTotals()
        let now = Date()
        defer { last = (totals.0, totals.1, now) }
        guard let last else { return .zero }
        let dt = now.timeIntervalSince(last.at)
        guard dt > 0 else { return .zero }
        let inDelta = totals.0 >= last.bytesIn ? totals.0 - last.bytesIn : 0
        let outDelta = totals.1 >= last.bytesOut ? totals.1 - last.bytesOut : 0
        return NetworkSample(
            bytesInPerSec: UInt64(Double(inDelta) / dt),
            bytesOutPerSec: UInt64(Double(outDelta) / dt)
        )
    }

    private nonisolated static func readInterfaceTotals() -> (UInt64, UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }

        var inSum: UInt64 = 0
        var outSum: UInt64 = 0
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            defer { ptr = cur.pointee.ifa_next }
            guard let addr = cur.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            let name = String(cString: cur.pointee.ifa_name)
            // Whitelist Ethernet/Wi-Fi (en*) only — that excludes lo0/utun/awdl/llw/anpi/bridge/gif/stf.
            guard name.hasPrefix("en") else { continue }
            if let raw = cur.pointee.ifa_data {
                let data = raw.assumingMemoryBound(to: if_data.self)
                inSum &+= UInt64(data.pointee.ifi_ibytes)
                outSum &+= UInt64(data.pointee.ifi_obytes)
            }
        }
        return (inSum, outSum)
    }
}
