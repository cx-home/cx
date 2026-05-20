import CXC
import Foundation

// Thread-init handshake (spec/abi.md §1.5.5, capability bit 26).
// Mandatory-for-all-bindings. Swift has no true module-load hook;
// the lazy global below initializes once, on first reference, and
// `_ensureCxInit()` (called from the helpers) forces that reference.
private let _cxInitOnce: Int32 = cx_init()

@inline(__always)
private func _ensureCxInit() {
    _ = _cxInitOnce
}

/// CX Swift binding — thin wrapper around libcx via the C module.
public enum CXError: Error, LocalizedError {
    case parse(String)
    public var errorDescription: String? {
        if case .parse(let m) = self { return m }
        return nil
    }
}

// ── internal helpers ─────────────────────────────────────────────────────────

private func _callFn(
    _ fn: (UnsafePointer<CChar>?,
           UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> UnsafeMutablePointer<CChar>?,
    _ input: String) throws -> String {
    _ensureCxInit()
    var errPtr: UnsafeMutablePointer<CChar>? = nil
    guard let out = input.withCString({ fn($0, &errPtr) }) else {
        let msg: String
        if let ep = errPtr { msg = String(cString: ep); cx_free(ep) }
        else                { msg = "unknown error" }
        throw CXError.parse(msg)
    }
    let s = String(cString: out)
    cx_free(out)
    return s
}

/// Call a binary-returning C function and decode the length-prefixed buffer into Data.
private func _callBin(
    _ input: String,
    fn: (UnsafePointer<CChar>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> UnsafeMutablePointer<CChar>?) throws -> Data {
    _ensureCxInit()
    var errPtr: UnsafeMutablePointer<CChar>? = nil
    guard let ptr = input.withCString({ fn($0, &errPtr) }) else {
        let msg: String
        if let ep = errPtr { msg = String(cString: ep); cx_free(ep) }
        else                { msg = "unknown error" }
        throw CXError.parse(msg)
    }
    // Buffer layout: [u32 LE: payload_size][payload bytes]
    let rawPtr = UnsafeRawPointer(ptr)
    let sizeLE = rawPtr.load(as: UInt32.self)
    let size = Int(UInt32(littleEndian: sizeLE))
    let data = Data(bytes: rawPtr.advanced(by: 4), count: size)
    cx_free(ptr)
    return data
}

// ── CXLib namespace ───────────────────────────────────────────────────────────

/// Namespace for CX library functions. Also exposes all format-conversion
/// functions as static methods (used internally by CXDocument).
public enum CXLib {

    // ── binary (used by BinaryDecoder) ─────────────────────────────────────────

    public static func astBin(_ cxStr: String) throws -> Data {
        return try _callBin(cxStr, fn: cx_to_ast_bin)
    }

    public static func eventsBin(_ cxStr: String) throws -> Data {
        return try _callBin(cxStr, fn: cx_to_events_bin)
    }

    /// Call cx_to_data_bin and return the CXDB v1 PAYLOAD (the [u32 LE size]
    /// frame is stripped by `_callBin`). Pass the result to `DataBin.decode`.
    public static func toDataBin(_ cxStr: String) throws -> Data {
        return try _callBin(cxStr, fn: cx_to_data_bin)
    }

    /// Call cx_select_all_paths and decode the framed [u32 size][u32 n_paths][...]
    /// blob into a list of structural paths. Each path is `[Int]` of
    /// 0-based indices: first into Document.elements, subsequent into
    /// Element.items. Match order is preorder (same as cx_select_all).
    /// See spec/abi.md §2.7.
    public static func selectAllPaths(_ cxText: String, _ expr: String) throws -> [[Int]] {
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        guard let ptr = cxText.withCString({ cInput in
            expr.withCString({ cExpr in
                cx_select_all_paths(cInput, cExpr, &errPtr)
            })
        }) else {
            let msg: String
            if let ep = errPtr { msg = String(cString: ep); cx_free(ep) }
            else                { msg = "unknown error" }
            throw CXError.parse(msg)
        }
        let raw = UnsafeRawPointer(ptr)
        let sizeLE = raw.load(as: UInt32.self)
        let size = Int(UInt32(littleEndian: sizeLE))
        let payload = Data(bytes: raw.advanced(by: 4), count: size)
        cx_free(ptr)
        let bytes = [UInt8](payload)
        var off = 0
        func readU32() -> UInt32 {
            let v = UInt32(bytes[off])
                  | (UInt32(bytes[off + 1]) << 8)
                  | (UInt32(bytes[off + 2]) << 16)
                  | (UInt32(bytes[off + 3]) << 24)
            off += 4
            return v
        }
        let nPaths = Int(readU32())
        var paths: [[Int]] = []
        paths.reserveCapacity(nPaths)
        for _ in 0 ..< nPaths {
            let depth = Int(readU32())
            var path = [Int]()
            path.reserveCapacity(depth)
            for _ in 0 ..< depth { path.append(Int(readU32())) }
            paths.append(path)
        }
        return paths
    }

    // ── Phase 5 / CB-1 — ast_bin → text format ───────────────────────────────

    private static func astBinToText(
        _ fn: (UnsafePointer<CChar>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> UnsafeMutablePointer<CChar>?,
        _ framed: Data
    ) throws -> String {
        if framed.isEmpty { throw CXError.parse("ast_bin_to_*: empty input") }
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        let result: UnsafeMutablePointer<CChar>? = framed.withUnsafeBytes { raw in
            let p = raw.baseAddress!.assumingMemoryBound(to: CChar.self)
            return fn(p, &errPtr)
        }
        guard let out = result else {
            let msg: String
            if let ep = errPtr { msg = String(cString: ep); cx_free(ep) }
            else                { msg = "unknown error" }
            throw CXError.parse(msg)
        }
        let s = String(cString: out)
        cx_free(out)
        return s
    }

    public static func astBinToCx  (_ framed: Data) throws -> String { try astBinToText(cx_ast_bin_to_cx,   framed) }
    public static func astBinToXml (_ framed: Data) throws -> String { try astBinToText(cx_ast_bin_to_xml,  framed) }
    public static func astBinToJson(_ framed: Data) throws -> String { try astBinToText(cx_ast_bin_to_json, framed) }
    public static func astBinToYaml(_ framed: Data) throws -> String { try astBinToText(cx_ast_bin_to_yaml, framed) }
    public static func astBinToToml(_ framed: Data) throws -> String { try astBinToText(cx_ast_bin_to_toml, framed) }
    public static func astBinToMd  (_ framed: Data) throws -> String { try astBinToText(cx_ast_bin_to_md,   framed) }

    // ── Phase 5 / CB-2 — text → ast_bin (frame stripped) ─────────────────────

    public static func xmlToAstBin (_ input: String) throws -> Data { try _callBin(input, fn: cx_xml_to_ast_bin) }
    public static func jsonToAstBin(_ input: String) throws -> Data { try _callBin(input, fn: cx_json_to_ast_bin) }
    public static func yamlToAstBin(_ input: String) throws -> Data { try _callBin(input, fn: cx_yaml_to_ast_bin) }
    public static func tomlToAstBin(_ input: String) throws -> Data { try _callBin(input, fn: cx_toml_to_ast_bin) }
    public static func mdToAstBin  (_ input: String) throws -> Data { try _callBin(input, fn: cx_md_to_ast_bin) }

    // ── data_bin one-shot loaders/dumpers (Phase 7.28; spec/abi.md §2.4–§2.5) ─

    /// Encode XML text to CXDB v1 PAYLOAD bytes (frame stripped).
    public static func xmlToDataBin (_ input: String) throws -> Data { try _callBin(input, fn: cx_xml_to_data_bin) }
    /// Encode JSON text to CXDB v1 PAYLOAD bytes (frame stripped).
    public static func jsonToDataBin(_ input: String) throws -> Data { try _callBin(input, fn: cx_json_to_data_bin) }
    /// Encode YAML text to CXDB v1 PAYLOAD bytes (frame stripped).
    public static func yamlToDataBin(_ input: String) throws -> Data { try _callBin(input, fn: cx_yaml_to_data_bin) }
    /// Encode TOML text to CXDB v1 PAYLOAD bytes (frame stripped).
    public static func tomlToDataBin(_ input: String) throws -> Data { try _callBin(input, fn: cx_toml_to_data_bin) }
    /// Encode Markdown text to CXDB v1 PAYLOAD bytes (frame stripped).
    public static func mdToDataBin  (_ input: String) throws -> Data { try _callBin(input, fn: cx_md_to_data_bin) }

    /// Decode FRAMED CXDB v1 bytes to XML text.
    public static func dataBinToXml (_ framed: Data) throws -> String { try astBinToText(cx_data_bin_to_xml,  framed) }
    /// Decode FRAMED CXDB v1 bytes to JSON text.
    public static func dataBinToJson(_ framed: Data) throws -> String { try astBinToText(cx_data_bin_to_json, framed) }
    /// Decode FRAMED CXDB v1 bytes to YAML text.
    public static func dataBinToYaml(_ framed: Data) throws -> String { try astBinToText(cx_data_bin_to_yaml, framed) }
    /// Decode FRAMED CXDB v1 bytes to TOML text.
    public static func dataBinToToml(_ framed: Data) throws -> String { try astBinToText(cx_data_bin_to_toml, framed) }
    /// Decode FRAMED CXDB v1 bytes to Markdown text.
    public static func dataBinToMd  (_ framed: Data) throws -> String { try astBinToText(cx_data_bin_to_md,   framed) }

    // ── Delimited (CSV/TSV/PSV/arbitrary) C ABI (ADR 0001 / Phase 7.68) ──────
    // Per spec/decisions/0001-delimited-conversion.md and spec/conversions.md §8.
    // cx_to_delimited / cx_from_delimited take a single-byte delimiter; the
    // cx_to_csv / cx_to_tsv / cx_to_psv aliases hard-code `,` / `\t` / `|`.
    // data_bin one-shots cover the three named-delimiter variants.

    /// Emit `input` as delimited text using the single-byte `delim`. ASCII only.
    public static func toDelimited(_ input: String, delim: Character) throws -> String {
        guard let scalar = delim.unicodeScalars.first,
              delim.unicodeScalars.count == 1,
              scalar.value < 0x80 else {
            throw CXError.parse("delim must be a single ASCII byte")
        }
        let d = CChar(bitPattern: UInt8(scalar.value))
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        guard let out = input.withCString({ cx_to_delimited($0, d, &errPtr) }) else {
            let msg: String
            if let ep = errPtr { msg = String(cString: ep); cx_free(ep) }
            else                { msg = "unknown error" }
            throw CXError.parse(msg)
        }
        let s = String(cString: out)
        cx_free(out)
        return s
    }

    /// Parse delimited `input` (single-byte ASCII `delim`) into canonical CX text.
    public static func fromDelimited(_ input: String, delim: Character) throws -> String {
        guard let scalar = delim.unicodeScalars.first,
              delim.unicodeScalars.count == 1,
              scalar.value < 0x80 else {
            throw CXError.parse("delim must be a single ASCII byte")
        }
        let d = CChar(bitPattern: UInt8(scalar.value))
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        guard let out = input.withCString({ cx_from_delimited($0, d, &errPtr) }) else {
            let msg: String
            if let ep = errPtr { msg = String(cString: ep); cx_free(ep) }
            else                { msg = "unknown error" }
            throw CXError.parse(msg)
        }
        let s = String(cString: out)
        cx_free(out)
        return s
    }

    public static func toCsv  (_ input: String) throws -> String { try _callFn(cx_to_csv,   input) }
    public static func fromCsv(_ input: String) throws -> String { try _callFn(cx_from_csv, input) }
    public static func toTsv  (_ input: String) throws -> String { try _callFn(cx_to_tsv,   input) }
    public static func fromTsv(_ input: String) throws -> String { try _callFn(cx_from_tsv, input) }
    public static func toPsv  (_ input: String) throws -> String { try _callFn(cx_to_psv,   input) }
    public static func fromPsv(_ input: String) throws -> String { try _callFn(cx_from_psv, input) }

    /// Encode CSV text to CXDB v1 PAYLOAD bytes (frame stripped).
    public static func csvToDataBin(_ input: String) throws -> Data { try _callBin(input, fn: cx_csv_to_data_bin) }
    /// Encode TSV text to CXDB v1 PAYLOAD bytes (frame stripped).
    public static func tsvToDataBin(_ input: String) throws -> Data { try _callBin(input, fn: cx_tsv_to_data_bin) }
    /// Encode PSV text to CXDB v1 PAYLOAD bytes (frame stripped).
    public static func psvToDataBin(_ input: String) throws -> Data { try _callBin(input, fn: cx_psv_to_data_bin) }

    /// Decode FRAMED CXDB v1 bytes to CSV text.
    public static func dataBinToCsv(_ framed: Data) throws -> String { try astBinToText(cx_data_bin_to_csv, framed) }
    /// Decode FRAMED CXDB v1 bytes to TSV text.
    public static func dataBinToTsv(_ framed: Data) throws -> String { try astBinToText(cx_data_bin_to_tsv, framed) }
    /// Decode FRAMED CXDB v1 bytes to PSV text.
    public static func dataBinToPsv(_ framed: Data) throws -> String { try astBinToText(cx_data_bin_to_psv, framed) }

    // ── Phase 6 / canonical-form tooling (spec/abi.md §2.6) ──────────────────

    /// Lossless canonical text CX. Idempotent.
    public static func fmt(_ input: String) throws -> String { try _callFn(cx_fmt, input) }

    /// Strict canonical text CX.
    public static func canonical(_ input: String) throws -> String { try _callFn(cx_canonical, input) }

    /// SHA-256 hex (64 lowercase hex chars) of the strict canonical bytes.
    public static func hash(_ input: String) throws -> String { try _callFn(cx_hash, input) }

    /// True iff strict-canonical(a) == strict-canonical(b).
    public static func eq(_ a: String, _ b: String) throws -> Bool {
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        guard let out = a.withCString({ ap in
            b.withCString({ bp in
                cx_eq(ap, bp, &errPtr)
            })
        }) else {
            let msg: String
            if let ep = errPtr { msg = String(cString: ep); cx_free(ep) }
            else                { msg = "unknown error" }
            throw CXError.parse(msg)
        }
        let s = String(cString: out)
        cx_free(out)
        return s == "1"
    }

    /// Semantic diff between two CX inputs, walking the strict-canonical
    /// forms. `format` is `"unified"`, `"json"`, or `"summary"`. Empty
    /// result means data-equivalent.
    ///
    /// Per spec/decisions/0012-cx-diff.md.
    public static func diff(_ a: String, _ b: String, format: String = "unified") throws -> String {
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        guard let out = a.withCString({ ap in
            b.withCString({ bp in
                format.withCString({ fp in
                    cx_diff(ap, bp, fp, &errPtr)
                })
            })
        }) else {
            let msg: String
            if let ep = errPtr { msg = String(cString: ep); cx_free(ep) }
            else                { msg = "unknown error" }
            throw CXError.parse(msg)
        }
        let s = String(cString: out)
        cx_free(out)
        return s
    }

    /// Style + correctness warnings. `format` is `"text"`, `"json"`, or
    /// `"summary"`. `disabled` is a comma-separated list of check IDs
    /// to suppress (`""` runs all). Empty result means no findings.
    ///
    /// Per spec/decisions/0013-cx-lint.md.
    public static func lint(_ input: String, format: String = "text", disabled: String = "") throws -> String {
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        guard let out = input.withCString({ ip in
            format.withCString({ fp in
                disabled.withCString({ dp in
                    cx_lint(ip, fp, dp, &errPtr)
                })
            })
        }) else {
            let msg: String
            if let ep = errPtr { msg = String(cString: ep); cx_free(ep) }
            else                { msg = "unknown error" }
            throw CXError.parse(msg)
        }
        let s = String(cString: out)
        cx_free(out)
        return s
    }

    // ── Phase 7.65 / ID/IDREF C ABI (ADR 0003) ───────────────────────────────

    /// Helper for `cx_id_lookup` / `cx_resolve_ref` / `cx_node_id` — all share
    /// the (const char*, const char*, char** err_out) -> char* shape and
    /// return the empty string (mapped to nil) for "not found".
    private static func _callIdAbi(
        _ fn: (UnsafePointer<CChar>?, UnsafePointer<CChar>?,
               UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> UnsafeMutablePointer<CChar>?,
        _ input: String, _ key: String) throws -> String? {
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        guard let out = input.withCString({ ip in
            key.withCString({ kp in
                fn(ip, kp, &errPtr)
            })
        }) else {
            let msg: String
            if let ep = errPtr { msg = String(cString: ep); cx_free(ep) }
            else                { msg = "unknown error" }
            throw CXError.parse(msg)
        }
        let s = String(cString: out)
        cx_free(out)
        return s.isEmpty ? nil : s
    }

    /// Find the element declaring `#id` in `input`. Returns the AST-JSON
    /// encoding of the element, or nil if no such ID exists. Throws on
    /// parse error.
    public static func idLookup(_ input: String, _ id: String) throws -> String? {
        try _callIdAbi(cx_id_lookup, input, id)
    }

    /// Follow a bare `@ref` reference. Observationally equivalent to
    /// `idLookup` (refs and IDs share a namespace). Returns the AST-JSON
    /// encoding of the referenced element, or nil if the ref does not
    /// resolve. Throws on parse error.
    public static func resolveRef(_ input: String, _ ref: String) throws -> String? {
        try _callIdAbi(cx_resolve_ref, input, ref)
    }

    /// Run CXPath `cxpath` on `input` and return the syntactic ID of the
    /// matched element, or nil when the matched element has no ID or no
    /// element matched. Throws on parse / cxpath error.
    public static func nodeId(_ input: String, _ cxpath: String) throws -> String? {
        try _callIdAbi(cx_node_id, input, cxpath)
    }

    /// Call cx_from_data_bin with FRAMED CXDB v1 bytes (as returned by
    /// `DataBin.encode`) and return the canonical CX text.
    public static func fromDataBin(_ framed: Data) throws -> String {
        if framed.isEmpty { throw CXError.parse("cx_from_data_bin: empty input") }
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        let result: UnsafeMutablePointer<CChar>? = framed.withUnsafeBytes { raw in
            let p = raw.baseAddress!.assumingMemoryBound(to: CChar.self)
            return cx_from_data_bin(p, &errPtr)
        }
        guard let out = result else {
            let msg: String
            if let ep = errPtr { msg = String(cString: ep); cx_free(ep) }
            else                { msg = "unknown error" }
            throw CXError.parse(msg)
        }
        let s = String(cString: out)
        cx_free(out)
        return s
    }

    // ── version ────────────────────────────────────────────────────────────────

    public static func version() -> String {
        let p = cx_version()!
        let s = String(cString: p)
        cx_free(p)
        return s
    }

    // ── CX input ───────────────────────────────────────────────────────────────

    public static func toCx        (_ input: String) throws -> String { try _callFn(cx_to_cx,         input) }
    public static func toCxCompact (_ input: String) throws -> String { try _callFn(cx_to_cx_compact, input) }
    public static func astToCx     (_ input: String) throws -> String { try _callFn(cx_ast_to_cx,     input) }
    public static func toXml (_ input: String) throws -> String { try _callFn(cx_to_xml,  input) }
    public static func toAst (_ input: String) throws -> String { try _callFn(cx_to_ast,  input) }
    public static func toJson(_ input: String) throws -> String { try _callFn(cx_to_json, input) }
    public static func toYaml(_ input: String) throws -> String { try _callFn(cx_to_yaml, input) }
    public static func toToml(_ input: String) throws -> String { try _callFn(cx_to_toml, input) }
    public static func toMd  (_ input: String) throws -> String { try _callFn(cx_to_md,   input) }

    // ── CXL evaluation ─────────────────────────────────────────────────────────

    /// Evaluate a CXL program against a CX context document.
    /// `outputTarget` may be "" (honour the program's `[?cx output-target=…]`
    /// directive, default "text") or one of "text" / "cx" / "html".
    public static func evalCxl(_ input: String, _ program: String, _ outputTarget: String = "") throws -> String {
        _ensureCxInit()
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        let out = input.withCString { ci in
            program.withCString { cp in
                outputTarget.withCString { ct in
                    cx_eval(ci, cp, ct, &errPtr)
                }
            }
        }
        guard let result = out else {
            let msg: String
            if let ep = errPtr { msg = String(cString: ep); cx_free(ep) }
            else                { msg = "cx_eval: unknown error" }
            throw CXError.parse(msg)
        }
        let s = String(cString: result)
        cx_free(result)
        return s
    }

    // ── XML input ──────────────────────────────────────────────────────────────

    public static func xmlToCx  (_ input: String) throws -> String { try _callFn(cx_xml_to_cx,   input) }
    public static func xmlToXml (_ input: String) throws -> String { try _callFn(cx_xml_to_xml,  input) }
    public static func xmlToAst (_ input: String) throws -> String { try _callFn(cx_xml_to_ast,  input) }
    public static func xmlToJson(_ input: String) throws -> String { try _callFn(cx_xml_to_json, input) }
    public static func xmlToYaml(_ input: String) throws -> String { try _callFn(cx_xml_to_yaml, input) }
    public static func xmlToToml(_ input: String) throws -> String { try _callFn(cx_xml_to_toml, input) }
    public static func xmlToMd  (_ input: String) throws -> String { try _callFn(cx_xml_to_md,   input) }

    // ── JSON input ─────────────────────────────────────────────────────────────

    public static func jsonToCx  (_ input: String) throws -> String { try _callFn(cx_json_to_cx,   input) }
    public static func jsonToXml (_ input: String) throws -> String { try _callFn(cx_json_to_xml,  input) }
    public static func jsonToAst (_ input: String) throws -> String { try _callFn(cx_json_to_ast,  input) }
    public static func jsonToJson(_ input: String) throws -> String { try _callFn(cx_json_to_json, input) }
    public static func jsonToYaml(_ input: String) throws -> String { try _callFn(cx_json_to_yaml, input) }
    public static func jsonToToml(_ input: String) throws -> String { try _callFn(cx_json_to_toml, input) }
    public static func jsonToMd  (_ input: String) throws -> String { try _callFn(cx_json_to_md,   input) }

    // ── YAML input ─────────────────────────────────────────────────────────────

    public static func yamlToCx  (_ input: String) throws -> String { try _callFn(cx_yaml_to_cx,   input) }
    public static func yamlToXml (_ input: String) throws -> String { try _callFn(cx_yaml_to_xml,  input) }
    public static func yamlToAst (_ input: String) throws -> String { try _callFn(cx_yaml_to_ast,  input) }
    public static func yamlToJson(_ input: String) throws -> String { try _callFn(cx_yaml_to_json, input) }
    public static func yamlToYaml(_ input: String) throws -> String { try _callFn(cx_yaml_to_yaml, input) }
    public static func yamlToToml(_ input: String) throws -> String { try _callFn(cx_yaml_to_toml, input) }
    public static func yamlToMd  (_ input: String) throws -> String { try _callFn(cx_yaml_to_md,   input) }

    // ── TOML input ─────────────────────────────────────────────────────────────

    public static func tomlToCx  (_ input: String) throws -> String { try _callFn(cx_toml_to_cx,   input) }
    public static func tomlToXml (_ input: String) throws -> String { try _callFn(cx_toml_to_xml,  input) }
    public static func tomlToAst (_ input: String) throws -> String { try _callFn(cx_toml_to_ast,  input) }
    public static func tomlToJson(_ input: String) throws -> String { try _callFn(cx_toml_to_json, input) }
    public static func tomlToYaml(_ input: String) throws -> String { try _callFn(cx_toml_to_yaml, input) }
    public static func tomlToToml(_ input: String) throws -> String { try _callFn(cx_toml_to_toml, input) }
    public static func tomlToMd  (_ input: String) throws -> String { try _callFn(cx_toml_to_md,   input) }

    // ── MD input ───────────────────────────────────────────────────────────────

    public static func mdToCx  (_ input: String) throws -> String { try _callFn(cx_md_to_cx,   input) }
    public static func mdToXml (_ input: String) throws -> String { try _callFn(cx_md_to_xml,  input) }
    public static func mdToAst (_ input: String) throws -> String { try _callFn(cx_md_to_ast,  input) }
    public static func mdToJson(_ input: String) throws -> String { try _callFn(cx_md_to_json, input) }
    public static func mdToYaml(_ input: String) throws -> String { try _callFn(cx_md_to_yaml, input) }
    public static func mdToToml(_ input: String) throws -> String { try _callFn(cx_md_to_toml, input) }
    public static func mdToMd  (_ input: String) throws -> String { try _callFn(cx_md_to_md,   input) }
}

// ── module-level shims (keep backward compat for any direct callers) ──────────

public func version() -> String { CXLib.version() }

public func toCx        (_ input: String) throws -> String { try CXLib.toCx(input)        }
public func toCxCompact (_ input: String) throws -> String { try CXLib.toCxCompact(input) }
public func astToCx     (_ input: String) throws -> String { try CXLib.astToCx(input)     }
public func toXml (_ input: String) throws -> String { try CXLib.toXml(input)  }
public func toAst (_ input: String) throws -> String { try CXLib.toAst(input)  }
public func toJson(_ input: String) throws -> String { try CXLib.toJson(input) }
public func toYaml(_ input: String) throws -> String { try CXLib.toYaml(input) }
public func toToml(_ input: String) throws -> String { try CXLib.toToml(input) }
public func toMd  (_ input: String) throws -> String { try CXLib.toMd(input)   }

public func xmlToCx  (_ input: String) throws -> String { try CXLib.xmlToCx(input)   }
public func xmlToXml (_ input: String) throws -> String { try CXLib.xmlToXml(input)  }
public func xmlToAst (_ input: String) throws -> String { try CXLib.xmlToAst(input)  }
public func xmlToJson(_ input: String) throws -> String { try CXLib.xmlToJson(input) }
public func xmlToYaml(_ input: String) throws -> String { try CXLib.xmlToYaml(input) }
public func xmlToToml(_ input: String) throws -> String { try CXLib.xmlToToml(input) }
public func xmlToMd  (_ input: String) throws -> String { try CXLib.xmlToMd(input)   }

public func jsonToCx  (_ input: String) throws -> String { try CXLib.jsonToCx(input)   }
public func jsonToXml (_ input: String) throws -> String { try CXLib.jsonToXml(input)  }
public func jsonToAst (_ input: String) throws -> String { try CXLib.jsonToAst(input)  }
public func jsonToJson(_ input: String) throws -> String { try CXLib.jsonToJson(input) }
public func jsonToYaml(_ input: String) throws -> String { try CXLib.jsonToYaml(input) }
public func jsonToToml(_ input: String) throws -> String { try CXLib.jsonToToml(input) }
public func jsonToMd  (_ input: String) throws -> String { try CXLib.jsonToMd(input)   }

public func yamlToCx  (_ input: String) throws -> String { try CXLib.yamlToCx(input)   }
public func yamlToXml (_ input: String) throws -> String { try CXLib.yamlToXml(input)  }
public func yamlToAst (_ input: String) throws -> String { try CXLib.yamlToAst(input)  }
public func yamlToJson(_ input: String) throws -> String { try CXLib.yamlToJson(input) }
public func yamlToYaml(_ input: String) throws -> String { try CXLib.yamlToYaml(input) }
public func yamlToToml(_ input: String) throws -> String { try CXLib.yamlToToml(input) }
public func yamlToMd  (_ input: String) throws -> String { try CXLib.yamlToMd(input)   }

public func tomlToCx  (_ input: String) throws -> String { try CXLib.tomlToCx(input)   }
public func tomlToXml (_ input: String) throws -> String { try CXLib.tomlToXml(input)  }
public func tomlToAst (_ input: String) throws -> String { try CXLib.tomlToAst(input)  }
public func tomlToJson(_ input: String) throws -> String { try CXLib.tomlToJson(input) }
public func tomlToYaml(_ input: String) throws -> String { try CXLib.tomlToYaml(input) }
public func tomlToToml(_ input: String) throws -> String { try CXLib.tomlToToml(input) }
public func tomlToMd  (_ input: String) throws -> String { try CXLib.tomlToMd(input)   }

public func mdToCx  (_ input: String) throws -> String { try CXLib.mdToCx(input)   }
public func mdToXml (_ input: String) throws -> String { try CXLib.mdToXml(input)  }
public func mdToAst (_ input: String) throws -> String { try CXLib.mdToAst(input)  }
public func mdToJson(_ input: String) throws -> String { try CXLib.mdToJson(input) }
public func mdToYaml(_ input: String) throws -> String { try CXLib.mdToYaml(input) }
public func mdToToml(_ input: String) throws -> String { try CXLib.mdToToml(input) }
public func mdToMd  (_ input: String) throws -> String { try CXLib.mdToMd(input)   }
