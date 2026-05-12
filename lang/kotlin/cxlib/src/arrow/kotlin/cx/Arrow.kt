package cx

import com.sun.jna.Library
import com.sun.jna.Native
import com.sun.jna.Pointer
import com.sun.jna.ptr.PointerByReference
import org.apache.arrow.c.ArrowArrayStream
import org.apache.arrow.c.Data
import org.apache.arrow.memory.BufferAllocator
import org.apache.arrow.memory.RootAllocator
import org.apache.arrow.vector.ipc.ArrowReader
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.file.Files
import java.nio.file.Paths

/**
 * Apache Arrow C-Data interop for cxlib (Phase 7.74c-cont-bindings-multi-kotlin).
 *
 * Bridges CXDB chunked-tables to Arrow `ArrowArrayStream` via libcx_arrow
 * (spec/abi.md §2.11, ADR 0015 D9, capability bit 0x800000). The bridge
 * handles the v0.6.0 column-type set: `int / i8 / i16 / i32 / float /
 * bool / string / date / bytes / datetime` (timestamp[ns, UTC]).
 * `decimal / dictionary` remain deferred and surface the V core's
 * deferred-type error.
 *
 * This source-set is opt-in: it lives under `src/arrow/kotlin` and is
 * compiled only when invoking the `compileArrowKotlin` / `arrowTest`
 * Gradle tasks. The default `gradle assemble` / `gradle test` build
 * does not require `arrow-c-data` or `libcx_arrow`. Mirrors Python's
 * `pip install cxlib[arrow]`, Go's `-tags arrow`, Rust's
 * `--features arrow`, C#'s separate `CXLib.Arrow.dll` assembly, and
 * Java's `-Parrow` Maven profile.
 */
object Arrow {

    /** Mirrors the libcx_arrow C ABI declared in include/cx.h §2.11. */
    interface ArrowLib : Library {
        fun cx_arrow_features(): Pointer?
        fun cx_arrow_version(): Pointer?
        fun cx_arrow_free(p: Pointer?)
        // (const char* data_bin, void* arrow_array_stream_out, char** err_out)
        fun cx_arrow_export_open(
            dataBin: ByteArray,
            arrowArrayStreamOut: Pointer,
            errOut: PointerByReference
        ): Pointer?
        // Returns a malloc'd [u32 LE size][payload] buffer (or NULL on error).
        fun cx_arrow_import_to_data_bin(
            arrowArrayStreamIn: Pointer,
            errOut: PointerByReference
        ): Pointer?
    }

    private val LIB: ArrowLib
    private val ALLOCATOR: BufferAllocator = RootAllocator()

    init {
        val os = System.getProperty("os.name", "").lowercase()
        val name = if (os.contains("mac")) "libcx_arrow.dylib" else "libcx_arrow.so"
        val candidates = mutableListOf<String>()

        System.getenv("LIBCX_ARROW_PATH")?.let(candidates::add)
        System.getenv("LIBCX_LIB_DIR")?.let { candidates.add("$it/$name") }

        for (dir in listOf(
            "/usr/local/lib", "/opt/homebrew/lib", "/usr/lib",
            "/usr/lib/x86_64-linux-gnu", "/usr/lib/aarch64-linux-gnu"
        )) {
            candidates.add("$dir/$name")
        }

        try {
            val base = Paths.get(Arrow::class.java.protectionDomain.codeSource.location.toURI())
            // build/classes/kotlin/arrow → repo root is 7 levels up
            // (build / classes / kotlin / arrow / cxlib / kotlin / lang / repo).
            // Walk up until we find a directory containing `vcx`.
            var dir = base
            repeat(10) {
                val parent = dir.parent ?: return@repeat
                dir = parent
                if (Files.exists(dir.resolve("vcx"))) {
                    candidates.add(dir.resolve("vcx/target/$name").toString())
                    candidates.add(dir.resolve("dist/lib/$name").toString())
                    return@repeat
                }
            }
        } catch (_: Exception) {}

        val found = candidates.firstOrNull { Files.exists(Paths.get(it)) }
            ?: throw RuntimeException(
                "libcx_arrow not found. Build with `make build-lib-arrow` or set LIBCX_ARROW_PATH."
            )
        LIB = Native.load(found, ArrowLib::class.java)
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    private fun parseHexBitmask(s: String?): Long {
        if (s == null) return 0L
        val str = if (s.startsWith("0x") || s.startsWith("0X")) s.substring(2) else s
        return try { java.lang.Long.parseUnsignedLong(str, 16) }
               catch (_: NumberFormatException) { 0L }
    }

    private fun takeError(errRef: PointerByReference, fallback: String): String {
        val ep = errRef.value ?: return fallback
        val msg = ep.getString(0)
        LIB.cx_arrow_free(ep)
        return if (msg.isNullOrEmpty()) fallback else msg
    }

    // ── public API ────────────────────────────────────────────────────────────

    /**
     * The shared [RootAllocator] the binding uses for all
     * [ArrowArrayStream] allocations. Tests and callers building their
     * own readers/vectors should reuse this allocator so that
     * cross-allocator transfers do not occur on the C-Data boundary.
     */
    fun allocator(): BufferAllocator = ALLOCATOR

    /** True iff libcx_arrow links and answers `cx_arrow_features`. */
    fun available(): Boolean =
        try { features() != 0L } catch (_: Throwable) { false }

    /**
     * libcx_arrow capability bitmask (spec/abi.md §2.11). Currently
     * always `0x800000` (bit 23) when libcx_arrow loads.
     */
    fun features(): Long {
        val p = LIB.cx_arrow_features() ?: return 0L
        val s = p.getString(0)
        LIB.cx_arrow_free(p)
        return parseHexBitmask(s)
    }

    /** libcx_arrow build version string. */
    fun version(): String {
        val p = LIB.cx_arrow_version() ?: return ""
        val s = p.getString(0) ?: ""
        LIB.cx_arrow_free(p)
        return s
    }

    /**
     * Bitwise OR of libcx and libcx_arrow capability bitmasks. Mirrors
     * Python's `cxlib.arrow.merged_features()`, Go's `ArrowMergedFeatures`,
     * C#'s `CxArrow.MergedFeatures`, and Java's `Arrow.mergedFeatures`.
     */
    fun mergedFeatures(): Long = CxLib.features() or features()

    /**
     * Decode FRAMED CXDB chunked-table bytes as an Arrow record-batch
     * reader. [framed] must be the `[u32 LE size][payload]` buffer
     * produced by [CxLib.toDataBinChunked] (or any other libcx producer
     * of CXDB chunked-table bytes). The returned [ArrowReader] owns the
     * underlying [ArrowArrayStream]; closing the reader releases the
     * stream (libcx-managed buffers go away at that point).
     *
     * Memory: cxlib copies the input into a stream-owned buffer on the
     * V side, so the caller may release [framed] immediately after this
     * call returns.
     */
    fun export(framed: ByteArray): ArrowReader {
        require(framed.isNotEmpty()) { "Arrow.export: empty input" }
        require(framed.size >= 4) {
            "Arrow.export: input too short to contain a [u32 LE size] header"
        }
        val sizeHeader = ByteBuffer.wrap(framed, 0, 4).order(ByteOrder.LITTLE_ENDIAN).int
        require(sizeHeader == framed.size - 4) {
            "Arrow.export: size header ($sizeHeader) does not match payload length (${framed.size - 4})"
        }
        val stream = ArrowArrayStream.allocateNew(ALLOCATOR)
        try {
            val errRef = PointerByReference()
            LIB.cx_arrow_export_open(framed, Pointer(stream.memoryAddress()), errRef)
            if (errRef.value != null) {
                throw RuntimeException(takeError(errRef, "cx_arrow_export_open: unknown error"))
            }
            // Data.importArrayStream takes ownership of the stream's
            // contents; the returned reader's close() releases the C
            // struct via the imported callbacks.
            return Data.importArrayStream(ALLOCATOR, stream)
        } catch (e: RuntimeException) {
            try { stream.close() } catch (_: Exception) {}
            throw e
        }
    }

    /**
     * Drain an Arrow [ArrowReader] into FRAMED CXDB chunked-table bytes
     * (`[u32 LE size][payload]`, the same shape [CxLib.toDataBinChunked]
     * returns). The reader is consumed; its callbacks are released by
     * libcx via the moved [ArrowArrayStream].
     */
    fun importToDataBin(reader: ArrowReader?): ByteArray {
        requireNotNull(reader) { "Arrow.importToDataBin: null reader" }
        val stream = ArrowArrayStream.allocateNew(ALLOCATOR)
        try {
            Data.exportArrayStream(ALLOCATOR, reader, stream)
            val errRef = PointerByReference()
            val out = LIB.cx_arrow_import_to_data_bin(Pointer(stream.memoryAddress()), errRef)
                ?: throw RuntimeException(
                    takeError(errRef, "cx_arrow_import_to_data_bin: unknown error")
                )
            val sizeBytes = out.getByteArray(0, 4)
            val size = ByteBuffer.wrap(sizeBytes).order(ByteOrder.LITTLE_ENDIAN).int
            val framed = out.getByteArray(0, 4 + size)
            LIB.cx_arrow_free(out)
            return framed
        } finally {
            try { stream.close() } catch (_: Exception) {}
        }
    }
}
