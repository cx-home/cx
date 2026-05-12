import CXC
import Foundation

/// Streaming Table reader / writer + schema-driven CXDB encoding +
/// chunked-table one-shot. Per spec/abi.md §§2.10 / 2.12 (capability
/// bits 21 / 24) and ADR 0015 D3 / D8.
///
/// Wire conventions (mirroring the C ABI):
///   - `toDataBinChunked` returns UNFRAMED CXDB payload, matching the
///     other `xxxToDataBin` shapes elsewhere in this binding.
///   - `xxxToDataBinSchemaDriven` returns UNFRAMED payload too.
///   - `fromDataBinSchemaDriven` takes a FRAMED buffer.
///   - The streaming `TableReader` / `TableWriter` exchange FRAMED bytes
///     end-to-end (col-spec, row groups, output buffer) — this matches
///     the C ABI's pull/push shape and avoids re-framing on every step.
///   - fd variants of the streaming API operate on bare CXDB bytes.

private func _readFramed(_ ptr: UnsafeMutablePointer<CChar>) -> Data {
    let raw = UnsafeRawPointer(ptr)
    let sizeLE = raw.load(as: UInt32.self)
    let size = Int(UInt32(littleEndian: sizeLE))
    return Data(bytes: raw, count: 4 + size)
}

private func _errMessage(_ errPtr: UnsafeMutablePointer<CChar>?, fallback: String) -> String {
    if let ep = errPtr {
        let msg = String(cString: ep)
        cx_free(ep)
        return msg
    }
    return fallback
}

// ── chunked-table one-shot + schema-driven loaders/dumper on CXLib ──────────

extension CXLib {

    /// Encode CX text to CXDB chunked-table form (`0x63`). Returns
    /// UNFRAMED CXDB payload bytes (frame stripped). Capability bit 21.
    public static func toDataBinChunked(_ input: String) throws -> Data {
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        guard let out = input.withCString({ cx_to_data_bin_chunked($0, &errPtr) }) else {
            throw CXError.parse(_errMessage(errPtr, fallback: "cx_to_data_bin_chunked: unknown error"))
        }
        let raw = UnsafeRawPointer(out)
        let sizeLE = raw.load(as: UInt32.self)
        let size = Int(UInt32(littleEndian: sizeLE))
        let payload = Data(bytes: raw.advanced(by: 4), count: size)
        cx_free(out)
        return payload
    }

    /// Schema reference form for the schema-driven encoders.
    /// 0 = content-hash only (default); 1 = inline schema; 2 = hash + name hint.
    public enum SchemaRefForm: Int32 {
        case contentHash = 0
        case inline      = 1
        case hashWithNameHint = 2
    }

    private static func _schemaDrivenCall(
        _ fn: (UnsafePointer<CChar>?, UnsafePointer<CChar>?,
               Int32, UnsafePointer<CChar>?,
               UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> UnsafeMutablePointer<CChar>?,
        _ input: String, _ schema: String,
        _ refForm: SchemaRefForm, _ nameHint: String?
    ) throws -> Data {
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        let hint = nameHint ?? ""
        guard let out = input.withCString({ ip in
            schema.withCString({ sp in
                hint.withCString({ hp in
                    fn(ip, sp, refForm.rawValue, hp, &errPtr)
                })
            })
        }) else {
            throw CXError.parse(_errMessage(errPtr, fallback: "cx_*_to_data_bin_schema_driven: unknown error"))
        }
        let raw = UnsafeRawPointer(out)
        let sizeLE = raw.load(as: UInt32.self)
        let size = Int(UInt32(littleEndian: sizeLE))
        let payload = Data(bytes: raw.advanced(by: 4), count: size)
        cx_free(out)
        return payload
    }

    public static func toDataBinSchemaDriven(
        _ input: String, schema: String,
        refForm: SchemaRefForm = .contentHash, nameHint: String? = nil
    ) throws -> Data {
        try _schemaDrivenCall(cx_to_data_bin_schema_driven, input, schema, refForm, nameHint)
    }

    public static func xmlToDataBinSchemaDriven(
        _ input: String, schema: String,
        refForm: SchemaRefForm = .contentHash, nameHint: String? = nil
    ) throws -> Data {
        try _schemaDrivenCall(cx_xml_to_data_bin_schema_driven, input, schema, refForm, nameHint)
    }

    public static func jsonToDataBinSchemaDriven(
        _ input: String, schema: String,
        refForm: SchemaRefForm = .contentHash, nameHint: String? = nil
    ) throws -> Data {
        try _schemaDrivenCall(cx_json_to_data_bin_schema_driven, input, schema, refForm, nameHint)
    }

    public static func yamlToDataBinSchemaDriven(
        _ input: String, schema: String,
        refForm: SchemaRefForm = .contentHash, nameHint: String? = nil
    ) throws -> Data {
        try _schemaDrivenCall(cx_yaml_to_data_bin_schema_driven, input, schema, refForm, nameHint)
    }

    public static func tomlToDataBinSchemaDriven(
        _ input: String, schema: String,
        refForm: SchemaRefForm = .contentHash, nameHint: String? = nil
    ) throws -> Data {
        try _schemaDrivenCall(cx_toml_to_data_bin_schema_driven, input, schema, refForm, nameHint)
    }

    public static func mdToDataBinSchemaDriven(
        _ input: String, schema: String,
        refForm: SchemaRefForm = .contentHash, nameHint: String? = nil
    ) throws -> Data {
        try _schemaDrivenCall(cx_md_to_data_bin_schema_driven, input, schema, refForm, nameHint)
    }

    public static func csvToDataBinSchemaDriven(
        _ input: String, schema: String,
        refForm: SchemaRefForm = .contentHash, nameHint: String? = nil
    ) throws -> Data {
        try _schemaDrivenCall(cx_csv_to_data_bin_schema_driven, input, schema, refForm, nameHint)
    }

    public static func tsvToDataBinSchemaDriven(
        _ input: String, schema: String,
        refForm: SchemaRefForm = .contentHash, nameHint: String? = nil
    ) throws -> Data {
        try _schemaDrivenCall(cx_tsv_to_data_bin_schema_driven, input, schema, refForm, nameHint)
    }

    public static func psvToDataBinSchemaDriven(
        _ input: String, schema: String,
        refForm: SchemaRefForm = .contentHash, nameHint: String? = nil
    ) throws -> Data {
        try _schemaDrivenCall(cx_psv_to_data_bin_schema_driven, input, schema, refForm, nameHint)
    }

    /// Decode a FRAMED schema-driven CXDB buffer to canonical CX text.
    /// `schemaHint` is consulted when the embedded reference is
    /// content-hash-only and not resolvable from a content-addressable
    /// store; pass `nil` or `""` to rely on embedded resolution alone.
    public static func fromDataBinSchemaDriven(_ framed: Data, schemaHint: String? = nil) throws -> String {
        if framed.isEmpty { throw CXError.parse("cx_from_data_bin_schema_driven: empty input") }
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        let hint = schemaHint ?? ""
        let result: UnsafeMutablePointer<CChar>? = framed.withUnsafeBytes { raw in
            let p = raw.baseAddress!.assumingMemoryBound(to: CChar.self)
            return hint.withCString { hp in
                cx_from_data_bin_schema_driven(p, hp, &errPtr)
            }
        }
        guard let out = result else {
            throw CXError.parse(_errMessage(errPtr, fallback: "cx_from_data_bin_schema_driven: unknown error"))
        }
        let s = String(cString: out)
        cx_free(out)
        return s
    }
}

// ── TableReader ────────────────────────────────────────────────────────────

/// Streaming reader over a chunked-table CXDB buffer or fd. Iterating
/// yields each row group as FRAMED `[u32 LE size][plain body]` Data.
public final class TableReader: Sequence, IteratorProtocol {
    private var handle: cx_table_reader_handle?
    private var closed: Bool = false
    private var errored: Bool = false

    /// Open a streaming reader over an in-memory FRAMED chunked-table buffer.
    public init(dataBin: Data) throws {
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        let h: cx_table_reader_handle? = dataBin.withUnsafeBytes { raw in
            let p = raw.baseAddress!.assumingMemoryBound(to: CChar.self)
            return cx_table_reader_open(p, &errPtr)
        }
        guard let opened = h else {
            throw CXError.parse(_errMessage(errPtr, fallback: "cx_table_reader_open: unknown error"))
        }
        self.handle = opened
    }

    /// Open a streaming reader over a POSIX file descriptor; fd reads
    /// bare CXDB bytes (no size prefix).
    public init(fd: Int32) throws {
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        guard let opened = cx_table_reader_open_fd(fd, &errPtr) else {
            throw CXError.parse(_errMessage(errPtr, fallback: "cx_table_reader_open_fd: unknown error"))
        }
        self.handle = opened
    }

    /// Return the table's column spec as FRAMED ast_bin (root Element
    /// "table" with one Attribute per column: name → type-name).
    public func schema() throws -> Data {
        guard !closed, let h = handle else { throw CXError.parse("TableReader: handle closed") }
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        guard let out = cx_table_reader_schema(h, &errPtr) else {
            throw CXError.parse(_errMessage(errPtr, fallback: "cx_table_reader_schema: unknown error"))
        }
        let data = _readFramed(out)
        cx_free(out)
        return data
    }

    /// Pull the next row group as FRAMED bytes, or nil at end-of-table.
    /// Throws on decode error.
    public func next() -> Data? {
        if closed || errored { return nil }
        guard let h = handle else { return nil }
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        guard let out = cx_table_reader_next(h, &errPtr) else {
            // EOF when err_out unset; error when set.
            if errPtr != nil {
                errored = true
                _ = _errMessage(errPtr, fallback: "")
            }
            return nil
        }
        let data = _readFramed(out)
        cx_free(out)
        return data
    }

    public func close() {
        if closed { return }
        closed = true
        if let h = handle {
            cx_table_reader_close(h)
            handle = nil
        }
    }

    deinit { close() }
}

// ── TableWriter ────────────────────────────────────────────────────────────

/// Streaming writer for the chunked-table CXDB format.
public final class TableWriter {
    private var handle: cx_table_writer_handle?
    private var closed: Bool = false
    private let isFd: Bool

    /// Open an in-memory writer. `colSpecPayload` is the FRAMED ast_bin
    /// shape returned by `TableReader.schema()`.
    public init(colSpec: Data) throws {
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        let h: cx_table_writer_handle? = colSpec.withUnsafeBytes { raw in
            let p = raw.baseAddress!.assumingMemoryBound(to: CChar.self)
            return cx_table_writer_open(p, &errPtr)
        }
        guard let opened = h else {
            throw CXError.parse(_errMessage(errPtr, fallback: "cx_table_writer_open: unknown error"))
        }
        self.handle = opened
        self.isFd = false
    }

    /// Open a writer that streams output to a POSIX file descriptor.
    public init(colSpec: Data, fd: Int32) throws {
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        let h: cx_table_writer_handle? = colSpec.withUnsafeBytes { raw in
            let p = raw.baseAddress!.assumingMemoryBound(to: CChar.self)
            return cx_table_writer_open_fd(p, fd, &errPtr)
        }
        guard let opened = h else {
            throw CXError.parse(_errMessage(errPtr, fallback: "cx_table_writer_open_fd: unknown error"))
        }
        self.handle = opened
        self.isFd = true
    }

    /// Append one row group. `rowGroup` is the FRAMED bytes yielded by
    /// `TableReader.next()`.
    public func emit(_ rowGroup: Data) throws {
        guard !closed, let h = handle else { throw CXError.parse("TableWriter: handle closed") }
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        rowGroup.withUnsafeBytes { raw in
            let p = raw.baseAddress!.assumingMemoryBound(to: CChar.self)
            _ = cx_table_writer_emit_row_group(h, p, &errPtr)
        }
        if let ep = errPtr {
            let msg = String(cString: ep)
            cx_free(ep)
            throw CXError.parse(msg)
        }
    }

    /// In-memory writers only: emit end-of-table and return the FRAMED
    /// chunked-table buffer. The handle is consumed by this call.
    public func closeGetBytes() throws -> Data {
        if isFd {
            throw CXError.parse("closeGetBytes is for in-memory writers; use close() for fd writers")
        }
        guard !closed, let h = handle else { throw CXError.parse("TableWriter: handle closed") }
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        let result = cx_table_writer_close_get_bytes(h, &errPtr)
        // V core releases the handle inside close_get_bytes; mark closed.
        self.handle = nil
        self.closed = true
        guard let out = result else {
            throw CXError.parse(_errMessage(errPtr, fallback: "cx_table_writer_close_get_bytes: unknown error"))
        }
        let data = _readFramed(out)
        cx_free(out)
        return data
    }

    public func close() {
        if closed { return }
        closed = true
        if let h = handle {
            cx_table_writer_close(h)
            handle = nil
        }
    }

    deinit { close() }
}
