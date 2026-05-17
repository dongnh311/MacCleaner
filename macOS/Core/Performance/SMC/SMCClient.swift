import Foundation
import IOKit
import os.log

/// Thin Swift wrapper around the AppleSMC IOService. Handles connect /
/// disconnect, sends kSMCGetKeyInfo + kSMCReadKey, and returns a typed
/// `SMCSample`. One client per process is enough — keep it long-lived.
final class SMCClient: @unchecked Sendable {

    private var connection: io_connect_t = 0
    private let lock = NSLock()
    private var connected: Bool = false

    init() throws {
        try connect()
    }

    deinit {
        if connection != 0 { IOServiceClose(connection) }
    }

    private func connect() throws {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { throw SMCError.serviceUnavailable }
        defer { IOObjectRelease(service) }

        var conn: io_connect_t = 0
        let kr = IOServiceOpen(service, mach_task_self_, 0, &conn)
        guard kr == kIOReturnSuccess else { throw SMCError.openFailed(kr) }
        self.connection = conn
        self.connected = true
    }

    /// Reads one SMC key. Returns nil if the key isn't supported on this
    /// machine — common across SoC generations, so the caller treats it as
    /// "skip this sensor" rather than an error worth surfacing.
    func read(_ key: String) -> SMCSample? {
        lock.lock(); defer { lock.unlock() }
        guard connected else { return nil }

        // 1) Ask SMC how big this key is + what type (kSMCGetKeyInfo = 9).
        var input = SMCBridge.KeyData()
        input.key = SMCBridge.encode(key)
        input.data8 = SMCBridge.Command.getKeyInfo.rawValue
        var output = SMCBridge.KeyData()
        guard call(input: &input, output: &output) else { return nil }
        guard output.result == 0 else { return nil }

        let dataSize = output.keyInfo.dataSize
        let dataType = SMCBridge.decode(output.keyInfo.dataType)

        guard dataSize > 0 && dataSize <= 32 else { return nil }

        // 2) Now read the value (kSMCReadKey = 5). Reuse the type info we
        //    just got — SMC wants it echoed back.
        input = SMCBridge.KeyData()
        input.key = SMCBridge.encode(key)
        input.keyInfo.dataSize = dataSize
        input.keyInfo.dataType = output.keyInfo.dataType
        input.data8 = SMCBridge.Command.readKey.rawValue
        output = SMCBridge.KeyData()
        guard call(input: &input, output: &output) else { return nil }
        guard output.result == 0 else { return nil }

        let bytes = bytesArray(output.bytes, length: Int(dataSize))
        guard let value = decodeValue(bytes: bytes, type: dataType) else { return nil }
        return SMCSample(key: key, dataType: dataType, value: value)
    }

    private func call(input: inout SMCBridge.KeyData, output: inout SMCBridge.KeyData) -> Bool {
        var outSize = MemoryLayout<SMCBridge.KeyData>.stride
        let kr = withUnsafePointer(to: &input) { (inPtr: UnsafePointer<SMCBridge.KeyData>) -> kern_return_t in
            withUnsafeMutablePointer(to: &output) { (outPtr: UnsafeMutablePointer<SMCBridge.KeyData>) -> kern_return_t in
                IOConnectCallStructMethod(
                    self.connection,
                    SMCBridge.kSMCHandleYPCEvent,
                    UnsafeRawPointer(inPtr),
                    MemoryLayout<SMCBridge.KeyData>.stride,
                    UnsafeMutableRawPointer(outPtr),
                    &outSize
                )
            }
        }
        return kr == kIOReturnSuccess
    }

    /// Pulls `length` bytes out of the 32-byte tuple inside the SMC packet.
    private func bytesArray(_ bytes: SMCBridge.SMCBytes32, length: Int) -> [UInt8] {
        var copy = bytes
        return withUnsafeBytes(of: &copy) { ptr -> [UInt8] in
            Array(ptr.prefix(length))
        }
    }

    /// Decode the SMC payload into a Double according to its declared type.
    /// Covers every type used by the keys we probe — float, fixed point,
    /// unsigned ints, flag. Unknown types return nil so the caller can
    /// surface "—" instead of fabricating a value.
    private func decodeValue(bytes: [UInt8], type: String) -> Double? {
        guard let kind = SMCDataType(rawValue: type) else { return nil }
        switch kind {
        case .float32:
            // Little-endian IEEE 754 float — Apple Silicon temps and powers.
            guard bytes.count >= 4 else { return nil }
            let raw = UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
            return Double(Float(bitPattern: raw))
        case .sp78:
            // Signed Q8.7 fixed point — Intel temps.
            guard bytes.count >= 2 else { return nil }
            let high = Int16(Int8(bitPattern: bytes[0]))
            let low = Int16(bytes[1])
            let raw = (high << 8) | low
            return Double(raw) / 256.0
        case .fpe2:
            // Unsigned Q14.2 fixed point — Intel fan RPM.
            guard bytes.count >= 2 else { return nil }
            let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(raw) / 4.0
        case .uint8:
            guard bytes.count >= 1 else { return nil }
            return Double(bytes[0])
        case .uint16:
            guard bytes.count >= 2 else { return nil }
            return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
        case .uint32:
            guard bytes.count >= 4 else { return nil }
            let v = (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
            return Double(v)
        case .int8:
            guard bytes.count >= 1 else { return nil }
            return Double(Int8(bitPattern: bytes[0]))
        case .int16:
            guard bytes.count >= 2 else { return nil }
            let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(Int16(bitPattern: raw))
        case .flag:
            guard bytes.count >= 1 else { return nil }
            return bytes[0] == 0 ? 0 : 1
        }
    }
}

/// Raw values are exactly the 4-byte ASCII tags the SMC kernel returns
/// alongside each reading. Padded with spaces where the type name is < 4
/// characters (a hard kernel constraint — strings must be 4 bytes).
enum SMCDataType: String {
    case float32 = "flt "
    case sp78    = "sp78"
    case fpe2    = "fpe2"
    case uint8   = "ui8 "
    case uint16  = "ui16"
    case uint32  = "ui32"
    case int8    = "si8 "
    case int16   = "si16"
    case flag    = "flag"
}
