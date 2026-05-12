import Foundation

// ── StreamEvent ───────────────────────────────────────────────────────────────

/// A single event from the CX streaming parser.
public struct StreamEvent {
    public var type: String
    // StartElement / EndElement
    public var name: String?
    public var anchor: String?
    public var dataType: String?
    public var merge: String?
    public var attrs: [Attr] = []
    // Text / Comment / RawText / EntityRef / Alias / Scalar value
    public var value: Any?
    // PI
    public var target: String?
    public var data: String?

    public init(type: String) { self.type = type }

    public func isStartElement(_ named: String? = nil) -> Bool {
        type == "StartElement" && (named == nil || name == named)
    }
    public func isEndElement(_ named: String? = nil) -> Bool {
        type == "EndElement" && (named == nil || name == named)
    }
}

// ── BufReader ─────────────────────────────────────────────────────────────────

private struct BufReader {
    let bytes: [UInt8]
    var pos: Int = 0

    init(_ data: Data) {
        self.bytes = Array(data)
    }

    mutating func u8() throws -> UInt8 {
        guard pos < bytes.count else { throw CXError.parse("binary: unexpected end of buffer (u8)") }
        let v = bytes[pos]; pos += 1; return v
    }

    mutating func u16() throws -> UInt16 {
        guard pos + 1 < bytes.count else { throw CXError.parse("binary: unexpected end of buffer (u16)") }
        let lo = UInt16(bytes[pos])
        let hi = UInt16(bytes[pos + 1])
        pos += 2
        return lo | (hi << 8)
    }

    mutating func u32() throws -> UInt32 {
        guard pos + 3 < bytes.count else { throw CXError.parse("binary: unexpected end of buffer (u32)") }
        let a = UInt32(bytes[pos])
        let b = UInt32(bytes[pos + 1])
        let c = UInt32(bytes[pos + 2])
        let d = UInt32(bytes[pos + 3])
        pos += 4
        return a | (b << 8) | (c << 16) | (d << 24)
    }

    mutating func str() throws -> String {
        let len = Int(try u32())
        guard pos + len <= bytes.count else { throw CXError.parse("binary: string overflows buffer") }
        let slice = bytes[pos ..< pos + len]
        pos += len
        guard let s = String(bytes: slice, encoding: .utf8) else {
            throw CXError.parse("binary: invalid UTF-8 in string")
        }
        return s
    }

    mutating func optStr() throws -> String? {
        let flag = try u8()
        guard flag != 0 else { return nil }
        return try str()
    }
}

// ── coercion ──────────────────────────────────────────────────────────────────

private func _coerce(_ typeStr: String, _ valueStr: String) -> Any? {
    switch typeStr {
    case "int":    return Int(valueStr) as Any?
    case "float":  return Double(valueStr) as Any?
    case "bool":   return (valueStr == "true") as Any?
    case "null":   return nil
    default:       return valueStr as Any?   // string / date / datetime / etc.
    }
}

// ── AST decoder ───────────────────────────────────────────────────────────────

private func _readAttr(_ b: inout BufReader, _ version: UInt8) throws -> Attr {
    let name     = try b.str()
    let valueStr = try b.str()
    let typeStr  = try b.str()
    let dt: String? = typeStr == "string" ? nil : typeStr
    var a = Attr(name, _coerce(typeStr, valueStr), dataType: dt)
    if version >= 2 {
        a.isRef = try b.u8() == 1
    }
    if version >= 5 {
        // v3.5 (ADR 0016): BracketBody attribute body tail.
        let flag = try b.u8()
        if flag == 1 {
            let count = Int(try b.u16())
            var body: [Node] = []
            body.reserveCapacity(count)
            for _ in 0 ..< count { body.append(try _readNode(&b, version)) }
            a.body = body
        } else if flag != 0 {
            throw CXError.parse("ast_bin: invalid attr body_flag \(flag)")
        }
    }
    return a
}

private func _readNode(_ b: inout BufReader, _ version: UInt8) throws -> Node {
    let tid = try b.u8()
    switch tid {
    case 0x01:  // Element
        let name   = try b.str()
        let anchor = try b.optStr()
        let dt     = try b.optStr()
        let merge  = try b.optStr()
        let idDecl: String? = version >= 2 ? try b.optStr() : nil
        let bodyRefDecl: String? = version >= 3 ? try b.optStr() : nil
        let attrCount = Int(try b.u16())
        var attrs: [Attr] = []
        attrs.reserveCapacity(attrCount)
        for _ in 0 ..< attrCount { attrs.append(try _readAttr(&b, version)) }
        let childCount = Int(try b.u16())
        var items: [Node] = []
        items.reserveCapacity(childCount)
        for _ in 0 ..< childCount { items.append(try _readNode(&b, version)) }
        let el = Element(name, attrs: attrs, items: items)
        el.anchor   = anchor
        el.dataType = dt
        el.merge    = merge
        el.id       = idDecl
        el.bodyRef  = bodyRefDecl
        return .element(el)

    case 0x02:  // Text
        return .text(try b.str())

    case 0x03:  // Scalar
        let typeStr  = try b.str()
        let valueStr = try b.str()
        return .scalar(dataType: typeStr, value: _coerce(typeStr, valueStr))

    case 0x04:  // Comment
        return .comment(try b.str())

    case 0x05:  // RawText
        return .rawText(try b.str())

    case 0x06:  // EntityRef
        return .entityRef(try b.str())

    case 0x07:  // Alias
        return .alias(try b.str())

    case 0x08:  // PI
        let target = try b.str()
        let data   = try b.optStr()
        return .pi(target: target, data: data)

    case 0x09:  // XMLDecl
        let declVersion = try b.str()
        let encoding    = try b.optStr()
        let standalone  = try b.optStr()
        return .xmlDecl(version: declVersion, encoding: encoding, standalone: standalone)

    case 0x0A:  // CXDirective
        let count = Int(try b.u16())
        var attrs: [Attr] = []
        attrs.reserveCapacity(count)
        for _ in 0 ..< count { attrs.append(try _readAttr(&b, version)) }
        var anchor: String? = nil
        var dirItems: [Node] = []
        if version >= 4 {
            // v0.6.0 — directive `&anchor` + nested children.
            anchor = try b.optStr()
            let itemCount = Int(try b.u16())
            dirItems.reserveCapacity(itemCount)
            for _ in 0 ..< itemCount { dirItems.append(try _readNode(&b, version)) }
        }
        return .cxDirective(attrs: attrs, anchor: anchor, items: dirItems)

    case 0x0C:  // BlockContent
        let count = Int(try b.u16())
        var items: [Node] = []
        items.reserveCapacity(count)
        for _ in 0 ..< count { items.append(try _readNode(&b, version)) }
        return .blockContent(items)

    case 0x0D:  // Interpolation — v3.5 (ADR 0016) [58]
        let expr = try b.str()
        return .interpolation(expr: expr)

    case 0x0E:  // EvalDirective — v3.5 (ADR 0016) [59]
        let name = try b.str()
        let attrCount = Int(try b.u16())
        var attrs: [Attr] = []
        attrs.reserveCapacity(attrCount)
        for _ in 0 ..< attrCount { attrs.append(try _readAttr(&b, version)) }
        let itemCount = Int(try b.u16())
        var items: [Node] = []
        items.reserveCapacity(itemCount)
        for _ in 0 ..< itemCount { items.append(try _readNode(&b, version)) }
        return .evalDirective(name: name, attrs: attrs, items: items)

    case 0xFF:  // skip (DTD etc.) — no payload
        return .text("")

    default:
        throw CXError.parse("binary: unknown node type 0x\(String(tid, radix: 16))")
    }
}

// ── Events decoder ────────────────────────────────────────────────────────────

private func _readOneEvent(_ b: inout BufReader) throws -> StreamEvent {
    let tid = try b.u8()
    switch tid {
    case 0x01: return StreamEvent(type: "StartDoc")
    case 0x02: return StreamEvent(type: "EndDoc")
    case 0x03:
        var e = StreamEvent(type: "StartElement")
        e.name     = try b.str()
        e.anchor   = try b.optStr()
        e.dataType = try b.optStr()
        e.merge    = try b.optStr()
        let attrCount = Int(try b.u16())
        var attrs: [Attr] = []
        attrs.reserveCapacity(attrCount)
        for _ in 0 ..< attrCount {
            let aName    = try b.str()
            let aValStr  = try b.str()
            let aTypeStr = try b.str()
            let dt: String? = aTypeStr == "string" ? nil : aTypeStr
            let isRef    = try b.u8() == 1  // v3.4 (ADR 0003): events buffer follows ast_bin v2.
            // v3.5 (ADR 0016): BracketBody attr body tail (events buffer
            // follows ast_bin v5 attr layout). Body items are skipped.
            let bodyFlag = try b.u8()
            if bodyFlag == 1 {
                let count = Int(try b.u16())
                for _ in 0 ..< count { _ = try _readNode(&b, 5) }
            } else if bodyFlag != 0 {
                throw CXError.parse("ast_bin: invalid attr body_flag \(bodyFlag)")
            }
            var a = Attr(aName, _coerce(aTypeStr, aValStr), dataType: dt)
            a.isRef = isRef
            attrs.append(a)
        }
        e.attrs = attrs
        return e
    case 0x04:
        var e = StreamEvent(type: "EndElement"); e.name = try b.str(); return e
    case 0x05:
        var e = StreamEvent(type: "Text"); e.value = try b.str(); return e
    case 0x06:
        var e = StreamEvent(type: "Scalar")
        let typeStr  = try b.str()
        let valueStr = try b.str()
        e.dataType = typeStr
        e.value    = _coerce(typeStr, valueStr)
        return e
    case 0x07:
        var e = StreamEvent(type: "Comment"); e.value = try b.str(); return e
    case 0x08:
        var e = StreamEvent(type: "PI")
        e.target = try b.str()
        e.data   = try b.optStr()
        return e
    case 0x09:
        var e = StreamEvent(type: "EntityRef"); e.value = try b.str(); return e
    case 0x0A:
        var e = StreamEvent(type: "RawText"); e.value = try b.str(); return e
    case 0x0B:
        var e = StreamEvent(type: "Alias"); e.value = try b.str(); return e
    default:
        throw CXError.parse("binary: unknown event type 0x\(String(tid, radix: 16))")
    }
}

private func _decodeEvents(_ b: inout BufReader) throws -> [StreamEvent] {
    let count = Int(try b.u32())
    var events: [StreamEvent] = []
    events.reserveCapacity(count)
    for _ in 0 ..< count { events.append(try _readOneEvent(&b)) }
    return events
}

// ── Public API ────────────────────────────────────────────────────────────────

public enum BinaryDecoder {

    /// Decode a binary AST payload (without the 4-byte size prefix) into a CXDocument.
    public static func decodeAST(_ data: Data) throws -> CXDocument {
        var b = BufReader(data)
        let version = try b.u8()
        let prologCount = Int(try b.u16())
        var prolog: [Node] = []
        prolog.reserveCapacity(prologCount)
        for _ in 0 ..< prologCount { prolog.append(try _readNode(&b, version)) }
        let elemCount = Int(try b.u16())
        var elements: [Node] = []
        elements.reserveCapacity(elemCount)
        for _ in 0 ..< elemCount { elements.append(try _readNode(&b, version)) }
        return CXDocument(elements: elements, prolog: prolog)
    }

    /// Decode a binary events payload (without the 4-byte size prefix) into [StreamEvent].
    public static func decodeEvents(_ data: Data) throws -> [StreamEvent] {
        var b = BufReader(data)
        return try _decodeEvents(&b)
    }

    /// Decode a single event from a payload (no [u32 count] prefix).
    /// Used by the handle-based EventStream (Phase 5 / CB-4).
    public static func decodeOneEvent(_ data: Data) throws -> StreamEvent {
        var b = BufReader(data)
        return try _readOneEvent(&b)
    }

    /// Encode a CXDocument to a FRAMED [u32 LE size][payload] AST bin
    /// `Data` suitable for direct hand-off to cx_ast_bin_to_<format>.
    public static func encodeAST(_ doc: CXDocument) -> Data {
        var out = Data()
        out.append(0x05)  // version — v0.6.0 (ADR 0016 grammar v3.5):
                          //   * CXDirective &anchor + items (format v4)
                          //   * Interpolation (0x0D) + EvalDirective (0x0E) tags
                          //   * BracketBody attribute body tail (format v5)
        _encU16(&out, UInt16(doc.prolog.count))
        for n in doc.prolog { _encNode(&out, n) }
        _encU16(&out, UInt16(doc.elements.count))
        for n in doc.elements { _encNode(&out, n) }
        var framed = Data()
        _encU32(&framed, UInt32(out.count))
        framed.append(out)
        return framed
    }
}

// ── Binary AST encoder helpers (Phase 5 / CB-1) ──────────────────────────────

private func _encU16(_ out: inout Data, _ v: UInt16) {
    out.append(UInt8(v & 0xFF))
    out.append(UInt8((v >> 8) & 0xFF))
}
private func _encU32(_ out: inout Data, _ v: UInt32) {
    out.append(UInt8(v & 0xFF))
    out.append(UInt8((v >> 8)  & 0xFF))
    out.append(UInt8((v >> 16) & 0xFF))
    out.append(UInt8((v >> 24) & 0xFF))
}
private func _encStr(_ out: inout Data, _ s: String) {
    let enc = Array(s.utf8)
    _encU32(&out, UInt32(enc.count))
    out.append(contentsOf: enc)
}
private func _encOptStr(_ out: inout Data, _ s: String?) {
    if let v = s { out.append(0x01); _encStr(&out, v) }
    else { out.append(0x00) }
}
private func _scalarValueStr(_ dt: String, _ v: Any?) -> String {
    if v == nil || dt == "null" { return "null" }
    if let b = v as? Bool { return b ? "true" : "false" }
    if let s = v as? String { return s }
    return "\(v!)"
}
private func _encAttr(_ out: inout Data, _ a: Attr) {
    let dt: String = (a.dataType?.isEmpty == false ? a.dataType : nil) ?? "string"
    _encStr(&out, a.name)
    _encStr(&out, _scalarValueStr(dt, a.value))
    _encStr(&out, dt)
    // v3.4 (ADR 0003): is_ref flag — format version 2.
    out.append(a.isRef ? 0x01 : 0x00)
    // v3.5 (ADR 0016): BracketBody attribute body tail — format version 5.
    if let body = a.body {
        out.append(0x01)
        _encU16(&out, UInt16(body.count))
        for n in body { _encNode(&out, n) }
    } else {
        out.append(0x00)
    }
}
private func _encNode(_ out: inout Data, _ n: Node) {
    switch n {
    case .element(let e):
        out.append(0x01)
        _encStr(&out, e.name)
        _encOptStr(&out, e.anchor)
        _encOptStr(&out, e.dataType)
        _encOptStr(&out, e.merge)
        // v3.4 (ADR 0003): syntactic ID declaration — format version 2.
        _encOptStr(&out, e.id)
        // v3.4 (ADR 0003 D1): body-position reference — format version 3 (Phase 7.70).
        _encOptStr(&out, e.bodyRef)
        _encU16(&out, UInt16(e.attrs.count))
        for a in e.attrs { _encAttr(&out, a) }
        _encU16(&out, UInt16(e.items.count))
        for c in e.items { _encNode(&out, c) }
    case .text(let s):    out.append(0x02); _encStr(&out, s)
    case .scalar(let dt, let v):
        out.append(0x03); _encStr(&out, dt); _encStr(&out, _scalarValueStr(dt, v))
    case .comment(let s): out.append(0x04); _encStr(&out, s)
    case .rawText(let s): out.append(0x05); _encStr(&out, s)
    case .entityRef(let s): out.append(0x06); _encStr(&out, s)
    case .alias(let s):     out.append(0x07); _encStr(&out, s)
    case .pi(let target, let data):
        out.append(0x08); _encStr(&out, target); _encOptStr(&out, data)
    case .xmlDecl(let version, let encoding, let standalone):
        out.append(0x09)
        _encStr(&out, version)
        _encOptStr(&out, encoding)
        _encOptStr(&out, standalone)
    case .cxDirective(let attrs, let anchor, let dirItems):
        out.append(0x0A); _encU16(&out, UInt16(attrs.count))
        for a in attrs { _encAttr(&out, a) }
        // v0.6.0 (format version 4) — directive `&anchor` + nested children.
        _encOptStr(&out, anchor)
        _encU16(&out, UInt16(dirItems.count))
        for it in dirItems { _encNode(&out, it) }
    case .blockContent(let items):
        out.append(0x0C); _encU16(&out, UInt16(items.count))
        for it in items { _encNode(&out, it) }
    case .interpolation(let expr):
        // v3.5 (ADR 0016) [58] — `[?=EXPR]`.
        out.append(0x0D); _encStr(&out, expr)
    case .evalDirective(let name, let attrs, let items):
        // v3.5 (ADR 0016) [59] — `[?Name attrs body]`.
        out.append(0x0E); _encStr(&out, name)
        _encU16(&out, UInt16(attrs.count))
        for a in attrs { _encAttr(&out, a) }
        _encU16(&out, UInt16(items.count))
        for it in items { _encNode(&out, it) }
    case .doctype:
        // DTD nodes aren't round-tripped; emit 0xFF skip marker.
        out.append(0xFF)
    }
}
