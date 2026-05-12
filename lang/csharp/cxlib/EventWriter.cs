using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

namespace CX;

/// <summary>
/// Streaming-write API binding — per spec/streaming.md §6 + ADR 0011 +
/// spec/abi.md §2.15. Thin wrapper over the 25 cx_events_writer_* C ABI
/// symbols. CX and XML output formats are implemented end-to-end in
/// v0.6.0; json / yaml / toml / md emits surface a W009 exception until
/// their follow-up phases land. Capability bit 27.
///
/// Errors throw <see cref="InvalidOperationException"/> whose Message
/// carries the W001-W013 prefix verbatim. The writer fails closed —
/// after the first W-code, subsequent emits throw the same diagnostic
/// without effect.
///
/// Usage:
/// <code>
/// using var w = new EventWriter("cx");
/// w.StartDoc();
/// w.StartElement("greet");
/// w.Text("hello");
/// w.EndElement("greet");
/// w.EndDoc();
/// byte[] bytes = w.CloseGetBytes();
/// </code>
/// </summary>
public static partial class CxLib
{
    private const string LibEw = "cx";

    [DllImport(LibEw, EntryPoint = "cx_events_writer_open", CharSet = CharSet.Ansi)]
    internal static extern IntPtr NativeEventsWriterOpen(string fmt, out IntPtr e);
    [DllImport(LibEw, EntryPoint = "cx_events_writer_open_fd", CharSet = CharSet.Ansi)]
    internal static extern IntPtr NativeEventsWriterOpenFd(string fmt, int fd, out IntPtr e);

    [DllImport(LibEw, EntryPoint = "cx_events_writer_close_get_bytes")]
    internal static extern IntPtr NativeEventsWriterCloseGetBytes(IntPtr h, out IntPtr e);
    [DllImport(LibEw, EntryPoint = "cx_events_writer_close")]
    internal static extern void NativeEventsWriterClose(IntPtr h);

    [DllImport(LibEw, EntryPoint = "cx_events_writer_start_doc")]
    internal static extern IntPtr NativeEventsWriterStartDoc(IntPtr h, out IntPtr e);
    [DllImport(LibEw, EntryPoint = "cx_events_writer_end_doc")]
    internal static extern IntPtr NativeEventsWriterEndDoc(IntPtr h, out IntPtr e);

    [DllImport(LibEw, EntryPoint = "cx_events_writer_start_element_with_len", CharSet = CharSet.Ansi)]
    internal static extern IntPtr NativeEventsWriterStartElementWithLen(
        IntPtr h, string name, string? anchor, string? dataType, string? merge,
        byte[]? attrsPayload, UIntPtr attrsLen, out IntPtr e);
    [DllImport(LibEw, EntryPoint = "cx_events_writer_end_element", CharSet = CharSet.Ansi)]
    internal static extern IntPtr NativeEventsWriterEndElement(IntPtr h, string name, out IntPtr e);

    [DllImport(LibEw, EntryPoint = "cx_events_writer_text", CharSet = CharSet.Ansi)]
    internal static extern IntPtr NativeEventsWriterText(IntPtr h, string value, out IntPtr e);
    [DllImport(LibEw, EntryPoint = "cx_events_writer_scalar", CharSet = CharSet.Ansi)]
    internal static extern IntPtr NativeEventsWriterScalar(IntPtr h, string? dataType, string value, out IntPtr e);
    [DllImport(LibEw, EntryPoint = "cx_events_writer_comment", CharSet = CharSet.Ansi)]
    internal static extern IntPtr NativeEventsWriterComment(IntPtr h, string value, out IntPtr e);
    [DllImport(LibEw, EntryPoint = "cx_events_writer_pi", CharSet = CharSet.Ansi)]
    internal static extern IntPtr NativeEventsWriterPi(IntPtr h, string target, string? data, out IntPtr e);
    [DllImport(LibEw, EntryPoint = "cx_events_writer_entity_ref", CharSet = CharSet.Ansi)]
    internal static extern IntPtr NativeEventsWriterEntityRef(IntPtr h, string name, out IntPtr e);
    [DllImport(LibEw, EntryPoint = "cx_events_writer_raw_text", CharSet = CharSet.Ansi)]
    internal static extern IntPtr NativeEventsWriterRawText(IntPtr h, string value, out IntPtr e);
    [DllImport(LibEw, EntryPoint = "cx_events_writer_alias", CharSet = CharSet.Ansi)]
    internal static extern IntPtr NativeEventsWriterAlias(IntPtr h, string name, out IntPtr e);

    [DllImport(LibEw, EntryPoint = "cx_events_writer_start_table_with_len")]
    internal static extern IntPtr NativeEventsWriterStartTableWithLen(
        IntPtr h, byte[] colSpec, UIntPtr colSpecLen, out IntPtr e);
    [DllImport(LibEw, EntryPoint = "cx_events_writer_row_group_with_len")]
    internal static extern IntPtr NativeEventsWriterRowGroupWithLen(
        IntPtr h, byte[] payload, UIntPtr payloadLen, out IntPtr e);
    [DllImport(LibEw, EntryPoint = "cx_events_writer_end_table")]
    internal static extern IntPtr NativeEventsWriterEndTable(IntPtr h, out IntPtr e);
}

/// <summary>One start-element attribute. <c>DataType</c> empty defaults to <c>"string"</c>.</summary>
public readonly record struct EventAttr(string Name, string Value, string DataType = "");

/// <summary>Streaming event writer. Class H per spec/abi.md §1.5.1 (one writer = one thread).</summary>
public sealed class EventWriter : IDisposable
{
    private const ulong CapBitStreamingWrite = 1UL << 27;

    private IntPtr _handle;
    private bool _closed;
    private readonly bool _fdMode;

    /// <summary>Open an in-memory writer for the given output format.</summary>
    /// <exception cref="InvalidOperationException">
    /// Thrown if libcx doesn't advertise capability bit 27 or if libcx
    /// returns a W-code (carried verbatim in the message).
    /// </exception>
    public EventWriter(string outputFormat)
    {
        if ((CxLib.Features() & CapBitStreamingWrite) == 0)
            throw new InvalidOperationException(
                "EventWriter requires libcx capability bit 27 (streaming-write; v0.6.0+).");
        var h = CxLib.NativeEventsWriterOpen(outputFormat, out var e);
        if (h == IntPtr.Zero) throw FromErr(e, $"cx_events_writer_open({outputFormat}): unknown error");
        _handle = h;
        _fdMode = false;
    }

    private EventWriter(IntPtr handle, bool fdMode) { _handle = handle; _fdMode = fdMode; }

    /// <summary>Open an fd-streaming writer. Caller retains fd ownership.</summary>
    public static EventWriter ToFd(string outputFormat, int fd)
    {
        if ((CxLib.Features() & CapBitStreamingWrite) == 0)
            throw new InvalidOperationException(
                "EventWriter.ToFd requires libcx capability bit 27 (streaming-write; v0.6.0+).");
        var h = CxLib.NativeEventsWriterOpenFd(outputFormat, fd, out var e);
        if (h == IntPtr.Zero) throw FromErr(e, $"cx_events_writer_open_fd({outputFormat}): unknown error");
        return new EventWriter(h, fdMode: true);
    }

    private static InvalidOperationException FromErr(IntPtr errPtr, string fallback)
    {
        string msg = errPtr != IntPtr.Zero
            ? (Marshal.PtrToStringUTF8(errPtr) ?? fallback)
            : fallback;
        if (errPtr != IntPtr.Zero) CxLib.NativeEventsWriterClose(IntPtr.Zero); // no-op safety
        if (errPtr != IntPtr.Zero) CxLib_FreeShim(errPtr);
        return new InvalidOperationException(msg);
    }

    // CxFree is internal in CxLib; expose via a tiny shim that uses the
    // already-exposed events_writer_close path? No — easier: re-declare
    // cx_free privately here.
    [DllImport("cx", EntryPoint = "cx_free")]
    private static extern void CxLib_FreeShim(IntPtr p);

    private static void ThrowIfDiag(IntPtr ret, IntPtr errPtr, string op)
    {
        if (ret != IntPtr.Zero)
        {
            string msg = Marshal.PtrToStringUTF8(ret) ?? $"{op}: unknown error";
            CxLib_FreeShim(ret);
            if (errPtr != IntPtr.Zero) CxLib_FreeShim(errPtr);
            throw new InvalidOperationException(msg);
        }
        if (errPtr != IntPtr.Zero)
        {
            string msg = Marshal.PtrToStringUTF8(errPtr) ?? $"{op}: unknown error";
            CxLib_FreeShim(errPtr);
            throw new InvalidOperationException(msg);
        }
    }

    private IntPtr Live(string op)
    {
        if (_closed || _handle == IntPtr.Zero)
            throw new InvalidOperationException($"EventWriter.{op}: handle closed");
        return _handle;
    }

    /// <summary>Whether libcx advertises capability bit 27 (streaming-write).</summary>
    public static bool HasCapability => (CxLib.Features() & CapBitStreamingWrite) != 0;

    /// <summary>
    /// Finalise the writer and return the accumulated output bytes. For
    /// fd writers the returned buffer is empty (output already flushed).
    /// Implicitly emits EndDoc — throws W004 if elements / table remain
    /// open. Consumes the writer.
    /// </summary>
    public byte[] CloseGetBytes()
    {
        var h = Live("CloseGetBytes");
        var raw = CxLib.NativeEventsWriterCloseGetBytes(h, out var errPtr);
        var old = _handle;
        _handle = IntPtr.Zero;
        _closed = true;
        if (raw == IntPtr.Zero)
        {
            CxLib.NativeEventsWriterClose(old);
            throw FromErr(errPtr, "cx_events_writer_close_get_bytes: unknown error");
        }
        // Framed [u32 LE size][payload].
        uint size = (uint)(
              Marshal.ReadByte(raw, 0)
            | (Marshal.ReadByte(raw, 1) << 8)
            | (Marshal.ReadByte(raw, 2) << 16)
            | (Marshal.ReadByte(raw, 3) << 24));
        var payload = new byte[size];
        if (size > 0) Marshal.Copy(raw + 4, payload, 0, (int)size);
        CxLib_FreeShim(raw);
        CxLib.NativeEventsWriterClose(old);
        _ = _fdMode;
        return payload;
    }

    /// <summary>Release the handle without finalising output. Idempotent.</summary>
    public void Close()
    {
        if (_closed) return;
        _closed = true;
        if (_handle != IntPtr.Zero)
        {
            CxLib.NativeEventsWriterClose(_handle);
            _handle = IntPtr.Zero;
        }
    }

    public void Dispose() => Close();
    ~EventWriter() { Close(); }

    // ── lifecycle ────────────────────────────────────────────────────────────

    public void StartDoc()
    {
        var h = Live("StartDoc");
        var ret = CxLib.NativeEventsWriterStartDoc(h, out var e);
        ThrowIfDiag(ret, e, "start_doc");
    }

    public void EndDoc()
    {
        var h = Live("EndDoc");
        var ret = CxLib.NativeEventsWriterEndDoc(h, out var e);
        ThrowIfDiag(ret, e, "end_doc");
    }

    /// <summary>Emit a StartElement. <paramref name="attrs"/> may be null.</summary>
    public void StartElement(string name,
                             string? anchor = null, string? dataType = null,
                             string? merge = null, IEnumerable<EventAttr>? attrs = null)
    {
        var h = Live("StartElement");
        byte[]? framed = null;
        if (attrs != null)
        {
            var raw = BuildAttrsPayload(attrs);
            if (raw != null) framed = Frame(raw);
        }
        var ret = CxLib.NativeEventsWriterStartElementWithLen(
            h, name, anchor, dataType, merge,
            framed, framed is null ? UIntPtr.Zero : (UIntPtr)framed.Length, out var e);
        ThrowIfDiag(ret, e, "start_element");
    }

    public void EndElement(string name)
    {
        var h = Live("EndElement");
        var ret = CxLib.NativeEventsWriterEndElement(h, name, out var e);
        ThrowIfDiag(ret, e, "end_element");
    }

    public void Text(string value)
    {
        var h = Live("Text");
        var ret = CxLib.NativeEventsWriterText(h, value, out var e);
        ThrowIfDiag(ret, e, "text");
    }

    /// <summary>Emit a typed scalar. Pass <paramref name="dataType"/> = "" for inferred string.</summary>
    public void Scalar(string value, string dataType = "")
    {
        var h = Live("Scalar");
        var ret = CxLib.NativeEventsWriterScalar(h,
            string.IsNullOrEmpty(dataType) ? null : dataType, value, out var e);
        ThrowIfDiag(ret, e, "scalar");
    }

    public void Comment(string value)
    {
        var h = Live("Comment");
        var ret = CxLib.NativeEventsWriterComment(h, value, out var e);
        ThrowIfDiag(ret, e, "comment");
    }

    public void Pi(string target, string data = "")
    {
        var h = Live("Pi");
        var ret = CxLib.NativeEventsWriterPi(h, target,
            string.IsNullOrEmpty(data) ? null : data, out var e);
        ThrowIfDiag(ret, e, "pi");
    }

    public void EntityRef(string name)
    {
        var h = Live("EntityRef");
        var ret = CxLib.NativeEventsWriterEntityRef(h, name, out var e);
        ThrowIfDiag(ret, e, "entity_ref");
    }

    public void RawText(string value)
    {
        var h = Live("RawText");
        var ret = CxLib.NativeEventsWriterRawText(h, value, out var e);
        ThrowIfDiag(ret, e, "raw_text");
    }

    public void Alias(string name)
    {
        var h = Live("Alias");
        var ret = CxLib.NativeEventsWriterAlias(h, name, out var e);
        ThrowIfDiag(ret, e, "alias");
    }

    /// <summary>
    /// Open a chunked table. <paramref name="colSpecPayload"/> is the unframed
    /// column-spec wire form per spec/data_bin.md §3.10.1:
    /// <c>[u32 LE count] ([u32 LE name_len] name [u8 type_code])*</c>.
    /// </summary>
    public void StartTable(byte[] colSpecPayload)
    {
        var h = Live("StartTable");
        var framed = Frame(colSpecPayload);
        var ret = CxLib.NativeEventsWriterStartTableWithLen(
            h, framed, (UIntPtr)framed.Length, out var e);
        ThrowIfDiag(ret, e, "start_table");
    }

    /// <summary>
    /// Append a row group. <paramref name="payload"/> is the unframed §3.11.2
    /// plain body: <c>uvarint(row_count) + col-payload[col_count]</c>.
    /// </summary>
    public void RowGroup(byte[] payload)
    {
        var h = Live("RowGroup");
        var framed = Frame(payload);
        var ret = CxLib.NativeEventsWriterRowGroupWithLen(
            h, framed, (UIntPtr)framed.Length, out var e);
        ThrowIfDiag(ret, e, "row_group");
    }

    public void EndTable()
    {
        var h = Live("EndTable");
        var ret = CxLib.NativeEventsWriterEndTable(h, out var e);
        ThrowIfDiag(ret, e, "end_table");
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private static byte[] Frame(byte[] payload)
    {
        var framed = new byte[4 + payload.Length];
        framed[0] = (byte)(payload.Length & 0xFF);
        framed[1] = (byte)((payload.Length >> 8)  & 0xFF);
        framed[2] = (byte)((payload.Length >> 16) & 0xFF);
        framed[3] = (byte)((payload.Length >> 24) & 0xFF);
        Array.Copy(payload, 0, framed, 4, payload.Length);
        return framed;
    }

    private static byte[]? BuildAttrsPayload(IEnumerable<EventAttr> attrs)
    {
        var list = new List<EventAttr>(attrs);
        if (list.Count == 0) return null;
        using var ms = new System.IO.MemoryStream();
        ms.WriteByte((byte)(list.Count & 0xFF));
        ms.WriteByte((byte)((list.Count >> 8) & 0xFF));
        void EncLp(string s)
        {
            var bytes = Encoding.UTF8.GetBytes(s);
            ms.WriteByte((byte)(bytes.Length & 0xFF));
            ms.WriteByte((byte)((bytes.Length >> 8)  & 0xFF));
            ms.WriteByte((byte)((bytes.Length >> 16) & 0xFF));
            ms.WriteByte((byte)((bytes.Length >> 24) & 0xFF));
            ms.Write(bytes, 0, bytes.Length);
        }
        foreach (var a in list)
        {
            string typ = string.IsNullOrEmpty(a.DataType) ? "string" : a.DataType;
            EncLp(a.Name);
            EncLp(a.Value);
            EncLp(typ);
            ms.WriteByte(0); // is_ref
        }
        return ms.ToArray();
    }
}
