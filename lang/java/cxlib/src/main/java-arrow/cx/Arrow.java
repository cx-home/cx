package cx;

import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.ptr.PointerByReference;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

import org.apache.arrow.c.ArrowArrayStream;
import org.apache.arrow.c.Data;
import org.apache.arrow.memory.BufferAllocator;
import org.apache.arrow.memory.RootAllocator;
import org.apache.arrow.vector.ipc.ArrowReader;

/**
 * Apache Arrow C-Data interop for cxlib (Phase 7.74c-cont-bindings-multi-java).
 *
 * <p>Bridges CXDB chunked-tables to Arrow {@code ArrowArrayStream} via
 * libcx_arrow (spec/abi.md §2.11, ADR 0015 D9, capability bit 0x800000).
 * The bridge handles the v0.6.0 column-type set: {@code int / i8 / i16 / i32
 * / float / bool / string / date / bytes / datetime} (timestamp[ns, UTC]).
 * {@code decimal / dictionary} remain deferred and surface the V core's
 * deferred-type error.
 *
 * <p>This source is opt-in: it lives under {@code src/main/java-arrow}
 * and is compiled only with the {@code arrow} Maven profile
 * ({@code mvn -Parrow ...}). The default {@code mvn package} build does
 * not require {@code arrow-c-data} or {@code libcx_arrow}. Mirrors
 * Python's {@code pip install cxlib[arrow]}, Go's {@code -tags arrow},
 * Rust's {@code --features arrow}, and C#'s separate
 * {@code CXLib.Arrow.dll} assembly.
 */
public final class Arrow {

    private Arrow() {}

    // ── native ABI ────────────────────────────────────────────────────────────

    /** Mirrors the libcx_arrow C ABI declared in include/cx.h §2.11. */
    interface ArrowLib extends Library {
        Pointer cx_arrow_features();
        Pointer cx_arrow_version();
        void    cx_arrow_free(Pointer p);
        // C signature: (const char* data_bin, void* arrow_array_stream_out, char** err_out)
        // Return value is a non-null status sentinel (we ignore it; errors flow through err_out).
        Pointer cx_arrow_export_open      (byte[] data_bin, Pointer arrow_array_stream_out,
                                           PointerByReference err_out);
        // Returns a malloc'd [u32 LE size][payload] buffer (or NULL on error).
        Pointer cx_arrow_import_to_data_bin(Pointer arrow_array_stream_in,
                                            PointerByReference err_out);
    }

    private static final ArrowLib LIB;
    private static final BufferAllocator ALLOCATOR = new RootAllocator();

    static {
        String os   = System.getProperty("os.name", "").toLowerCase();
        String name = os.contains("mac") ? "libcx_arrow.dylib" : "libcx_arrow.so";
        List<String> candidates = new ArrayList<>();

        String envPath = System.getenv("LIBCX_ARROW_PATH");
        if (envPath != null) candidates.add(envPath);

        String envDir = System.getenv("LIBCX_LIB_DIR");
        if (envDir != null) candidates.add(envDir + "/" + name);

        for (String dir : new String[]{"/usr/local/lib", "/opt/homebrew/lib", "/usr/lib",
                                       "/usr/lib/x86_64-linux-gnu", "/usr/lib/aarch64-linux-gnu"}) {
            candidates.add(dir + "/" + name);
        }

        try {
            Path base = Paths.get(Arrow.class.getProtectionDomain()
                    .getCodeSource().getLocation().toURI());
            Path repo = base.getParent().getParent().getParent().getParent().getParent();
            candidates.add(repo.resolve("vcx/target/" + name).toString());
            candidates.add(repo.resolve("dist/lib/"   + name).toString());
        } catch (Exception ignored) {}

        String found = candidates.stream()
                .filter(p -> Files.exists(Paths.get(p)))
                .findFirst()
                .orElseThrow(() -> new RuntimeException(
                        "libcx_arrow not found. Build with `make build-lib-arrow` "
                                + "or set LIBCX_ARROW_PATH."));
        LIB = Native.load(found, ArrowLib.class);
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    private static long parseHexBitmask(String s) {
        if (s == null) return 0L;
        if (s.startsWith("0x") || s.startsWith("0X")) s = s.substring(2);
        try { return Long.parseUnsignedLong(s, 16); }
        catch (NumberFormatException e) { return 0L; }
    }

    private static String takeError(PointerByReference errRef, String fallback) {
        Pointer ep = errRef.getValue();
        if (ep == null) return fallback;
        String msg = ep.getString(0);
        LIB.cx_arrow_free(ep);
        return (msg == null || msg.isEmpty()) ? fallback : msg;
    }

    // ── public API ────────────────────────────────────────────────────────────

    /**
     * The shared {@link RootAllocator} the binding uses for all
     * {@link ArrowArrayStream} allocations. Tests and callers building
     * their own readers/vectors should reuse this allocator so that
     * cross-allocator transfers do not occur on the C-Data boundary.
     */
    public static BufferAllocator allocator() { return ALLOCATOR; }

    /** True iff libcx_arrow links and answers {@code cx_arrow_features}. */
    public static boolean available() {
        try { return features() != 0L; }
        catch (Throwable t) { return false; }
    }

    /**
     * libcx_arrow capability bitmask (spec/abi.md §2.11). Currently
     * always {@code 0x800000} (bit 23) when libcx_arrow loads.
     */
    public static long features() {
        Pointer p = LIB.cx_arrow_features();
        if (p == null) return 0L;
        String s = p.getString(0);
        LIB.cx_arrow_free(p);
        return parseHexBitmask(s);
    }

    /** libcx_arrow build version string. */
    public static String version() {
        Pointer p = LIB.cx_arrow_version();
        if (p == null) return "";
        String s = p.getString(0);
        LIB.cx_arrow_free(p);
        return s == null ? "" : s;
    }

    /**
     * Bitwise OR of libcx and libcx_arrow capability bitmasks. Mirrors
     * Python's {@code cxlib.arrow.merged_features()}, Go's
     * {@code ArrowMergedFeatures}, and C#'s
     * {@code CxArrow.MergedFeatures}.
     */
    public static long mergedFeatures() {
        return CxLib.features() | features();
    }

    /**
     * Decode FRAMED CXDB chunked-table bytes as an Arrow record-batch
     * reader. {@code framed} must be the {@code [u32 LE size][payload]}
     * buffer produced by {@link CxLib#toDataBinChunked} (or any other
     * libcx producer of CXDB chunked-table bytes). The returned
     * {@link ArrowReader} owns the underlying {@code ArrowArrayStream};
     * closing the reader releases the stream (libcx-managed buffers go
     * away at that point).
     *
     * <p>Memory: cxlib copies the input into a stream-owned buffer on
     * the V side, so the caller may release {@code framed} immediately
     * after this call returns.
     */
    public static ArrowReader export(byte[] framed) {
        if (framed == null || framed.length == 0) {
            throw new IllegalArgumentException("Arrow.export: empty input");
        }
        if (framed.length < 4) {
            throw new IllegalArgumentException(
                    "Arrow.export: input too short to contain a [u32 LE size] header");
        }
        int sizeHeader = ByteBuffer.wrap(framed, 0, 4).order(ByteOrder.LITTLE_ENDIAN).getInt();
        if (sizeHeader != framed.length - 4) {
            throw new IllegalArgumentException(
                    "Arrow.export: size header (" + sizeHeader
                            + ") does not match payload length (" + (framed.length - 4) + ")");
        }
        ArrowArrayStream stream = ArrowArrayStream.allocateNew(ALLOCATOR);
        try {
            PointerByReference errRef = new PointerByReference();
            LIB.cx_arrow_export_open(framed, new Pointer(stream.memoryAddress()), errRef);
            if (errRef.getValue() != null) {
                String msg = takeError(errRef, "cx_arrow_export_open: unknown error");
                throw new RuntimeException(msg);
            }
            // Data.importArrayStream takes ownership of the stream's
            // contents; the returned reader's close() releases the C
            // struct via the imported callbacks.
            return Data.importArrayStream(ALLOCATOR, stream);
        } catch (RuntimeException e) {
            try { stream.close(); } catch (Exception ignored) {}
            throw e;
        }
    }

    /**
     * Drain an Arrow {@link ArrowReader} into FRAMED CXDB chunked-table
     * bytes ({@code [u32 LE size][payload]}, the same shape
     * {@link CxLib#toDataBinChunked} returns). The reader is consumed;
     * its callbacks are released by libcx via the moved
     * {@code ArrowArrayStream}.
     */
    public static byte[] importToDataBin(ArrowReader reader) {
        if (reader == null) {
            throw new IllegalArgumentException("Arrow.importToDataBin: null reader");
        }
        ArrowArrayStream stream = ArrowArrayStream.allocateNew(ALLOCATOR);
        try {
            Data.exportArrayStream(ALLOCATOR, reader, stream);
            PointerByReference errRef = new PointerByReference();
            Pointer out = LIB.cx_arrow_import_to_data_bin(
                    new Pointer(stream.memoryAddress()), errRef);
            if (out == null) {
                String msg = takeError(errRef, "cx_arrow_import_to_data_bin: unknown error");
                throw new RuntimeException(msg);
            }
            byte[] sizeBytes = out.getByteArray(0, 4);
            int size = ByteBuffer.wrap(sizeBytes).order(ByteOrder.LITTLE_ENDIAN).getInt();
            byte[] framed = out.getByteArray(0, 4 + size);
            LIB.cx_arrow_free(out);
            return framed;
        } finally {
            try { stream.close(); } catch (Exception ignored) {}
        }
    }
}
