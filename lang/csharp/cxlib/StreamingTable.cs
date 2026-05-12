using System;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace CX;

/// <summary>
/// Streaming Table reader / writer + schema-driven CXDB encoding +
/// chunked-table one-shot. Per spec/abi.md §§2.10 / 2.12 (capability
/// bits 21 / 24) and ADR 0015 D3 / D8.
///
/// Wire conventions (mirroring the C ABI):
///   - <see cref="CxLib.ToDataBinChunked"/> returns UNFRAMED CXDB payload
///     bytes (frame stripped), matching <see cref="CxLib.ToDataBin"/>.
///   - <see cref="CxLib.XmlToDataBinSchemaDriven"/> et al. return
///     UNFRAMED payload bytes too.
///   - <see cref="CxLib.FromDataBinSchemaDriven"/> takes a FRAMED buffer.
///   - <see cref="TableReader"/> and <see cref="TableWriter"/> exchange
///     FRAMED bytes end-to-end (col-spec, row groups, output buffer).
///   - fd variants of the streaming API operate on bare CXDB bytes.
/// </summary>
public static partial class CxLib
{
    private const string LibSt = "cx";

    // ── chunked-table one-shot (Phase 7.72; spec/abi.md §2.10) ───────────────

    [DllImport(LibSt, EntryPoint = "cx_to_data_bin_chunked", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeToDataBinChunked(string input, out IntPtr e);

    /// <summary>
    /// Encode CX text whose root is a single <c>:table</c>-bodied element to
    /// CXDB chunked-table form (<c>0x63</c>). Returns UNFRAMED CXDB payload
    /// bytes (frame stripped). Capability bit 21.
    /// </summary>
    public static byte[] ToDataBinChunked(string input)
    {
        var r = NativeToDataBinChunked(input, out var e);
        return UnwrapBinSt(r, e);
    }

    // ── schema-driven loaders / dumper (Phase 7.73; spec/abi.md §2.12) ───────

    [DllImport(LibSt, EntryPoint = "cx_to_data_bin_schema_driven", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeToDataBinSchemaDriven(string input, string schema, int refForm, string nameHint, out IntPtr e);
    [DllImport(LibSt, EntryPoint = "cx_xml_to_data_bin_schema_driven", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeXmlToDataBinSchemaDriven(string input, string schema, int refForm, string nameHint, out IntPtr e);
    [DllImport(LibSt, EntryPoint = "cx_json_to_data_bin_schema_driven", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeJsonToDataBinSchemaDriven(string input, string schema, int refForm, string nameHint, out IntPtr e);
    [DllImport(LibSt, EntryPoint = "cx_yaml_to_data_bin_schema_driven", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeYamlToDataBinSchemaDriven(string input, string schema, int refForm, string nameHint, out IntPtr e);
    [DllImport(LibSt, EntryPoint = "cx_toml_to_data_bin_schema_driven", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeTomlToDataBinSchemaDriven(string input, string schema, int refForm, string nameHint, out IntPtr e);
    [DllImport(LibSt, EntryPoint = "cx_md_to_data_bin_schema_driven", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeMdToDataBinSchemaDriven(string input, string schema, int refForm, string nameHint, out IntPtr e);
    [DllImport(LibSt, EntryPoint = "cx_csv_to_data_bin_schema_driven", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeCsvToDataBinSchemaDriven(string input, string schema, int refForm, string nameHint, out IntPtr e);
    [DllImport(LibSt, EntryPoint = "cx_tsv_to_data_bin_schema_driven", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeTsvToDataBinSchemaDriven(string input, string schema, int refForm, string nameHint, out IntPtr e);
    [DllImport(LibSt, EntryPoint = "cx_psv_to_data_bin_schema_driven", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativePsvToDataBinSchemaDriven(string input, string schema, int refForm, string nameHint, out IntPtr e);

    [DllImport(LibSt, EntryPoint = "cx_from_data_bin_schema_driven", CharSet = CharSet.Ansi)]
    private static extern IntPtr NativeFromDataBinSchemaDriven(byte[] dataBin, string schemaHint, out IntPtr e);

    /// <summary>Schema reference embedding form (per spec/data_bin.md §3.13.1).</summary>
    public enum SchemaRefForm
    {
        ContentHash       = 0,
        Inline            = 1,
        HashWithNameHint  = 2,
    }

    private delegate IntPtr SchemaDrivenFn(string input, string schema, int refForm, string nameHint, out IntPtr e);

    private static byte[] CallSchemaDriven(SchemaDrivenFn fn, string input, string schema,
                                           SchemaRefForm refForm, string? nameHint)
    {
        var r = fn(input, schema, (int)refForm, nameHint ?? string.Empty, out var e);
        return UnwrapBinSt(r, e);
    }

    public static byte[] ToDataBinSchemaDriven(string input, string schema,
        SchemaRefForm refForm = SchemaRefForm.ContentHash, string? nameHint = null)
        => CallSchemaDriven(NativeToDataBinSchemaDriven, input, schema, refForm, nameHint);

    public static byte[] XmlToDataBinSchemaDriven(string input, string schema,
        SchemaRefForm refForm = SchemaRefForm.ContentHash, string? nameHint = null)
        => CallSchemaDriven(NativeXmlToDataBinSchemaDriven, input, schema, refForm, nameHint);

    public static byte[] JsonToDataBinSchemaDriven(string input, string schema,
        SchemaRefForm refForm = SchemaRefForm.ContentHash, string? nameHint = null)
        => CallSchemaDriven(NativeJsonToDataBinSchemaDriven, input, schema, refForm, nameHint);

    public static byte[] YamlToDataBinSchemaDriven(string input, string schema,
        SchemaRefForm refForm = SchemaRefForm.ContentHash, string? nameHint = null)
        => CallSchemaDriven(NativeYamlToDataBinSchemaDriven, input, schema, refForm, nameHint);

    public static byte[] TomlToDataBinSchemaDriven(string input, string schema,
        SchemaRefForm refForm = SchemaRefForm.ContentHash, string? nameHint = null)
        => CallSchemaDriven(NativeTomlToDataBinSchemaDriven, input, schema, refForm, nameHint);

    public static byte[] MdToDataBinSchemaDriven(string input, string schema,
        SchemaRefForm refForm = SchemaRefForm.ContentHash, string? nameHint = null)
        => CallSchemaDriven(NativeMdToDataBinSchemaDriven, input, schema, refForm, nameHint);

    public static byte[] CsvToDataBinSchemaDriven(string input, string schema,
        SchemaRefForm refForm = SchemaRefForm.ContentHash, string? nameHint = null)
        => CallSchemaDriven(NativeCsvToDataBinSchemaDriven, input, schema, refForm, nameHint);

    public static byte[] TsvToDataBinSchemaDriven(string input, string schema,
        SchemaRefForm refForm = SchemaRefForm.ContentHash, string? nameHint = null)
        => CallSchemaDriven(NativeTsvToDataBinSchemaDriven, input, schema, refForm, nameHint);

    public static byte[] PsvToDataBinSchemaDriven(string input, string schema,
        SchemaRefForm refForm = SchemaRefForm.ContentHash, string? nameHint = null)
        => CallSchemaDriven(NativePsvToDataBinSchemaDriven, input, schema, refForm, nameHint);

    /// <summary>
    /// Decode a FRAMED schema-driven CXDB buffer to canonical CX text.
    /// <paramref name="schemaHint"/> is consulted when the embedded
    /// reference is content-hash-only and not resolvable from a
    /// content-addressable store; pass <c>null</c> or <c>""</c> to rely
    /// on embedded resolution alone.
    /// </summary>
    public static string FromDataBinSchemaDriven(byte[] framed, string? schemaHint = null)
    {
        if (framed is null || framed.Length == 0)
            throw new InvalidOperationException("cx_from_data_bin_schema_driven: empty input");
        var r = NativeFromDataBinSchemaDriven(framed, schemaHint ?? string.Empty, out var e);
        if (r == IntPtr.Zero)
        {
            string msg = e != IntPtr.Zero
                ? (Marshal.PtrToStringUTF8(e) ?? "unknown error")
                : "unknown error";
            if (e != IntPtr.Zero) CxFree(e);
            throw new InvalidOperationException(msg);
        }
        string s = Marshal.PtrToStringUTF8(r) ?? "";
        CxFree(r);
        return s;
    }

    // ── streaming Table reader / writer (Phase 7.74a; spec/abi.md §2.10) ─────

    [DllImport(LibSt, EntryPoint = "cx_table_reader_open")]
    internal static extern IntPtr NativeTableReaderOpen(byte[] dataBin, out IntPtr e);
    [DllImport(LibSt, EntryPoint = "cx_table_reader_open_fd")]
    internal static extern IntPtr NativeTableReaderOpenFd(int fd, out IntPtr e);
    [DllImport(LibSt, EntryPoint = "cx_table_reader_schema")]
    internal static extern IntPtr NativeTableReaderSchema(IntPtr handle, out IntPtr e);
    [DllImport(LibSt, EntryPoint = "cx_table_reader_next")]
    internal static extern IntPtr NativeTableReaderNext(IntPtr handle, out IntPtr e);
    [DllImport(LibSt, EntryPoint = "cx_table_reader_close")]
    internal static extern void NativeTableReaderClose(IntPtr handle);

    [DllImport(LibSt, EntryPoint = "cx_table_writer_open")]
    internal static extern IntPtr NativeTableWriterOpen(byte[] colSpec, out IntPtr e);
    [DllImport(LibSt, EntryPoint = "cx_table_writer_open_fd")]
    internal static extern IntPtr NativeTableWriterOpenFd(byte[] colSpec, int fd, out IntPtr e);
    [DllImport(LibSt, EntryPoint = "cx_table_writer_emit_row_group")]
    internal static extern IntPtr NativeTableWriterEmitRowGroup(IntPtr handle, byte[] rowGroup, out IntPtr e);
    [DllImport(LibSt, EntryPoint = "cx_table_writer_close_get_bytes")]
    internal static extern IntPtr NativeTableWriterCloseGetBytes(IntPtr handle, out IntPtr e);
    [DllImport(LibSt, EntryPoint = "cx_table_writer_close")]
    internal static extern void NativeTableWriterClose(IntPtr handle);

    // ── helper (separate symbol to avoid conflicting with UnwrapBin) ─────────

    /// <summary>
    /// Read a [u32 LE size][payload] buffer from a libcx-owned pointer,
    /// copy the FRAMED (4 + size) bytes into a managed array, free the
    /// native pointer, and return.
    /// </summary>
    private static byte[] ReadFramed(IntPtr ptr)
    {
        uint size = (uint)(
              Marshal.ReadByte(ptr, 0)
            | (Marshal.ReadByte(ptr, 1) << 8)
            | (Marshal.ReadByte(ptr, 2) << 16)
            | (Marshal.ReadByte(ptr, 3) << 24));
        var framed = new byte[4 + size];
        Marshal.Copy(ptr, framed, 0, framed.Length);
        return framed;
    }

    internal static byte[] ReadFramedAndFree(IntPtr ptr)
    {
        var framed = ReadFramed(ptr);
        CxFree(ptr);
        return framed;
    }

    private static byte[] UnwrapBinSt(IntPtr result, IntPtr errPtr)
    {
        if (result == IntPtr.Zero)
        {
            string msg = errPtr != IntPtr.Zero
                ? (Marshal.PtrToStringUTF8(errPtr) ?? "unknown error")
                : "unknown error";
            if (errPtr != IntPtr.Zero) CxFree(errPtr);
            throw new InvalidOperationException(msg);
        }
        // UNFRAMED: copy just the payload, drop the [u32] header.
        uint size = (uint)(
              Marshal.ReadByte(result, 0)
            | (Marshal.ReadByte(result, 1) << 8)
            | (Marshal.ReadByte(result, 2) << 16)
            | (Marshal.ReadByte(result, 3) << 24));
        var payload = new byte[size];
        Marshal.Copy(result + 4, payload, 0, (int)size);
        CxFree(result);
        return payload;
    }
}

/// <summary>
/// Streaming reader over a chunked-table CXDB buffer or fd. Iterating
/// yields each row group as FRAMED <c>[u32 LE size][plain body]</c> bytes.
/// </summary>
public sealed class TableReader : IDisposable, IEnumerable<byte[]>
{
    private IntPtr _handle;
    private bool _closed;
    private bool _errored;

    /// <summary>Open a streaming reader over an in-memory FRAMED chunked-table buffer.</summary>
    public TableReader(byte[] dataBin)
    {
        if (dataBin is null || dataBin.Length == 0)
            throw new InvalidOperationException("TableReader: empty data_bin");
        var h = CxLib.NativeTableReaderOpen(dataBin, out var e);
        if (h == IntPtr.Zero)
        {
            string msg = e != IntPtr.Zero
                ? (Marshal.PtrToStringUTF8(e) ?? "unknown error")
                : "unknown error";
            if (e != IntPtr.Zero) CxLib.CxFree(e);
            throw new InvalidOperationException(msg);
        }
        _handle = h;
    }

    /// <summary>
    /// Open a streaming reader over a POSIX file descriptor; fd reads
    /// bare CXDB bytes (no size prefix).
    /// </summary>
    public static TableReader FromFd(int fd)
    {
        var h = CxLib.NativeTableReaderOpenFd(fd, out var e);
        if (h == IntPtr.Zero)
        {
            string msg = e != IntPtr.Zero
                ? (Marshal.PtrToStringUTF8(e) ?? "unknown error")
                : "unknown error";
            if (e != IntPtr.Zero) CxLib.CxFree(e);
            throw new InvalidOperationException(msg);
        }
        return new TableReader(h);
    }

    private TableReader(IntPtr handle) { _handle = handle; }

    /// <summary>
    /// Return the table's column spec as FRAMED ast_bin (root Element
    /// "table" with one Attribute per column: name → type-name).
    /// </summary>
    public byte[] Schema()
    {
        if (_closed || _handle == IntPtr.Zero)
            throw new InvalidOperationException("TableReader: handle closed");
        var r = CxLib.NativeTableReaderSchema(_handle, out var e);
        if (r == IntPtr.Zero)
        {
            string msg = e != IntPtr.Zero
                ? (Marshal.PtrToStringUTF8(e) ?? "unknown error")
                : "unknown error";
            if (e != IntPtr.Zero) CxLib.CxFree(e);
            throw new InvalidOperationException(msg);
        }
        return CxLib.ReadFramedAndFree(r);
    }

    /// <summary>
    /// Pull the next row group as FRAMED bytes, or null at end-of-table.
    /// Throws on decode error.
    /// </summary>
    public byte[]? Next()
    {
        if (_closed || _errored || _handle == IntPtr.Zero) return null;
        var r = CxLib.NativeTableReaderNext(_handle, out var e);
        if (r == IntPtr.Zero)
        {
            // EOF when err_out unset; error when set.
            if (e != IntPtr.Zero)
            {
                string msg = Marshal.PtrToStringUTF8(e) ?? "unknown error";
                CxLib.CxFree(e);
                _errored = true;
                throw new InvalidOperationException(msg);
            }
            return null;
        }
        return CxLib.ReadFramedAndFree(r);
    }

    public IEnumerator<byte[]> GetEnumerator()
    {
        while (true)
        {
            var g = Next();
            if (g is null) yield break;
            yield return g;
        }
    }

    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();

    public void Close()
    {
        if (_closed) return;
        _closed = true;
        if (_handle != IntPtr.Zero)
        {
            CxLib.NativeTableReaderClose(_handle);
            _handle = IntPtr.Zero;
        }
    }

    public void Dispose() => Close();
    ~TableReader() { Close(); }
}

/// <summary>Streaming writer for the chunked-table CXDB format.</summary>
public sealed class TableWriter : IDisposable
{
    private IntPtr _handle;
    private bool _closed;
    private readonly bool _isFd;

    /// <summary>
    /// Open an in-memory writer. <paramref name="colSpec"/> is the FRAMED
    /// ast_bin shape returned by <see cref="TableReader.Schema"/>.
    /// </summary>
    public TableWriter(byte[] colSpec)
    {
        if (colSpec is null || colSpec.Length == 0)
            throw new InvalidOperationException("TableWriter: empty col_spec");
        var h = CxLib.NativeTableWriterOpen(colSpec, out var e);
        if (h == IntPtr.Zero)
        {
            string msg = e != IntPtr.Zero
                ? (Marshal.PtrToStringUTF8(e) ?? "unknown error")
                : "unknown error";
            if (e != IntPtr.Zero) CxLib.CxFree(e);
            throw new InvalidOperationException(msg);
        }
        _handle = h;
        _isFd = false;
    }

    private TableWriter(IntPtr handle, bool isFd) { _handle = handle; _isFd = isFd; }

    /// <summary>Open a writer that streams output to a POSIX file descriptor.</summary>
    public static TableWriter ToFd(byte[] colSpec, int fd)
    {
        if (colSpec is null || colSpec.Length == 0)
            throw new InvalidOperationException("TableWriter: empty col_spec");
        var h = CxLib.NativeTableWriterOpenFd(colSpec, fd, out var e);
        if (h == IntPtr.Zero)
        {
            string msg = e != IntPtr.Zero
                ? (Marshal.PtrToStringUTF8(e) ?? "unknown error")
                : "unknown error";
            if (e != IntPtr.Zero) CxLib.CxFree(e);
            throw new InvalidOperationException(msg);
        }
        return new TableWriter(h, isFd: true);
    }

    /// <summary>
    /// Append one row group. <paramref name="rowGroup"/> is the FRAMED bytes
    /// yielded by <see cref="TableReader.Next"/>.
    /// </summary>
    public void Emit(byte[] rowGroup)
    {
        if (_closed || _handle == IntPtr.Zero)
            throw new InvalidOperationException("TableWriter: handle closed");
        if (rowGroup is null || rowGroup.Length == 0)
            throw new InvalidOperationException("TableWriter.Emit: empty row group");
        _ = CxLib.NativeTableWriterEmitRowGroup(_handle, rowGroup, out var e);
        if (e != IntPtr.Zero)
        {
            string msg = Marshal.PtrToStringUTF8(e) ?? "unknown error";
            CxLib.CxFree(e);
            throw new InvalidOperationException(msg);
        }
    }

    /// <summary>
    /// In-memory writers only: emit end-of-table and return the FRAMED
    /// chunked-table buffer. The handle is consumed by this call.
    /// </summary>
    public byte[] CloseGetBytes()
    {
        if (_isFd)
            throw new InvalidOperationException("CloseGetBytes is for in-memory writers; use Close() for fd writers");
        if (_closed || _handle == IntPtr.Zero)
            throw new InvalidOperationException("TableWriter: handle closed");
        var r = CxLib.NativeTableWriterCloseGetBytes(_handle, out var e);
        // V core releases the handle inside close_get_bytes; mark closed.
        _handle = IntPtr.Zero;
        _closed = true;
        if (r == IntPtr.Zero)
        {
            string msg = e != IntPtr.Zero
                ? (Marshal.PtrToStringUTF8(e) ?? "unknown error")
                : "unknown error";
            if (e != IntPtr.Zero) CxLib.CxFree(e);
            throw new InvalidOperationException(msg);
        }
        return CxLib.ReadFramedAndFree(r);
    }

    public void Close()
    {
        if (_closed) return;
        _closed = true;
        if (_handle != IntPtr.Zero)
        {
            CxLib.NativeTableWriterClose(_handle);
            _handle = IntPtr.Zero;
        }
    }

    public void Dispose() => Close();
    ~TableWriter() { Close(); }
}
