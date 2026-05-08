import Foundation
import IOKit

/// Pure-Swift bridge to AppleSMC. Mirrors the userland protocol used by every
/// Mac SMC tool (iStat Menus, Stats, smckit) — open the IOService, send a
/// kSMCGetKeyInfo to learn type+size, then kSMCReadKey to get the bytes.
///
/// Layout: the SMC IOKit selector takes an 80-byte struct in/out. Swift's
/// tuple-of-32-UInt8 packs identically to C's `char[32]` for these fixed
/// primitives — confirmed by SMCKit / Stats. We allocate the struct in
/// Swift and let `IOConnectCallStructMethod` write into it directly.
enum SMCBridge {

    /// IOConnect selector for AppleSMC user client. Always `2`
    /// (kSMCHandleYPCEvent) — the SMC sub-command (5 = readKey,
    /// 9 = getKeyInfo) is encoded in `data8`.
    static let kSMCHandleYPCEvent: UInt32 = 2

    enum Command: UInt8 {
        case readKey = 5
        case getKeyInfo = 9
    }

    /// Selectors expect / return 80-byte SMCKeyData_t. Layout MUST match
    /// the C struct exactly — Swift respects struct boundaries when fields
    /// are themselves structs, so we nest the inner records and rely on
    /// Swift's natural alignment to add the trailing pads (3 bytes after
    /// keyInfo, 1 byte after data8) the kernel expects.
    struct KeyDataVers {
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: UInt8 = 0
        var release: UInt16 = 0
    }

    struct KeyDataPLimit {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    struct KeyDataKeyInfo {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
        // C trailing pad: keyInfo struct must round up to 4-byte boundary so
        // dataAttributes (1 byte) is followed by 3 pad bytes. Swift won't
        // add these for us — explicit fields keep the struct exactly 12B.
        var _pad0: UInt8 = 0
        var _pad1: UInt8 = 0
        var _pad2: UInt8 = 0
    }

    struct KeyData {
        var key: UInt32 = 0
        var vers: KeyDataVers = KeyDataVers()
        var pLimit: KeyDataPLimit = KeyDataPLimit()
        var keyInfo: KeyDataKeyInfo = KeyDataKeyInfo()
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        // 1 byte pad so the following UInt32 sits on a 4-byte boundary —
        // matches C's implicit struct padding.
        var _pad: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: SMCBytes32 = SMCBytes32()
    }

    struct SMCBytes32 {
        var b00: UInt8 = 0; var b01: UInt8 = 0; var b02: UInt8 = 0; var b03: UInt8 = 0
        var b04: UInt8 = 0; var b05: UInt8 = 0; var b06: UInt8 = 0; var b07: UInt8 = 0
        var b08: UInt8 = 0; var b09: UInt8 = 0; var b10: UInt8 = 0; var b11: UInt8 = 0
        var b12: UInt8 = 0; var b13: UInt8 = 0; var b14: UInt8 = 0; var b15: UInt8 = 0
        var b16: UInt8 = 0; var b17: UInt8 = 0; var b18: UInt8 = 0; var b19: UInt8 = 0
        var b20: UInt8 = 0; var b21: UInt8 = 0; var b22: UInt8 = 0; var b23: UInt8 = 0
        var b24: UInt8 = 0; var b25: UInt8 = 0; var b26: UInt8 = 0; var b27: UInt8 = 0
        var b28: UInt8 = 0; var b29: UInt8 = 0; var b30: UInt8 = 0; var b31: UInt8 = 0
    }

    /// Encode a 4-character key like "TC0P" into the big-endian UInt32 the
    /// SMC kernel expects.
    static func encode(_ fourCC: String) -> UInt32 {
        precondition(fourCC.utf8.count == 4, "SMC keys must be exactly 4 ASCII chars")
        var result: UInt32 = 0
        for byte in fourCC.utf8 {
            result = (result << 8) | UInt32(byte)
        }
        return result
    }

    /// Decode a UInt32 four-char-code back to a 4-letter String.
    static func decode(_ value: UInt32) -> String {
        let bytes: [UInt8] = [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "????"
    }
}

/// One reading from a single SMC key — a typed numeric value plus the raw
/// SMC type code so the UI can format units (°C, RPM, W, V).
struct SMCSample: Sendable {
    let key: String
    let dataType: String     // e.g. "flt ", "sp78", "fpe2", "ui16"
    let value: Double
}

/// Errors out of the SMC bridge that callers might want to log but rarely
/// surface to the user — most just mean "this key isn't on this machine".
enum SMCError: Error {
    case serviceUnavailable
    case openFailed(kern_return_t)
    case callFailed(kern_return_t)
    case keyNotFound(String)
    case unsupportedType(String)
}
