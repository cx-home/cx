package cx

import com.sun.jna.*
import com.sun.jna.ptr.PointerByReference
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths

/**
 * CX Kotlin binding — JNA wrapper around libcx.
 */
object CxLib {

    /** JNA native interface mirroring cx.h */
    interface NativeLib : Library {
        // Thread-init handshake (spec/abi.md §1.5.5, capability bit 26).
        // Mandatory-for-all-bindings; called once at module-load time.
        fun cx_init(): Int
        fun cx_free(s: Pointer)
        fun cx_version(): Pointer
        fun cx_features(): Pointer

        // Binary output (returns length-prefixed buffer)
        fun cx_to_ast_bin   (input: String, errOut: PointerByReference): Pointer?
        fun cx_to_events_bin(input: String, errOut: PointerByReference): Pointer?
        fun cx_to_data_bin  (input: String, errOut: PointerByReference): Pointer?

        // CXDB framed bytes in, canonical CX text out.
        fun cx_from_data_bin(input: ByteArray, errOut: PointerByReference): Pointer?

        // data_bin one-shot loaders/dumpers (Phase 7.28; spec/abi.md §2.4–§2.5).
        fun cx_xml_to_data_bin (input: String, errOut: PointerByReference): Pointer?
        fun cx_json_to_data_bin(input: String, errOut: PointerByReference): Pointer?
        fun cx_yaml_to_data_bin(input: String, errOut: PointerByReference): Pointer?
        fun cx_toml_to_data_bin(input: String, errOut: PointerByReference): Pointer?
        fun cx_md_to_data_bin  (input: String, errOut: PointerByReference): Pointer?

        fun cx_data_bin_to_xml (input: ByteArray, errOut: PointerByReference): Pointer?
        fun cx_data_bin_to_json(input: ByteArray, errOut: PointerByReference): Pointer?
        fun cx_data_bin_to_yaml(input: ByteArray, errOut: PointerByReference): Pointer?
        fun cx_data_bin_to_toml(input: ByteArray, errOut: PointerByReference): Pointer?
        fun cx_data_bin_to_md  (input: ByteArray, errOut: PointerByReference): Pointer?

        // CXPath path-tracking C ABI (Phase 4 / CB-5).
        fun cx_select_all_paths(input: String, expr: String, errOut: PointerByReference): Pointer?

        // Phase 5 / CB-1 — ast_bin → text format.
        fun cx_ast_bin_to_cx  (input: ByteArray, errOut: PointerByReference): Pointer?
        fun cx_ast_bin_to_xml (input: ByteArray, errOut: PointerByReference): Pointer?
        fun cx_ast_bin_to_json(input: ByteArray, errOut: PointerByReference): Pointer?
        fun cx_ast_bin_to_yaml(input: ByteArray, errOut: PointerByReference): Pointer?
        fun cx_ast_bin_to_toml(input: ByteArray, errOut: PointerByReference): Pointer?
        fun cx_ast_bin_to_md  (input: ByteArray, errOut: PointerByReference): Pointer?

        // Phase 5 / CB-2 — text → ast_bin (returns framed binary).
        fun cx_xml_to_ast_bin (input: String, errOut: PointerByReference): Pointer?
        fun cx_json_to_ast_bin(input: String, errOut: PointerByReference): Pointer?
        fun cx_yaml_to_ast_bin(input: String, errOut: PointerByReference): Pointer?
        fun cx_toml_to_ast_bin(input: String, errOut: PointerByReference): Pointer?
        fun cx_md_to_ast_bin  (input: String, errOut: PointerByReference): Pointer?

        // Phase 5 / CB-4 — events handle API.
        fun cx_events_open (input: String, errOut: PointerByReference): Pointer?
        fun cx_events_next (handle: Pointer, errOut: PointerByReference): Pointer?
        fun cx_events_close(handle: Pointer)

        // Phase 6 — canonical-form tooling (spec/abi.md §2.6).
        fun cx_fmt      (input: String, errOut: PointerByReference): Pointer?
        fun cx_canonical(input: String, errOut: PointerByReference): Pointer?
        fun cx_hash     (input: String, errOut: PointerByReference): Pointer?
        fun cx_eq       (a: String, b: String, errOut: PointerByReference): Pointer?

        // Phase 7.47 — cx diff (ADR 0012). format = "unified" | "json" | "summary".
        fun cx_diff     (a: String, b: String, format: String, errOut: PointerByReference): Pointer?

        // Phase 7.49 — cx lint (ADR 0013). format = "text" | "json" | "summary".
        fun cx_lint     (input: String, format: String, disabled: String, errOut: PointerByReference): Pointer?

        // Phase 7.65 — ID/IDREF C ABI (ADR 0003).
        fun cx_id_lookup  (input: String, id: String,     errOut: PointerByReference): Pointer?
        fun cx_resolve_ref(input: String, ref: String,    errOut: PointerByReference): Pointer?
        fun cx_node_id    (input: String, cxpath: String, errOut: PointerByReference): Pointer?

        // Phase 7.68 — Delimited (CSV/TSV/PSV/arbitrary) C ABI (ADR 0001).
        fun cx_to_delimited  (input: String, delim: Byte, errOut: PointerByReference): Pointer?
        fun cx_from_delimited(input: String, delim: Byte, errOut: PointerByReference): Pointer?
        fun cx_to_csv  (input: String, errOut: PointerByReference): Pointer?
        fun cx_from_csv(input: String, errOut: PointerByReference): Pointer?
        fun cx_to_tsv  (input: String, errOut: PointerByReference): Pointer?
        fun cx_from_tsv(input: String, errOut: PointerByReference): Pointer?
        fun cx_to_psv  (input: String, errOut: PointerByReference): Pointer?
        fun cx_from_psv(input: String, errOut: PointerByReference): Pointer?

        fun cx_csv_to_data_bin(input: String, errOut: PointerByReference): Pointer?
        fun cx_tsv_to_data_bin(input: String, errOut: PointerByReference): Pointer?
        fun cx_psv_to_data_bin(input: String, errOut: PointerByReference): Pointer?
        fun cx_data_bin_to_csv(input: ByteArray, errOut: PointerByReference): Pointer?
        fun cx_data_bin_to_tsv(input: ByteArray, errOut: PointerByReference): Pointer?
        fun cx_data_bin_to_psv(input: ByteArray, errOut: PointerByReference): Pointer?

        // Phase 7.72 — chunked-table one-shot (spec/abi.md §2.10, ADR 0015 D8).
        fun cx_to_data_bin_chunked(input: String, errOut: PointerByReference): Pointer?

        // Phase 7.74a — streaming Table reader / writer (spec/abi.md §2.10).
        fun cx_table_reader_open    (dataBin: ByteArray,                errOut: PointerByReference): Pointer?
        fun cx_table_reader_open_fd (fd: Int,                            errOut: PointerByReference): Pointer?
        fun cx_table_reader_schema  (handle: Pointer,                    errOut: PointerByReference): Pointer?
        fun cx_table_reader_next    (handle: Pointer,                    errOut: PointerByReference): Pointer?
        fun cx_table_reader_close   (handle: Pointer)

        fun cx_table_writer_open            (colSpecPayload: ByteArray,           errOut: PointerByReference): Pointer?
        fun cx_table_writer_open_fd         (colSpecPayload: ByteArray, fd: Int,  errOut: PointerByReference): Pointer?
        fun cx_table_writer_emit_row_group  (handle: Pointer, payload: ByteArray, errOut: PointerByReference): Pointer?
        fun cx_table_writer_close_get_bytes (handle: Pointer,                     errOut: PointerByReference): Pointer?
        fun cx_table_writer_close           (handle: Pointer)

        // Phase 7.73 — schema-driven CXDB encoding (spec/abi.md §2.12, ADR 0015 D3).
        fun cx_to_data_bin_schema_driven      (input: String, schema: String, refForm: Int, nameHint: String, errOut: PointerByReference): Pointer?
        fun cx_xml_to_data_bin_schema_driven  (input: String, schema: String, refForm: Int, nameHint: String, errOut: PointerByReference): Pointer?
        fun cx_json_to_data_bin_schema_driven (input: String, schema: String, refForm: Int, nameHint: String, errOut: PointerByReference): Pointer?
        fun cx_yaml_to_data_bin_schema_driven (input: String, schema: String, refForm: Int, nameHint: String, errOut: PointerByReference): Pointer?
        fun cx_toml_to_data_bin_schema_driven (input: String, schema: String, refForm: Int, nameHint: String, errOut: PointerByReference): Pointer?
        fun cx_md_to_data_bin_schema_driven   (input: String, schema: String, refForm: Int, nameHint: String, errOut: PointerByReference): Pointer?
        fun cx_csv_to_data_bin_schema_driven  (input: String, schema: String, refForm: Int, nameHint: String, errOut: PointerByReference): Pointer?
        fun cx_tsv_to_data_bin_schema_driven  (input: String, schema: String, refForm: Int, nameHint: String, errOut: PointerByReference): Pointer?
        fun cx_psv_to_data_bin_schema_driven  (input: String, schema: String, refForm: Int, nameHint: String, errOut: PointerByReference): Pointer?
        fun cx_from_data_bin_schema_driven    (dataBin: ByteArray, schemaHint: String,                          errOut: PointerByReference): Pointer?

        // CX input
        fun cx_to_cx          (input: String, errOut: PointerByReference): Pointer?
        fun cx_to_cx_compact  (input: String, errOut: PointerByReference): Pointer?
        fun cx_ast_to_cx      (input: String, errOut: PointerByReference): Pointer?
        fun cx_to_xml  (input: String, errOut: PointerByReference): Pointer?
        fun cx_to_ast  (input: String, errOut: PointerByReference): Pointer?
        fun cx_to_json (input: String, errOut: PointerByReference): Pointer?
        fun cx_to_yaml (input: String, errOut: PointerByReference): Pointer?
        fun cx_to_toml (input: String, errOut: PointerByReference): Pointer?
        fun cx_to_md   (input: String, errOut: PointerByReference): Pointer?

        // CXL evaluator (capability bit 28; spec/eval.md)
        fun cx_eval_cxl(input: String, program: String, outputTarget: String, errOut: PointerByReference): Pointer?

        // XML input
        fun cx_xml_to_cx   (input: String, errOut: PointerByReference): Pointer?
        fun cx_xml_to_xml  (input: String, errOut: PointerByReference): Pointer?
        fun cx_xml_to_ast  (input: String, errOut: PointerByReference): Pointer?
        fun cx_xml_to_json (input: String, errOut: PointerByReference): Pointer?
        fun cx_xml_to_yaml (input: String, errOut: PointerByReference): Pointer?
        fun cx_xml_to_toml (input: String, errOut: PointerByReference): Pointer?
        fun cx_xml_to_md   (input: String, errOut: PointerByReference): Pointer?

        // JSON input
        fun cx_json_to_cx   (input: String, errOut: PointerByReference): Pointer?
        fun cx_json_to_xml  (input: String, errOut: PointerByReference): Pointer?
        fun cx_json_to_ast  (input: String, errOut: PointerByReference): Pointer?
        fun cx_json_to_json (input: String, errOut: PointerByReference): Pointer?
        fun cx_json_to_yaml (input: String, errOut: PointerByReference): Pointer?
        fun cx_json_to_toml (input: String, errOut: PointerByReference): Pointer?
        fun cx_json_to_md   (input: String, errOut: PointerByReference): Pointer?

        // YAML input
        fun cx_yaml_to_cx   (input: String, errOut: PointerByReference): Pointer?
        fun cx_yaml_to_xml  (input: String, errOut: PointerByReference): Pointer?
        fun cx_yaml_to_ast  (input: String, errOut: PointerByReference): Pointer?
        fun cx_yaml_to_json (input: String, errOut: PointerByReference): Pointer?
        fun cx_yaml_to_yaml (input: String, errOut: PointerByReference): Pointer?
        fun cx_yaml_to_toml (input: String, errOut: PointerByReference): Pointer?
        fun cx_yaml_to_md   (input: String, errOut: PointerByReference): Pointer?

        // TOML input
        fun cx_toml_to_cx   (input: String, errOut: PointerByReference): Pointer?
        fun cx_toml_to_xml  (input: String, errOut: PointerByReference): Pointer?
        fun cx_toml_to_ast  (input: String, errOut: PointerByReference): Pointer?
        fun cx_toml_to_json (input: String, errOut: PointerByReference): Pointer?
        fun cx_toml_to_yaml (input: String, errOut: PointerByReference): Pointer?
        fun cx_toml_to_toml (input: String, errOut: PointerByReference): Pointer?
        fun cx_toml_to_md   (input: String, errOut: PointerByReference): Pointer?

        // MD input
        fun cx_md_to_cx   (input: String, errOut: PointerByReference): Pointer?
        fun cx_md_to_xml  (input: String, errOut: PointerByReference): Pointer?
        fun cx_md_to_ast  (input: String, errOut: PointerByReference): Pointer?
        fun cx_md_to_json (input: String, errOut: PointerByReference): Pointer?
        fun cx_md_to_yaml (input: String, errOut: PointerByReference): Pointer?
        fun cx_md_to_toml (input: String, errOut: PointerByReference): Pointer?
        fun cx_md_to_md   (input: String, errOut: PointerByReference): Pointer?
    }

    private lateinit var lib: NativeLib

    init {
        val os   = System.getProperty("os.name", "").lowercase()
        val name = if (os.contains("mac")) "libcx.dylib" else "libcx.so"
        val candidates = mutableListOf<Path>()

        // 1. Explicit path override
        System.getenv("LIBCX_PATH")?.let { candidates.add(Paths.get(it)) }

        // 2. Directory override
        System.getenv("LIBCX_LIB_DIR")?.let { candidates.add(Paths.get(it, name)) }

        // 3. System paths
        for (dir in listOf("/usr/local/lib", "/opt/homebrew/lib", "/usr/lib",
                           "/usr/lib/x86_64-linux-gnu", "/usr/lib/aarch64-linux-gnu"))
            candidates.add(Paths.get(dir, name))

        // 4. Repo-relative fallback (development)
        try {
            val base = Paths.get(CxLib::class.java.protectionDomain.codeSource.location.toURI())
            val repo = base.parent.parent.parent.parent.parent.parent.parent
            candidates.add(repo.resolve("vcx/target/$name"))
            candidates.add(repo.resolve("dist/lib/$name"))
        } catch (_: Exception) {}

        val found = candidates.firstOrNull { Files.exists(it) }
            ?: throw RuntimeException("libcx not found. Install with 'sudo make install' or set LIBCX_PATH.")
        lib = Native.load(found.toString(), NativeLib::class.java)
        // Thread-init handshake — JVM threads aren't tracked by libgc
        // by default; call cx_init at module-load so the GC sees the
        // first thread that touches libcx (per spec/abi.md §1.5.5).
        lib.cx_init()
    }

    // ── helper ─────────────────────────────────────────────────────────────────

    private fun callFn(fn: (String, PointerByReference) -> Pointer?, input: String): String {
        val errRef = PointerByReference()
        val out = fn(input, errRef)
        if (out == null) {
            val ep  = errRef.value
            val msg = ep?.getString(0) ?: "unknown error"
            if (ep != null) lib.cx_free(ep)
            throw RuntimeException(msg)
        }
        val s = out.getString(0)
        lib.cx_free(out)
        return s
    }

    private fun callBinFn(fn: (String, PointerByReference) -> Pointer?, input: String): ByteArray {
        val errRef = PointerByReference()
        val out = fn(input, errRef)
        if (out == null) {
            val ep  = errRef.value
            val msg = ep?.getString(0) ?: "unknown error"
            if (ep != null) lib.cx_free(ep)
            throw RuntimeException(msg)
        }
        // Read 4-byte little-endian payload size
        val b0 = out.getByte(0).toInt() and 0xFF
        val b1 = out.getByte(1).toInt() and 0xFF
        val b2 = out.getByte(2).toInt() and 0xFF
        val b3 = out.getByte(3).toInt() and 0xFF
        val payloadSize = b0 or (b1 shl 8) or (b2 shl 16) or (b3 shl 24)
        val payload = out.getByteArray(4, payloadSize)
        lib.cx_free(out)
        return payload
    }

    // ── public API ─────────────────────────────────────────────────────────────

    fun version(): String {
        val p = lib.cx_version()
        val s = p.getString(0)
        lib.cx_free(p)
        return s
    }

    /**
     * libcx capability bitmask (spec/abi.md §2.11). Used by the optional
     * Arrow source-set to OR with libcx_arrow's bitmask. Public so the
     * Arrow source-set can route through the existing JNA load instead
     * of a duplicate `Native.load("cx", ...)`.
     */
    fun features(): Long {
        val p = lib.cx_features()
        val s = p.getString(0) ?: ""
        lib.cx_free(p)
        val str = if (s.startsWith("0x") || s.startsWith("0X")) s.substring(2) else s
        return try { java.lang.Long.parseUnsignedLong(str, 16) }
               catch (_: NumberFormatException) { 0L }
    }

    /** Return binary-encoded AST payload for the given CX string. */
    fun astBin(cxStr: String): ByteArray = callBinFn(lib::cx_to_ast_bin, cxStr)

    /** Return binary-encoded events payload for the given CX string. */
    fun eventsBin(cxStr: String): ByteArray = callBinFn(lib::cx_to_events_bin, cxStr)

    /**
     * Call cx_to_data_bin and return the CXDB v1 PAYLOAD (the [u32 LE size]
     * frame is stripped by callBinFn). Pass the result to [DataBin.decode].
     */
    fun toDataBin(cxStr: String): ByteArray = callBinFn(lib::cx_to_data_bin, cxStr)

    /**
     * Call cx_select_all_paths and decode the framed [u32 size][u32 n_paths][...]
     * blob into a list of structural paths. Each path is an IntArray of
     * 0-based indices: first into Document.elements, subsequent into
     * Element.items. Match order is preorder (same as cx_select_all).
     * See spec/abi.md §2.7.
     */
    fun selectAllPaths(cxText: String, expr: String): List<IntArray> {
        val errRef = PointerByReference()
        val out = lib.cx_select_all_paths(cxText, expr, errRef)
        if (out == null) {
            val ep  = errRef.value
            val msg = ep?.getString(0) ?: "unknown error"
            if (ep != null) lib.cx_free(ep)
            throw IllegalArgumentException(msg)
        }
        val b0 = out.getByte(0).toInt() and 0xFF
        val b1 = out.getByte(1).toInt() and 0xFF
        val b2 = out.getByte(2).toInt() and 0xFF
        val b3 = out.getByte(3).toInt() and 0xFF
        val payloadSize = b0 or (b1 shl 8) or (b2 shl 16) or (b3 shl 24)
        val payload = out.getByteArray(4, payloadSize)
        lib.cx_free(out)
        val bb = java.nio.ByteBuffer.wrap(payload).order(java.nio.ByteOrder.LITTLE_ENDIAN)
        val nPaths = bb.int
        val paths = ArrayList<IntArray>(nPaths)
        for (i in 0 until nPaths) {
            val depth = bb.int
            val path = IntArray(depth)
            for (k in 0 until depth) path[k] = bb.int
            paths.add(path)
        }
        return paths
    }

    // ── Phase 5 / CB-1 — ast_bin → text format ───────────────────────────────

    private fun astBinToText(
        fn: (ByteArray, PointerByReference) -> Pointer?,
        framed: ByteArray
    ): String {
        if (framed.isEmpty()) throw RuntimeException("ast_bin_to_*: empty input")
        val errRef = PointerByReference()
        val out = fn(framed, errRef)
        if (out == null) {
            val ep  = errRef.value
            val msg = ep?.getString(0) ?: "unknown error"
            if (ep != null) lib.cx_free(ep)
            throw RuntimeException(msg)
        }
        val s = out.getString(0)
        lib.cx_free(out)
        return s
    }

    fun astBinToCx  (framed: ByteArray): String = astBinToText(lib::cx_ast_bin_to_cx,   framed)
    fun astBinToXml (framed: ByteArray): String = astBinToText(lib::cx_ast_bin_to_xml,  framed)
    fun astBinToJson(framed: ByteArray): String = astBinToText(lib::cx_ast_bin_to_json, framed)
    fun astBinToYaml(framed: ByteArray): String = astBinToText(lib::cx_ast_bin_to_yaml, framed)
    fun astBinToToml(framed: ByteArray): String = astBinToText(lib::cx_ast_bin_to_toml, framed)
    fun astBinToMd  (framed: ByteArray): String = astBinToText(lib::cx_ast_bin_to_md,   framed)

    // ── Phase 5 / CB-2 — text → ast_bin (frame stripped) ─────────────────────

    fun xmlToAstBin (input: String): ByteArray = callBinFn(lib::cx_xml_to_ast_bin,  input)
    fun jsonToAstBin(input: String): ByteArray = callBinFn(lib::cx_json_to_ast_bin, input)
    fun yamlToAstBin(input: String): ByteArray = callBinFn(lib::cx_yaml_to_ast_bin, input)
    fun tomlToAstBin(input: String): ByteArray = callBinFn(lib::cx_toml_to_ast_bin, input)
    fun mdToAstBin  (input: String): ByteArray = callBinFn(lib::cx_md_to_ast_bin,   input)

    // ── data_bin one-shot loaders/dumpers (Phase 7.28; spec/abi.md §2.4–§2.5) ─

    /** Encode XML text to CXDB v1 PAYLOAD bytes (frame stripped). */
    fun xmlToDataBin (input: String): ByteArray = callBinFn(lib::cx_xml_to_data_bin,  input)
    /** Encode JSON text to CXDB v1 PAYLOAD bytes (frame stripped). */
    fun jsonToDataBin(input: String): ByteArray = callBinFn(lib::cx_json_to_data_bin, input)
    /** Encode YAML text to CXDB v1 PAYLOAD bytes (frame stripped). */
    fun yamlToDataBin(input: String): ByteArray = callBinFn(lib::cx_yaml_to_data_bin, input)
    /** Encode TOML text to CXDB v1 PAYLOAD bytes (frame stripped). */
    fun tomlToDataBin(input: String): ByteArray = callBinFn(lib::cx_toml_to_data_bin, input)
    /** Encode Markdown text to CXDB v1 PAYLOAD bytes (frame stripped). */
    fun mdToDataBin  (input: String): ByteArray = callBinFn(lib::cx_md_to_data_bin,   input)

    /** Decode FRAMED CXDB v1 bytes to XML text. */
    fun dataBinToXml (framed: ByteArray): String = astBinToText(lib::cx_data_bin_to_xml,  framed)
    /** Decode FRAMED CXDB v1 bytes to JSON text. */
    fun dataBinToJson(framed: ByteArray): String = astBinToText(lib::cx_data_bin_to_json, framed)
    /** Decode FRAMED CXDB v1 bytes to YAML text. */
    fun dataBinToYaml(framed: ByteArray): String = astBinToText(lib::cx_data_bin_to_yaml, framed)
    /** Decode FRAMED CXDB v1 bytes to TOML text. */
    fun dataBinToToml(framed: ByteArray): String = astBinToText(lib::cx_data_bin_to_toml, framed)
    /** Decode FRAMED CXDB v1 bytes to Markdown text. */
    fun dataBinToMd  (framed: ByteArray): String = astBinToText(lib::cx_data_bin_to_md,   framed)

    // ── Phase 5 / CB-4 — events handle API (used by EventStream) ─────────────

    internal fun eventsOpen(input: String, errOut: PointerByReference): Pointer? =
        lib.cx_events_open(input, errOut)
    internal fun eventsNext(handle: Pointer, errOut: PointerByReference): Pointer? =
        lib.cx_events_next(handle, errOut)
    internal fun eventsClose(handle: Pointer) { lib.cx_events_close(handle) }
    internal fun cxFree(p: Pointer) { lib.cx_free(p) }

    // ── Phase 6 / canonical-form tooling (spec/abi.md §2.6) ──────────────────

    /** Lossless canonical text CX. Idempotent. */
    fun fmt(input: String): String       = callFn(lib::cx_fmt,       input)

    /** Strict canonical text CX. */
    fun canonical(input: String): String = callFn(lib::cx_canonical, input)

    /** SHA-256 hex (64 lowercase hex chars) of the strict canonical bytes. */
    fun hash(input: String): String      = callFn(lib::cx_hash,      input)

    /** True iff strict-canonical(a) == strict-canonical(b). */
    fun eq(a: String, b: String): Boolean {
        val errRef = PointerByReference()
        val out = lib.cx_eq(a, b, errRef)
        if (out == null) {
            val ep  = errRef.value
            val msg = ep?.getString(0) ?: "unknown error"
            if (ep != null) lib.cx_free(ep)
            throw RuntimeException(msg)
        }
        val s = out.getString(0)
        lib.cx_free(out)
        return s == "1"
    }

    /**
     * Semantic diff between two CX inputs, walking the strict-canonical
     * forms. [format] is `"unified"`, `"json"`, or `"summary"`. Empty
     * result means data-equivalent.
     *
     * Per spec/decisions/0012-cx-diff.md.
     */
    fun diff(a: String, b: String, format: String = "unified"): String {
        val errRef = PointerByReference()
        val out = lib.cx_diff(a, b, format, errRef)
        if (out == null) {
            val ep  = errRef.value
            val msg = ep?.getString(0) ?: "unknown error"
            if (ep != null) lib.cx_free(ep)
            throw RuntimeException(msg)
        }
        val s = out.getString(0)
        lib.cx_free(out)
        return s
    }

    /**
     * Style + correctness warnings. [format] is `"text"`, `"json"`, or
     * `"summary"`. [disabled] is a comma-separated list of check IDs to
     * suppress (`""` runs all). Empty result means no findings.
     *
     * Per spec/decisions/0013-cx-lint.md.
     */
    fun lint(input: String, format: String = "text", disabled: String = ""): String {
        val errRef = PointerByReference()
        val out = lib.cx_lint(input, format, disabled, errRef)
        if (out == null) {
            val ep  = errRef.value
            val msg = ep?.getString(0) ?: "unknown error"
            if (ep != null) lib.cx_free(ep)
            throw RuntimeException(msg)
        }
        val s = out.getString(0)
        lib.cx_free(out)
        return s
    }

    // ── Phase 7.65 / ID/IDREF C ABI (ADR 0003) ──────────────────────────────

    /**
     * Find the element declaring `#id` in [input] and return its AST-JSON
     * encoding. Empty string means no such ID. Throws on parse error.
     */
    fun idLookup(input: String, id: String): String {
        val errRef = PointerByReference()
        val out = lib.cx_id_lookup(input, id, errRef)
        if (out == null) {
            val ep  = errRef.value
            val msg = ep?.getString(0) ?: "unknown error"
            if (ep != null) lib.cx_free(ep)
            throw RuntimeException(msg)
        }
        val s = out.getString(0)
        lib.cx_free(out)
        return s
    }

    /**
     * Resolve an attribute-value reference by its ID. Observationally
     * equivalent to [idLookup] (refs and IDs share a namespace). Empty
     * string means no such ID. Throws on parse error.
     */
    fun resolveRef(input: String, ref: String): String {
        val errRef = PointerByReference()
        val out = lib.cx_resolve_ref(input, ref, errRef)
        if (out == null) {
            val ep  = errRef.value
            val msg = ep?.getString(0) ?: "unknown error"
            if (ep != null) lib.cx_free(ep)
            throw RuntimeException(msg)
        }
        val s = out.getString(0)
        lib.cx_free(out)
        return s
    }

    /**
     * Run CXPath [cxpath] on [input] and return the syntactic ID of the
     * matched element. Empty when the matched element has no ID or no
     * element matched. Throws on parse/cxpath error.
     */
    fun nodeId(input: String, cxpath: String): String {
        val errRef = PointerByReference()
        val out = lib.cx_node_id(input, cxpath, errRef)
        if (out == null) {
            val ep  = errRef.value
            val msg = ep?.getString(0) ?: "unknown error"
            if (ep != null) lib.cx_free(ep)
            throw RuntimeException(msg)
        }
        val s = out.getString(0)
        lib.cx_free(out)
        return s
    }

    // ── Phase 7.68 / Delimited (CSV/TSV/PSV/arbitrary) C ABI (ADR 0001) ──────

    private fun callDelim(
        fn: (String, Byte, PointerByReference) -> Pointer?,
        input: String,
        delim: Byte
    ): String {
        val errRef = PointerByReference()
        val out = fn(input, delim, errRef)
        if (out == null) {
            val ep  = errRef.value
            val msg = ep?.getString(0) ?: "unknown error"
            if (ep != null) lib.cx_free(ep)
            throw RuntimeException(msg)
        }
        val s = out.getString(0)
        lib.cx_free(out)
        return s
    }

    /** Emit CX as delimited text using a single-byte delimiter. */
    fun toDelimited(input: String, delim: Char): String {
        val b = delim.code
        if (b > 0x7F) throw IllegalArgumentException("delim must be a single ASCII byte")
        return callDelim(lib::cx_to_delimited, input, b.toByte())
    }

    /** Parse delimited text to canonical CX using a single-byte delimiter. */
    fun fromDelimited(input: String, delim: Char): String {
        val b = delim.code
        if (b > 0x7F) throw IllegalArgumentException("delim must be a single ASCII byte")
        return callDelim(lib::cx_from_delimited, input, b.toByte())
    }

    fun toCsv  (input: String): String = callFn(lib::cx_to_csv,   input)
    fun fromCsv(input: String): String = callFn(lib::cx_from_csv, input)
    fun toTsv  (input: String): String = callFn(lib::cx_to_tsv,   input)
    fun fromTsv(input: String): String = callFn(lib::cx_from_tsv, input)
    fun toPsv  (input: String): String = callFn(lib::cx_to_psv,   input)
    fun fromPsv(input: String): String = callFn(lib::cx_from_psv, input)

    /** Encode CSV text to CXDB v1 PAYLOAD bytes (frame stripped). */
    fun csvToDataBin(input: String): ByteArray = callBinFn(lib::cx_csv_to_data_bin, input)
    /** Encode TSV text to CXDB v1 PAYLOAD bytes (frame stripped). */
    fun tsvToDataBin(input: String): ByteArray = callBinFn(lib::cx_tsv_to_data_bin, input)
    /** Encode PSV text to CXDB v1 PAYLOAD bytes (frame stripped). */
    fun psvToDataBin(input: String): ByteArray = callBinFn(lib::cx_psv_to_data_bin, input)

    /** Decode FRAMED CXDB v1 bytes to CSV text. */
    fun dataBinToCsv(framed: ByteArray): String = astBinToText(lib::cx_data_bin_to_csv, framed)
    /** Decode FRAMED CXDB v1 bytes to TSV text. */
    fun dataBinToTsv(framed: ByteArray): String = astBinToText(lib::cx_data_bin_to_tsv, framed)
    /** Decode FRAMED CXDB v1 bytes to PSV text. */
    fun dataBinToPsv(framed: ByteArray): String = astBinToText(lib::cx_data_bin_to_psv, framed)

    /**
     * Call cx_from_data_bin with FRAMED CXDB v1 bytes (as returned by
     * [DataBin.encode]) and return the canonical CX text.
     */
    fun fromDataBin(framed: ByteArray): String {
        if (framed.isEmpty()) throw RuntimeException("cx_from_data_bin: empty input")
        val errRef = PointerByReference()
        val out = lib.cx_from_data_bin(framed, errRef)
        if (out == null) {
            val ep  = errRef.value
            val msg = ep?.getString(0) ?: "unknown error"
            if (ep != null) lib.cx_free(ep)
            throw RuntimeException(msg)
        }
        val s = out.getString(0)
        lib.cx_free(out)
        return s
    }

    // CX input
    fun toCx        (input: String) = callFn(lib::cx_to_cx,         input)
    fun toCxCompact (input: String) = callFn(lib::cx_to_cx_compact, input)
    fun astToCx     (input: String) = callFn(lib::cx_ast_to_cx,     input)
    fun toXml (input: String) = callFn(lib::cx_to_xml,  input)
    fun toAst (input: String) = callFn(lib::cx_to_ast,  input)
    fun toJson(input: String) = callFn(lib::cx_to_json, input)
    fun toYaml(input: String) = callFn(lib::cx_to_yaml, input)
    fun toToml(input: String) = callFn(lib::cx_to_toml, input)
    fun toMd  (input: String) = callFn(lib::cx_to_md,   input)

    /**
     * Evaluate a CXL program against a CX context document.
     * outputTarget may be "" (honour the program's [?cx output-target=…]
     * directive, default "text") or one of "text" / "cx" / "html" at
     * CXL 1.0 (v0.6.0).
     */
    fun evalCxl(input: String, program: String, outputTarget: String = ""): String {
        val err = PointerByReference()
        val out = lib.cx_eval_cxl(input, program, outputTarget, err)
            ?: run {
                val ep = err.value
                val msg = ep?.getString(0) ?: "cx_eval_cxl: unknown error"
                ep?.let { lib.cx_free(it) }
                throw RuntimeException(msg)
            }
        val s = out.getString(0)
        lib.cx_free(out)
        return s
    }

    // XML input
    fun xmlToCx  (input: String) = callFn(lib::cx_xml_to_cx,   input)
    fun xmlToXml (input: String) = callFn(lib::cx_xml_to_xml,  input)
    fun xmlToAst (input: String) = callFn(lib::cx_xml_to_ast,  input)
    fun xmlToJson(input: String) = callFn(lib::cx_xml_to_json, input)
    fun xmlToYaml(input: String) = callFn(lib::cx_xml_to_yaml, input)
    fun xmlToToml(input: String) = callFn(lib::cx_xml_to_toml, input)
    fun xmlToMd  (input: String) = callFn(lib::cx_xml_to_md,   input)

    // JSON input
    fun jsonToCx  (input: String) = callFn(lib::cx_json_to_cx,   input)
    fun jsonToXml (input: String) = callFn(lib::cx_json_to_xml,  input)
    fun jsonToAst (input: String) = callFn(lib::cx_json_to_ast,  input)
    fun jsonToJson(input: String) = callFn(lib::cx_json_to_json, input)
    fun jsonToYaml(input: String) = callFn(lib::cx_json_to_yaml, input)
    fun jsonToToml(input: String) = callFn(lib::cx_json_to_toml, input)
    fun jsonToMd  (input: String) = callFn(lib::cx_json_to_md,   input)

    // YAML input
    fun yamlToCx  (input: String) = callFn(lib::cx_yaml_to_cx,   input)
    fun yamlToXml (input: String) = callFn(lib::cx_yaml_to_xml,  input)
    fun yamlToAst (input: String) = callFn(lib::cx_yaml_to_ast,  input)
    fun yamlToJson(input: String) = callFn(lib::cx_yaml_to_json, input)
    fun yamlToYaml(input: String) = callFn(lib::cx_yaml_to_yaml, input)
    fun yamlToToml(input: String) = callFn(lib::cx_yaml_to_toml, input)
    fun yamlToMd  (input: String) = callFn(lib::cx_yaml_to_md,   input)

    // TOML input
    fun tomlToCx  (input: String) = callFn(lib::cx_toml_to_cx,   input)
    fun tomlToXml (input: String) = callFn(lib::cx_toml_to_xml,  input)
    fun tomlToAst (input: String) = callFn(lib::cx_toml_to_ast,  input)
    fun tomlToJson(input: String) = callFn(lib::cx_toml_to_json, input)
    fun tomlToYaml(input: String) = callFn(lib::cx_toml_to_yaml, input)
    fun tomlToToml(input: String) = callFn(lib::cx_toml_to_toml, input)
    fun tomlToMd  (input: String) = callFn(lib::cx_toml_to_md,   input)

    // MD input
    fun mdToCx  (input: String) = callFn(lib::cx_md_to_cx,   input)
    fun mdToXml (input: String) = callFn(lib::cx_md_to_xml,  input)
    fun mdToAst (input: String) = callFn(lib::cx_md_to_ast,  input)
    fun mdToJson(input: String) = callFn(lib::cx_md_to_json, input)
    fun mdToYaml(input: String) = callFn(lib::cx_md_to_yaml, input)
    fun mdToToml(input: String) = callFn(lib::cx_md_to_toml, input)
    fun mdToMd  (input: String) = callFn(lib::cx_md_to_md,   input)

    // ── Phase 7.72 — chunked-table one-shot (ADR 0015 D8) ───────────────────

    /**
     * Encode CX text whose root is a single :table-bodied element to the
     * CXDB chunked-table form. Returns the FRAMED buffer
     * `[u32 LE size][payload]` (consumable by [fromDataBin] or [TableReader]).
     */
    fun toDataBinChunked(input: String): ByteArray {
        val errRef = PointerByReference()
        val out = lib.cx_to_data_bin_chunked(input, errRef)
            ?: run {
                val ep  = errRef.value
                val msg = ep?.getString(0) ?: "unknown error"
                if (ep != null) lib.cx_free(ep)
                throw RuntimeException(msg)
            }
        val b0 = out.getByte(0).toInt() and 0xFF
        val b1 = out.getByte(1).toInt() and 0xFF
        val b2 = out.getByte(2).toInt() and 0xFF
        val b3 = out.getByte(3).toInt() and 0xFF
        val payloadSize = b0 or (b1 shl 8) or (b2 shl 16) or (b3 shl 24)
        val framed = out.getByteArray(0, 4 + payloadSize)
        lib.cx_free(out)
        return framed
    }

    // ── Phase 7.73 — schema-driven CXDB encoding (ADR 0015 D3) ──────────────

    private fun callSchemaDrivenLoader(
        fn: (String, String, Int, String, PointerByReference) -> Pointer?,
        input: String, schema: String, refForm: Int, nameHint: String
    ): ByteArray {
        require(refForm in 0..2) {
            "refForm must be 0 (hash-only), 1 (inline), or 2 (hash+name)"
        }
        val errRef = PointerByReference()
        val out = fn(input, schema, refForm, nameHint, errRef)
            ?: run {
                val ep  = errRef.value
                val msg = ep?.getString(0) ?: "unknown error"
                if (ep != null) lib.cx_free(ep)
                throw RuntimeException(msg)
            }
        val b0 = out.getByte(0).toInt() and 0xFF
        val b1 = out.getByte(1).toInt() and 0xFF
        val b2 = out.getByte(2).toInt() and 0xFF
        val b3 = out.getByte(3).toInt() and 0xFF
        val payloadSize = b0 or (b1 shl 8) or (b2 shl 16) or (b3 shl 24)
        val framed = out.getByteArray(0, 4 + payloadSize)
        lib.cx_free(out)
        return framed
    }

    fun toDataBinSchemaDriven    (input: String, schema: String, refForm: Int = 0, nameHint: String = ""): ByteArray =
        callSchemaDrivenLoader(lib::cx_to_data_bin_schema_driven,      input, schema, refForm, nameHint)
    fun xmlToDataBinSchemaDriven (input: String, schema: String, refForm: Int = 0, nameHint: String = ""): ByteArray =
        callSchemaDrivenLoader(lib::cx_xml_to_data_bin_schema_driven,  input, schema, refForm, nameHint)
    fun jsonToDataBinSchemaDriven(input: String, schema: String, refForm: Int = 0, nameHint: String = ""): ByteArray =
        callSchemaDrivenLoader(lib::cx_json_to_data_bin_schema_driven, input, schema, refForm, nameHint)
    fun yamlToDataBinSchemaDriven(input: String, schema: String, refForm: Int = 0, nameHint: String = ""): ByteArray =
        callSchemaDrivenLoader(lib::cx_yaml_to_data_bin_schema_driven, input, schema, refForm, nameHint)
    fun tomlToDataBinSchemaDriven(input: String, schema: String, refForm: Int = 0, nameHint: String = ""): ByteArray =
        callSchemaDrivenLoader(lib::cx_toml_to_data_bin_schema_driven, input, schema, refForm, nameHint)
    fun mdToDataBinSchemaDriven  (input: String, schema: String, refForm: Int = 0, nameHint: String = ""): ByteArray =
        callSchemaDrivenLoader(lib::cx_md_to_data_bin_schema_driven,   input, schema, refForm, nameHint)
    fun csvToDataBinSchemaDriven (input: String, schema: String, refForm: Int = 0, nameHint: String = ""): ByteArray =
        callSchemaDrivenLoader(lib::cx_csv_to_data_bin_schema_driven,  input, schema, refForm, nameHint)
    fun tsvToDataBinSchemaDriven (input: String, schema: String, refForm: Int = 0, nameHint: String = ""): ByteArray =
        callSchemaDrivenLoader(lib::cx_tsv_to_data_bin_schema_driven,  input, schema, refForm, nameHint)
    fun psvToDataBinSchemaDriven (input: String, schema: String, refForm: Int = 0, nameHint: String = ""): ByteArray =
        callSchemaDrivenLoader(lib::cx_psv_to_data_bin_schema_driven,  input, schema, refForm, nameHint)

    /** Decode a FRAMED schema-driven CXDB buffer back to canonical CX text.
     *  Pass `""` for [schemaHint] to use only the embedded reference's resolution. */
    fun fromDataBinSchemaDriven(framed: ByteArray, schemaHint: String = ""): String {
        if (framed.isEmpty()) throw RuntimeException("cx_from_data_bin_schema_driven: empty input")
        val errRef = PointerByReference()
        val out = lib.cx_from_data_bin_schema_driven(framed, schemaHint, errRef)
            ?: run {
                val ep  = errRef.value
                val msg = ep?.getString(0) ?: "unknown error"
                if (ep != null) lib.cx_free(ep)
                throw RuntimeException(msg)
            }
        val s = out.getString(0)
        lib.cx_free(out)
        return s
    }

    // ── Phase 7.74a — streaming Table internals (used by TableReader/Writer) ─

    internal fun tableReaderOpen   (dataBin: ByteArray, err: PointerByReference) = lib.cx_table_reader_open    (dataBin, err)
    internal fun tableReaderOpenFd (fd: Int,            err: PointerByReference) = lib.cx_table_reader_open_fd (fd, err)
    internal fun tableReaderSchema (h: Pointer,         err: PointerByReference) = lib.cx_table_reader_schema  (h, err)
    internal fun tableReaderNext   (h: Pointer,         err: PointerByReference) = lib.cx_table_reader_next    (h, err)
    internal fun tableReaderClose  (h: Pointer)                                  = lib.cx_table_reader_close   (h)

    internal fun tableWriterOpen           (cs: ByteArray, err: PointerByReference)                = lib.cx_table_writer_open           (cs, err)
    internal fun tableWriterOpenFd         (cs: ByteArray, fd: Int, err: PointerByReference)       = lib.cx_table_writer_open_fd        (cs, fd, err)
    internal fun tableWriterEmitRowGroup   (h: Pointer, payload: ByteArray, err: PointerByReference) = lib.cx_table_writer_emit_row_group(h, payload, err)
    internal fun tableWriterCloseGetBytes  (h: Pointer, err: PointerByReference)                   = lib.cx_table_writer_close_get_bytes(h, err)
    internal fun tableWriterClose          (h: Pointer)                                            = lib.cx_table_writer_close          (h)
}
