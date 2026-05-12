using System;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace CX;

/// <summary>
/// Pull-based iterator over CX streaming events backed by the
/// <c>cx_events_open</c> / <c>cx_events_next</c> / <c>cx_events_close</c>
/// handle API. Replaces the prior eager-buffered cx_to_events_bin
/// path (Phase 5 / CB-4).
///
/// <para>Usage:
/// <code>
///   using var s = EventStream.Open(cxStr);
///   foreach (var ev in s) {
///       if (ev.Type == "StartElement") ...
///   }
/// </code>
/// </para>
/// </summary>
public sealed class EventStream : IEnumerable<StreamEvent>, IDisposable
{
    private IntPtr _handle;
    private bool   _closed;

    private EventStream(IntPtr handle)
    {
        _handle = handle;
    }

    /// <summary>Open a streaming handle for the given CX input.</summary>
    public static EventStream Open(string cxStr)
    {
        var h = CxLib.EventsOpen(cxStr, out var ePtr);
        if (h == IntPtr.Zero)
        {
            string msg = ePtr != IntPtr.Zero
                ? (Marshal.PtrToStringUTF8(ePtr) ?? "cx_events_open: unknown error")
                : "cx_events_open: unknown error";
            if (ePtr != IntPtr.Zero) CxLib.CxFree(ePtr);
            throw new InvalidOperationException(msg);
        }
        return new EventStream(h);
    }

    /// <summary>Pull the next event, or null on EOF.</summary>
    public StreamEvent? Next()
    {
        if (_closed || _handle == IntPtr.Zero) return null;
        var raw = CxLib.EventsNext(_handle, out var ePtr);
        if (raw == IntPtr.Zero)
        {
            // NULL with err = error; NULL with no err = EOF.
            if (ePtr != IntPtr.Zero)
            {
                string msg = Marshal.PtrToStringUTF8(ePtr) ?? "unknown error";
                CxLib.CxFree(ePtr);
                Close();
                throw new InvalidOperationException(msg);
            }
            Close();
            return null;
        }
        // Read framed [u32 size][payload] from the C-owned buffer.
        uint size = (uint)(
              Marshal.ReadByte(raw, 0)
            | (Marshal.ReadByte(raw, 1) << 8)
            | (Marshal.ReadByte(raw, 2) << 16)
            | (Marshal.ReadByte(raw, 3) << 24));
        var payload = new byte[size];
        Marshal.Copy(raw + 4, payload, 0, (int)size);
        CxLib.CxFree(raw);
        return BinaryDecoder.DecodeOneEvent(payload);
    }

    /// <summary>Release the underlying handle. Idempotent.</summary>
    public void Close()
    {
        if (_closed) return;
        _closed = true;
        if (_handle != IntPtr.Zero)
        {
            CxLib.EventsClose(_handle);
            _handle = IntPtr.Zero;
        }
    }

    public void Dispose() => Close();

    public IEnumerator<StreamEvent> GetEnumerator()
    {
        for (var ev = Next(); ev is not null; ev = Next())
            yield return ev;
    }

    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
}
