import Foundation

/// CXDB v1 codec — strict canonical binary data format.
///
/// Spec: spec/data_bin.md. Decoder consumes the 12-byte-header-prefixed
/// PAYLOAD returned by libcx.cx_to_data_bin (the [u32 LE size] frame is
/// stripped by `CXLib.toDataBin` before this module sees it). Encoder
/// produces a FRAMED buffer suitable for direct hand-off to
/// libcx.cx_from_data_bin.
///
/// Replaces the JSON-string detour previously used by `CXDocument.loads`
/// / `dumps` (audit finding CB-3). Type fidelity preserved: integers
/// stay `Int64` (not coerced to `Double` via JSONSerialization), floats
/// stay `Double`, booleans stay `Bool`, bytes round-trip as `Data`,
/// dates as Foundation `Date`.
///
/// Type mapping:
///   NSNull / nil-as-NSNull        <-> CXDB null
///   Bool                          <-> CXDB false/true
///   Int / Int8…64 / UInt8…32      <-> CXDB int8/int16/int32/int64
///   Float / Double                <-> CXDB float64
///   String                        <-> CXDB string
///   Data                          <-> CXDB bytes
///   Date                          <-> CXDB datetime (placeholder source string in v1)
///   [Any]                         <-> CXDB array
///   [String: Any]                 <-> CXDB map
public enum DataBin {

    // ── Tag bytes (spec/data_bin.md §3.2) ─────────────────────────────────────
    private static let TAG_NULL:        UInt8 = 0x00
    private static let TAG_FALSE:       UInt8 = 0x01
    private static let TAG_TRUE:        UInt8 = 0x02
    private static let TAG_INT8:        UInt8 = 0x10
    private static let TAG_INT16:       UInt8 = 0x11
    private static let TAG_INT32:       UInt8 = 0x12
    private static let TAG_INT64:       UInt8 = 0x13
    private static let TAG_FLOAT64:     UInt8 = 0x20
    private static let TAG_STRING:      UInt8 = 0x30
    private static let TAG_DATE:        UInt8 = 0x31
    private static let TAG_DATETIME:    UInt8 = 0x32
    private static let TAG_BYTES:       UInt8 = 0x33
    private static let TAG_ARRAY:       UInt8 = 0x40
    private static let TAG_ARRAY_EMPTY: UInt8 = 0x41
    private static let TAG_MAP:         UInt8 = 0x50
    private static let TAG_MAP_EMPTY:   UInt8 = 0x51
    private static let TAG_TABLE:       UInt8 = 0x60
    private static let TAG_TABLE_EMPTY: UInt8 = 0x61

    private static let CXDB_MAGIC: [UInt8] = [0x43, 0x58, 0x44, 0x42] // "CXDB"
    private static let CXDB_VERSION:  UInt8 = 0x01
    private static let CXDB_FLAGS_LE: UInt8 = 0x01
    private static let CXDB_DEFAULT_DEPTH: UInt32 = 64

    // ── Decoder ───────────────────────────────────────────────────────────────

    private final class Reader {
        let buf: [UInt8]
        var pos: Int = 0
        var depth: Int = 0
        let maxDepth: Int

        init(_ buf: [UInt8], maxDepth: Int) {
            self.buf = buf
            self.maxDepth = maxDepth
        }

        func need(_ n: Int) throws {
            if pos + n > buf.count {
                throw CXError.parse("cxdb: \(n) bytes requested, \(buf.count - pos) remaining")
            }
        }

        func u8() throws -> UInt8 {
            if pos >= buf.count { throw CXError.parse("cxdb: unexpected end of input") }
            let v = buf[pos]; pos += 1
            return v
        }

        func u16() throws -> UInt16 {
            try need(2)
            let v = UInt16(buf[pos]) | (UInt16(buf[pos + 1]) << 8)
            pos += 2
            return v
        }

        func u32() throws -> UInt32 {
            try need(4)
            let v = UInt32(buf[pos])
                  | (UInt32(buf[pos + 1]) << 8)
                  | (UInt32(buf[pos + 2]) << 16)
                  | (UInt32(buf[pos + 3]) << 24)
            pos += 4
            return v
        }

        func i64() throws -> Int64 {
            try need(8)
            var v: UInt64 = 0
            for i in 0 ..< 8 { v |= UInt64(buf[pos + i]) << (8 * i) }
            pos += 8
            return Int64(bitPattern: v)
        }

        func f64() throws -> Double {
            return Double(bitPattern: UInt64(bitPattern: try i64()))
        }

        func take(_ n: Int) throws -> [UInt8] {
            try need(n)
            let out = Array(buf[pos ..< pos + n])
            pos += n
            return out
        }

        func uvarint() throws -> Int {
            var x = 0
            var shift = 0
            for i in 0 ..< 5 {
                let b = Int(try u8())
                if b < 0x80 {
                    if i == 4 && b > 0x0F { throw CXError.parse("cxdb: varint overflow (>2^32-1)") }
                    if i > 0 && b == 0    { throw CXError.parse("cxdb: non-canonical varint (extra zero byte)") }
                    return x | (b << shift)
                }
                x |= (b & 0x7F) << shift
                shift += 7
            }
            throw CXError.parse("cxdb: varint exceeds 5 bytes")
        }

        func stringPayload() throws -> String {
            let n = try uvarint()
            try need(n)
            let bytes = Array(buf[pos ..< pos + n])
            pos += n
            return String(decoding: bytes, as: UTF8.self)
        }

        func value() throws -> Any {
            depth += 1
            if depth > maxDepth {
                throw CXError.parse("cxdb: recursion depth exceeds limit (\(maxDepth))")
            }
            defer { depth -= 1 }

            let tag = try u8()
            switch tag {
            case TAG_NULL:    return NSNull()
            case TAG_FALSE:   return false
            case TAG_TRUE:    return true
            case TAG_INT8:
                try need(1)
                let v = Int64(Int8(bitPattern: buf[pos])); pos += 1
                return v
            case TAG_INT16:
                let raw = try u16()
                return Int64(Int16(bitPattern: raw))
            case TAG_INT32:
                let raw = try u32()
                return Int64(Int32(bitPattern: raw))
            case TAG_INT64:   return try i64()
            case TAG_FLOAT64: return try f64()
            case TAG_STRING:  return try stringPayload()
            case TAG_BYTES:
                let n = try uvarint()
                return Data(try take(n))
            case TAG_DATE:
                try need(4)
                let yearRaw = UInt16(buf[pos]) | (UInt16(buf[pos + 1]) << 8)
                let year  = Int(Int16(bitPattern: yearRaw))
                let month = Int(buf[pos + 2])
                let day   = Int(buf[pos + 3])
                pos += 4
                var comps = DateComponents()
                comps.year = year; comps.month = month; comps.day = day
                comps.timeZone = TimeZone(identifier: "UTC")
                if let d = Calendar(identifier: .gregorian).date(from: comps) {
                    return d
                }
                return "\(year)-\(month)-\(day)"
            case TAG_DATETIME:
                _ = try take(10) // 10 reserved placeholder bytes
                let srcLen = Int(try u16())
                let src = String(decoding: try take(srcLen), as: UTF8.self)
                let fmt = ISO8601DateFormatter()
                fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let d = fmt.date(from: src) { return d }
                fmt.formatOptions = [.withInternetDateTime]
                if let d = fmt.date(from: src) { return d }
                return src
            case TAG_ARRAY:
                let count = try uvarint()
                if count == 0 {
                    throw CXError.parse("cxdb: array tag 0x40 with count=0; use 0x41 for empty")
                }
                var out: [Any] = []
                out.reserveCapacity(count)
                for _ in 0 ..< count { out.append(try value()) }
                return out
            case TAG_ARRAY_EMPTY: return [Any]()
            case TAG_MAP:
                let count = try uvarint()
                if count == 0 {
                    throw CXError.parse("cxdb: map tag 0x50 with count=0; use 0x51 for empty")
                }
                var out: [String: Any] = [:]
                out.reserveCapacity(count)
                for _ in 0 ..< count {
                    let keyTag = try u8()
                    if keyTag != DataBin.TAG_STRING {
                        throw CXError.parse(String(format: "cxdb: map key must be string; got 0x%02x", keyTag))
                    }
                    let key = try stringPayload()
                    out[key] = try value()
                }
                return out
            case TAG_MAP_EMPTY: return [String: Any]()
            case TAG_TABLE, TAG_TABLE_EMPTY:
                return try tablePayload(tag)
            default:
                throw CXError.parse(String(format: "cxdb: unknown tag 0x%02x at offset %d", tag, pos - 1))
            }
        }

        private func tablePayload(_ tag: UInt8) throws -> Any {
            if tag == DataBin.TAG_TABLE_EMPTY { return [Any]() }
            let colCount = try uvarint()
            var cols: [String] = []
            cols.reserveCapacity(colCount)
            for _ in 0 ..< colCount {
                let keyTag = try u8()
                if keyTag != DataBin.TAG_STRING {
                    throw CXError.parse(String(format: "cxdb: table column name must be string; got 0x%02x", keyTag))
                }
                cols.append(try stringPayload())
                _ = try u8() // column type code (informational; per-cell tags drive decode)
            }
            let rowCount = try uvarint()
            var rows: [[String: Any]] = Array(repeating: [:], count: rowCount)
            for c in 0 ..< colCount {
                for r in 0 ..< rowCount {
                    rows[r][cols[c]] = try value()
                }
            }
            return rows
        }
    }

    /// Decode a CXDB v1 PAYLOAD (12-byte header + value section). The
    /// `[u32 LE size]` frame is expected to have already been stripped by
    /// `CXLib.toDataBin`; pass the raw payload bytes directly.
    public static func decode(_ payload: Data, maxDepth: Int = 64) throws -> Any {
        if payload.count < 12 {
            throw CXError.parse("cxdb: payload too short for 12-byte header")
        }
        let bytes = [UInt8](payload)
        if bytes[0] != 0x43 || bytes[1] != 0x58 || bytes[2] != 0x44 || bytes[3] != 0x42 {
            throw CXError.parse("cxdb: bad magic (expected 'CXDB')")
        }
        if bytes[4] != CXDB_VERSION {
            throw CXError.parse("cxdb: unsupported version \(bytes[4])")
        }
        let flags = bytes[5]
        if (flags & 0xFE) != 0 {
            throw CXError.parse("cxdb: reserved flag bits set in header")
        }
        if (flags & 0x01) == 0 {
            throw CXError.parse("cxdb: only little-endian payloads supported in v1")
        }
        if bytes[10] != 0 || bytes[11] != 0 {
            throw CXError.parse("cxdb: reserved header bytes must be zero")
        }
        let tail = Array(bytes[12 ..< bytes.count])
        return try Reader(tail, maxDepth: maxDepth).value()
    }

    // ── Encoder ───────────────────────────────────────────────────────────────

    private final class Writer {
        var buf: [UInt8] = []

        init() { buf.reserveCapacity(256) }

        func u8(_ v: UInt8)  { buf.append(v) }
        func u16(_ v: UInt16) { buf.append(UInt8(v & 0xFF)); buf.append(UInt8((v >> 8) & 0xFF)) }
        func u32(_ v: UInt32) {
            buf.append(UInt8(v & 0xFF))
            buf.append(UInt8((v >> 8)  & 0xFF))
            buf.append(UInt8((v >> 16) & 0xFF))
            buf.append(UInt8((v >> 24) & 0xFF))
        }
        func i64(_ v: Int64) {
            let u = UInt64(bitPattern: v)
            for i in 0 ..< 8 { buf.append(UInt8((u >> (8 * i)) & 0xFF)) }
        }
        func f64(_ v: Double) { i64(Int64(bitPattern: v.bitPattern)) }
        func raw(_ bytes: [UInt8]) { buf.append(contentsOf: bytes) }

        func uvarint(_ v: Int) {
            var x = UInt64(bitPattern: Int64(v))
            while x >= 0x80 {
                buf.append(UInt8((x & 0x7F) | 0x80))
                x >>= 7
            }
            buf.append(UInt8(x & 0x7F))
        }

        func stringValue(_ s: String) {
            u8(DataBin.TAG_STRING)
            let enc = Array(s.utf8)
            uvarint(enc.count)
            raw(enc)
        }

        func intCanonical(_ v: Int64) {
            switch v {
            case -128 ... 127:
                u8(DataBin.TAG_INT8)
                buf.append(UInt8(bitPattern: Int8(v)))
            case -32768 ... 32767:
                u8(DataBin.TAG_INT16)
                u16(UInt16(bitPattern: Int16(v)))
            case -2_147_483_648 ... 2_147_483_647:
                u8(DataBin.TAG_INT32)
                u32(UInt32(bitPattern: Int32(v)))
            default:
                u8(DataBin.TAG_INT64)
                i64(v)
            }
        }
    }

    private static func encodeValue(_ v: Any?, into w: Writer) throws {
        // nil and NSNull both encode as null
        if v == nil || v is NSNull { w.u8(TAG_NULL); return }

        // Cocoa bridges Bool through __NSCFBoolean which also satisfies
        // `is NSNumber`. Check Bool FIRST so booleans don't slip into the
        // numeric path and get encoded as int.
        if let b = v as? Bool, type(of: v!) == Bool.self || isCFBoolean(v!) {
            w.u8(b ? TAG_TRUE : TAG_FALSE)
            return
        }

        switch v {
        case let n as Int64:  w.intCanonical(n)
        case let n as Int:    w.intCanonical(Int64(n))
        case let n as Int32:  w.intCanonical(Int64(n))
        case let n as Int16:  w.intCanonical(Int64(n))
        case let n as Int8:   w.intCanonical(Int64(n))
        case let n as UInt32: w.intCanonical(Int64(n))
        case let n as UInt16: w.intCanonical(Int64(n))
        case let n as UInt8:  w.intCanonical(Int64(n))
        case let n as UInt:
            if n > UInt(Int64.max) { throw CXError.parse("cxdb: UInt \(n) exceeds i64 range") }
            w.intCanonical(Int64(n))
        case let n as UInt64:
            if n > UInt64(Int64.max) { throw CXError.parse("cxdb: UInt64 \(n) exceeds i64 range") }
            w.intCanonical(Int64(n))
        case let f as Double:
            w.u8(TAG_FLOAT64); w.f64(f)
        case let f as Float:
            w.u8(TAG_FLOAT64); w.f64(Double(f))
        case let n as NSNumber:
            // After the explicit numeric cases above, this catches the
            // bridged-NSNumber path that JSONSerialization produces.
            try encodeNSNumber(n, into: w)
        case let s as String:
            w.stringValue(s)
        case let d as Data:
            w.u8(TAG_BYTES)
            w.uvarint(d.count)
            w.buf.append(contentsOf: [UInt8](d))
        case let date as Date:
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let iso = fmt.string(from: date)
            w.u8(TAG_DATETIME)
            w.raw([UInt8](repeating: 0, count: 10)) // 10 reserved placeholder bytes
            let enc = Array(iso.utf8)
            w.u16(UInt16(enc.count))
            w.raw(enc)
        case let dict as [String: Any]:
            if dict.isEmpty { w.u8(TAG_MAP_EMPTY); return }
            w.u8(TAG_MAP)
            w.uvarint(dict.count)
            for (k, vv) in dict {
                w.stringValue(k)
                try encodeValue(vv, into: w)
            }
        case let dict as NSDictionary:
            if dict.count == 0 { w.u8(TAG_MAP_EMPTY); return }
            w.u8(TAG_MAP)
            w.uvarint(dict.count)
            for (k, vv) in dict {
                guard let ks = k as? String else {
                    throw CXError.parse("cxdb: map keys must be String; got \(type(of: k))")
                }
                w.stringValue(ks)
                try encodeValue(vv, into: w)
            }
        case let arr as [Any]:
            if arr.isEmpty { w.u8(TAG_ARRAY_EMPTY); return }
            w.u8(TAG_ARRAY)
            w.uvarint(arr.count)
            for item in arr { try encodeValue(item, into: w) }
        default:
            throw CXError.parse("cxdb: unsupported type \(type(of: v!))")
        }
    }

    private static func isCFBoolean(_ v: Any) -> Bool {
        // CFBooleanRef bridges to Bool in Swift; on its NSNumber
        // representation, objCType returns "c" (char).
        if let n = v as? NSNumber {
            return String(cString: n.objCType) == "c"
        }
        return false
    }

    private static func encodeNSNumber(_ n: NSNumber, into w: Writer) throws {
        let typ = String(cString: n.objCType)
        switch typ {
        case "c", "B": // char (BOOL) / C++ bool
            w.u8(n.boolValue ? TAG_TRUE : TAG_FALSE)
        case "f", "d":
            w.u8(TAG_FLOAT64); w.f64(n.doubleValue)
        default:
            // Anything else: integer types ("i","s","l","q","I","S","L","Q").
            // Use int64Value; encoder picks the canonical width.
            w.intCanonical(n.int64Value)
        }
    }

    /// Encode a Swift value to a FRAMED CXDB v1 buffer suitable for passing
    /// directly to `CXLib.fromDataBin`. Output layout:
    /// `[u32 LE size][CXDB magic][version][flags][u32 max_depth][u16 reserved][value...]`.
    public static func encode(_ value: Any) throws -> Data {
        let w = Writer()
        w.raw(CXDB_MAGIC)
        w.u8(CXDB_VERSION)
        w.u8(CXDB_FLAGS_LE)
        w.u32(CXDB_DEFAULT_DEPTH)
        w.u8(0); w.u8(0)
        try encodeValue(value, into: w)
        let payloadSize = w.buf.count
        var framed = [UInt8]()
        framed.reserveCapacity(4 + payloadSize)
        let s = UInt32(payloadSize)
        framed.append(UInt8(s & 0xFF))
        framed.append(UInt8((s >> 8)  & 0xFF))
        framed.append(UInt8((s >> 16) & 0xFF))
        framed.append(UInt8((s >> 24) & 0xFF))
        framed.append(contentsOf: w.buf)
        return Data(framed)
    }
}
