using Apache.Arrow.C;
using Apache.Arrow.Ipc;
using CX;
using System;
using System.IO;
using System.Runtime.InteropServices;

namespace CX.Arrow;

/// <summary>
/// Apache Arrow C-Data interop for cxlib (Phase 7.74c-cont-bindings-multi-csharp).
///
/// Bridges CXDB chunked-tables to Arrow <c>ArrowArrayStream</c> via libcx_arrow
/// (spec/abi.md §2.11, ADR 0015 D9, capability bit 0x800000). The bridge handles
/// the v0.6.0 column-type set: int / i8 / i16 / i32 / float / bool / string /
/// date / bytes / datetime (timestamp[ns, UTC]). decimal / dictionary remain
/// deferred and surface the V core's deferred-type error.
///
/// This assembly is OPT-IN: the default <c>cxlib.csproj</c> build does not
/// require <c>libcx_arrow</c> or the <c>Apache.Arrow</c> NuGet package.
/// Mirrors Python's <c>pip install cxlib[arrow]</c>, Go's <c>-tags arrow</c>,
/// and Rust's <c>--features arrow</c> patterns.
/// </summary>
public static class CxArrow
{
    private const string Lib = "cx_arrow";

    static CxArrow()
    {
        NativeLibrary.SetDllImportResolver(typeof(CxArrow).Assembly,
            (name, _, _) =>
            {
                if (name != Lib) return IntPtr.Zero;
                var candidates = new List<string>();

                var envPath = Environment.GetEnvironmentVariable("LIBCX_ARROW_PATH");
                if (envPath != null) candidates.Add(envPath);

                var envDir = Environment.GetEnvironmentVariable("LIBCX_LIB_DIR");
                if (envDir != null)
                {
                    candidates.Add(Path.Combine(envDir, "libcx_arrow.dylib"));
                    candidates.Add(Path.Combine(envDir, "libcx_arrow.so"));
                }

                foreach (var dir in new[] { "/usr/local/lib", "/opt/homebrew/lib", "/usr/lib",
                                            "/usr/lib/x86_64-linux-gnu", "/usr/lib/aarch64-linux-gnu" })
                {
                    candidates.Add(Path.Combine(dir, "libcx_arrow.dylib"));
                    candidates.Add(Path.Combine(dir, "libcx_arrow.so"));
                }

                try
                {
                    string repoRoot = FindRepoRoot(AppContext.BaseDirectory);
                    candidates.Add(Path.Combine(repoRoot, "vcx", "target", "libcx_arrow.dylib"));
                    candidates.Add(Path.Combine(repoRoot, "vcx", "target", "libcx_arrow.so"));
                    candidates.Add(Path.Combine(repoRoot, "dist", "lib", "libcx_arrow.dylib"));
                    candidates.Add(Path.Combine(repoRoot, "dist", "lib", "libcx_arrow.so"));
                }
                catch { /* ignore */ }

                foreach (var p in candidates)
                    if (File.Exists(p) && NativeLibrary.TryLoad(p, out var h)) return h;
                throw new DllNotFoundException(
                    "libcx_arrow not found. Build with `make build-lib-arrow` or set LIBCX_ARROW_PATH.");
            });
    }

    private static string FindRepoRoot(string start)
    {
        var dir = new DirectoryInfo(start);
        while (dir != null)
        {
            if (Directory.Exists(Path.Combine(dir.FullName, "vcx"))) return dir.FullName;
            dir = dir.Parent;
        }
        throw new DirectoryNotFoundException("Cannot locate repo root from " + start);
    }

    // ── native ABI ────────────────────────────────────────────────────────────

    [DllImport(Lib, EntryPoint = "cx_arrow_features")]
    private static extern IntPtr NativeArrowFeatures();

    [DllImport(Lib, EntryPoint = "cx_arrow_version")]
    private static extern IntPtr NativeArrowVersion();

    [DllImport(Lib, EntryPoint = "cx_arrow_free")]
    private static extern void NativeArrowFree(IntPtr p);

    [DllImport(Lib, EntryPoint = "cx_arrow_export_open")]
    private static extern IntPtr NativeExportOpen(byte[] dataBin, IntPtr stream, out IntPtr err);

    [DllImport(Lib, EntryPoint = "cx_arrow_import_to_data_bin")]
    private static extern IntPtr NativeImportToDataBin(IntPtr stream, out IntPtr err);

    // ── helpers ───────────────────────────────────────────────────────────────

    private static ulong ParseHexBitmask(string s)
    {
        if (s.StartsWith("0x") || s.StartsWith("0X")) s = s.Substring(2);
        return ulong.TryParse(s, System.Globalization.NumberStyles.HexNumber,
            System.Globalization.CultureInfo.InvariantCulture, out var v) ? v : 0UL;
    }

    private static string TakeError(IntPtr errPtr, string fallback)
    {
        if (errPtr == IntPtr.Zero) return fallback;
        string msg = Marshal.PtrToStringUTF8(errPtr) ?? fallback;
        NativeArrowFree(errPtr);
        return msg;
    }

    private static byte[] FrameForC(byte[] payload)
    {
        var framed = new byte[4 + payload.Length];
        uint sz = (uint)payload.Length;
        framed[0] = (byte)(sz & 0xFF);
        framed[1] = (byte)((sz >> 8) & 0xFF);
        framed[2] = (byte)((sz >> 16) & 0xFF);
        framed[3] = (byte)((sz >> 24) & 0xFF);
        Buffer.BlockCopy(payload, 0, framed, 4, payload.Length);
        return framed;
    }

    // ── public API ────────────────────────────────────────────────────────────

    /// <summary>
    /// True iff the Arrow bridge is reachable (libcx_arrow links and answers
    /// <c>cx_arrow_features</c>). Mirrors Python's <c>cxlib.arrow.available</c>.
    /// </summary>
    public static bool Available
    {
        get
        {
            try { return Features() != 0UL; }
            catch { return false; }
        }
    }

    /// <summary>
    /// libcx_arrow capability bitmask (spec/abi.md §2.11). Currently always
    /// 0x800000 (bit 23) when libcx_arrow loads.
    /// </summary>
    public static ulong Features()
    {
        var p = NativeArrowFeatures();
        if (p == IntPtr.Zero) return 0UL;
        string s = Marshal.PtrToStringUTF8(p) ?? "";
        NativeArrowFree(p);
        return ParseHexBitmask(s);
    }

    /// <summary>libcx_arrow build version string.</summary>
    public static string Version()
    {
        var p = NativeArrowVersion();
        if (p == IntPtr.Zero) return "";
        string s = Marshal.PtrToStringUTF8(p) ?? "";
        NativeArrowFree(p);
        return s;
    }

    /// <summary>
    /// Bitwise OR of libcx and libcx_arrow capability bitmasks. Mirrors
    /// Python's <c>cxlib.arrow.merged_features()</c>.
    /// </summary>
    public static ulong MergedFeatures() => CxLib.Features() | Features();

    /// <summary>
    /// Decode UNFRAMED CXDB chunked-table bytes as an Arrow record-batch
    /// reader. Ownership of the underlying <c>ArrowArrayStream</c> callbacks
    /// moves into the returned reader, which releases them on
    /// <c>Dispose()</c>. Caller must release <c>payload</c> only after
    /// disposing the reader, but cxlib copies the input into a stream-owned
    /// buffer on the V side, so the caller may release immediately.
    /// </summary>
    public static IArrowArrayStream Export(ReadOnlySpan<byte> payload)
    {
        if (payload.Length == 0)
            throw new ArgumentException("CxArrow.Export: empty input");
        byte[] framed = FrameForC(payload.ToArray());

        unsafe
        {
            CArrowArrayStream* stream = CArrowArrayStream.Create();
            IntPtr streamPtr = (IntPtr)stream;
            try
            {
                NativeExportOpen(framed, streamPtr, out IntPtr errPtr);
                if (errPtr != IntPtr.Zero)
                {
                    string msg = TakeError(errPtr, "cx_arrow_export_open: unknown error");
                    throw new InvalidOperationException(msg);
                }
                // ImportArrayStream takes ownership of the C struct's
                // callbacks via C-Data move semantics. The wrapper Releases
                // and the caller must Free the empty struct after Dispose.
                IArrowArrayStream reader = CArrowArrayStreamImporter.ImportArrayStream(stream);
                return new OwnedStreamReader(reader, stream);
            }
            catch
            {
                CArrowArrayStream.Free(stream);
                throw;
            }
        }
    }

    /// <summary>
    /// Drain an Arrow <see cref="IArrowArrayStream"/> into UNFRAMED CXDB
    /// chunked-table bytes. The reader is consumed; its callbacks are
    /// released by libcx via the moved <c>ArrowArrayStream</c>.
    /// </summary>
    public static byte[] ImportToDataBin(IArrowArrayStream reader)
    {
        if (reader == null) throw new ArgumentNullException(nameof(reader));

        unsafe
        {
            CArrowArrayStream* stream = CArrowArrayStream.Create();
            IntPtr streamPtr = (IntPtr)stream;
            try
            {
                CArrowArrayStreamExporter.ExportArrayStream(reader, stream);
                IntPtr addr = NativeImportToDataBin(streamPtr, out IntPtr errPtr);
                if (addr == IntPtr.Zero)
                {
                    string msg = TakeError(errPtr, "cx_arrow_import_to_data_bin: unknown error");
                    throw new InvalidOperationException(msg);
                }

                // [u32 LE size][payload]; convention is UNFRAMED out.
                uint size = (uint)(
                    Marshal.ReadByte(addr, 0)
                    | (Marshal.ReadByte(addr, 1) << 8)
                    | (Marshal.ReadByte(addr, 2) << 16)
                    | (Marshal.ReadByte(addr, 3) << 24));
                var payload = new byte[size];
                if (size > 0) Marshal.Copy(addr + 4, payload, 0, (int)size);
                NativeArrowFree(addr);
                return payload;
            }
            finally
            {
                // libcx_arrow consumed the stream's callbacks; the empty
                // C struct can now be freed unconditionally.
                CArrowArrayStream.Free(stream);
            }
        }
    }

    /// <summary>
    /// Wraps the Apache.Arrow.C-imported <see cref="IArrowArrayStream"/>
    /// together with the unmanaged <c>CArrowArrayStream</c> struct it owns,
    /// so that <see cref="Dispose"/> both releases the imported reader and
    /// frees the heap-allocated C struct.
    /// </summary>
    private sealed unsafe class OwnedStreamReader : IArrowArrayStream
    {
        private readonly IArrowArrayStream _inner;
        private CArrowArrayStream* _stream;
        private bool _disposed;

        public OwnedStreamReader(IArrowArrayStream inner, CArrowArrayStream* stream)
        {
            _inner = inner;
            _stream = stream;
        }

        public Apache.Arrow.Schema Schema => _inner.Schema;

        public System.Threading.Tasks.ValueTask<Apache.Arrow.RecordBatch?> ReadNextRecordBatchAsync(
            System.Threading.CancellationToken cancellationToken = default)
            => _inner.ReadNextRecordBatchAsync(cancellationToken);

        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;
            try { _inner.Dispose(); }
            finally
            {
                if (_stream != null)
                {
                    CArrowArrayStream.Free(_stream);
                    _stream = null;
                }
            }
        }
    }
}
