package cx;

import com.sun.jna.*;
import com.sun.jna.ptr.PointerByReference;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.file.*;
import java.util.Arrays;
import java.util.List;
import java.util.function.BiFunction;

/**
 * CX Java binding — JNA wrapper around libcx.
 */
public class CxLib {

    /** JNA native interface mirroring cx.h */
    interface NativeLib extends Library {
        // Thread-init handshake (spec/abi.md §1.5.5, capability bit 26).
        // Mandatory-for-all-bindings; called once at module-load time.
        int     cx_init   ();
        void    cx_free   (Pointer s);
        Pointer cx_version();
        Pointer cx_features();

        // CX input
        Pointer cx_to_cx          (String input, PointerByReference errOut);
        Pointer cx_to_cx_compact  (String input, PointerByReference errOut);
        Pointer cx_ast_to_cx      (String input, PointerByReference errOut);
        Pointer cx_to_xml  (String input, PointerByReference errOut);
        Pointer cx_to_ast  (String input, PointerByReference errOut);
        Pointer cx_to_json (String input, PointerByReference errOut);
        Pointer cx_to_yaml (String input, PointerByReference errOut);
        Pointer cx_to_toml (String input, PointerByReference errOut);
        Pointer cx_to_md   (String input, PointerByReference errOut);

        // CXL evaluator (capability bit 28; spec/cxl.md)
        Pointer cx_eval_cxl(String input, String program, String outputTarget, PointerByReference errOut);

        // XML input
        Pointer cx_xml_to_cx   (String input, PointerByReference errOut);
        Pointer cx_xml_to_xml  (String input, PointerByReference errOut);
        Pointer cx_xml_to_ast  (String input, PointerByReference errOut);
        Pointer cx_xml_to_json (String input, PointerByReference errOut);
        Pointer cx_xml_to_yaml (String input, PointerByReference errOut);
        Pointer cx_xml_to_toml (String input, PointerByReference errOut);
        Pointer cx_xml_to_md   (String input, PointerByReference errOut);

        // JSON input
        Pointer cx_json_to_cx   (String input, PointerByReference errOut);
        Pointer cx_json_to_xml  (String input, PointerByReference errOut);
        Pointer cx_json_to_ast  (String input, PointerByReference errOut);
        Pointer cx_json_to_json (String input, PointerByReference errOut);
        Pointer cx_json_to_yaml (String input, PointerByReference errOut);
        Pointer cx_json_to_toml (String input, PointerByReference errOut);
        Pointer cx_json_to_md   (String input, PointerByReference errOut);

        // YAML input
        Pointer cx_yaml_to_cx   (String input, PointerByReference errOut);
        Pointer cx_yaml_to_xml  (String input, PointerByReference errOut);
        Pointer cx_yaml_to_ast  (String input, PointerByReference errOut);
        Pointer cx_yaml_to_json (String input, PointerByReference errOut);
        Pointer cx_yaml_to_yaml (String input, PointerByReference errOut);
        Pointer cx_yaml_to_toml (String input, PointerByReference errOut);
        Pointer cx_yaml_to_md   (String input, PointerByReference errOut);

        // TOML input
        Pointer cx_toml_to_cx   (String input, PointerByReference errOut);
        Pointer cx_toml_to_xml  (String input, PointerByReference errOut);
        Pointer cx_toml_to_ast  (String input, PointerByReference errOut);
        Pointer cx_toml_to_json (String input, PointerByReference errOut);
        Pointer cx_toml_to_yaml (String input, PointerByReference errOut);
        Pointer cx_toml_to_toml (String input, PointerByReference errOut);
        Pointer cx_toml_to_md   (String input, PointerByReference errOut);

        // MD input
        Pointer cx_md_to_cx   (String input, PointerByReference errOut);
        Pointer cx_md_to_xml  (String input, PointerByReference errOut);
        Pointer cx_md_to_ast  (String input, PointerByReference errOut);
        Pointer cx_md_to_json (String input, PointerByReference errOut);
        Pointer cx_md_to_yaml (String input, PointerByReference errOut);
        Pointer cx_md_to_toml (String input, PointerByReference errOut);
        Pointer cx_md_to_md   (String input, PointerByReference errOut);

        // Binary output
        Pointer cx_to_ast_bin    (String input, PointerByReference errOut);
        Pointer cx_to_events_bin (String input, PointerByReference errOut);
        Pointer cx_to_data_bin   (String input, PointerByReference errOut);

        // CXDB framed bytes in, canonical CX text out.
        Pointer cx_from_data_bin (byte[] input, PointerByReference errOut);

        // data_bin one-shot loaders/dumpers (Phase 7.28; spec/abi.md §2.4–§2.5).
        Pointer cx_xml_to_data_bin (String input, PointerByReference errOut);
        Pointer cx_json_to_data_bin(String input, PointerByReference errOut);
        Pointer cx_yaml_to_data_bin(String input, PointerByReference errOut);
        Pointer cx_toml_to_data_bin(String input, PointerByReference errOut);
        Pointer cx_md_to_data_bin  (String input, PointerByReference errOut);

        Pointer cx_data_bin_to_xml (byte[] input, PointerByReference errOut);
        Pointer cx_data_bin_to_json(byte[] input, PointerByReference errOut);
        Pointer cx_data_bin_to_yaml(byte[] input, PointerByReference errOut);
        Pointer cx_data_bin_to_toml(byte[] input, PointerByReference errOut);
        Pointer cx_data_bin_to_md  (byte[] input, PointerByReference errOut);

        // CXPath path-tracking C ABI (Phase 4 / CB-5).
        Pointer cx_select_all_paths(String input, String expr, PointerByReference errOut);

        // Phase 5 / CB-1 — ast_bin → text format. byte[] input passes
        // a pointer; the C side reads size from the first 4 bytes.
        Pointer cx_ast_bin_to_cx  (byte[] input, PointerByReference errOut);
        Pointer cx_ast_bin_to_xml (byte[] input, PointerByReference errOut);
        Pointer cx_ast_bin_to_json(byte[] input, PointerByReference errOut);
        Pointer cx_ast_bin_to_yaml(byte[] input, PointerByReference errOut);
        Pointer cx_ast_bin_to_toml(byte[] input, PointerByReference errOut);
        Pointer cx_ast_bin_to_md  (byte[] input, PointerByReference errOut);

        // Phase 5 / CB-2 — text → ast_bin (returns framed binary).
        Pointer cx_xml_to_ast_bin (String input, PointerByReference errOut);
        Pointer cx_json_to_ast_bin(String input, PointerByReference errOut);
        Pointer cx_yaml_to_ast_bin(String input, PointerByReference errOut);
        Pointer cx_toml_to_ast_bin(String input, PointerByReference errOut);
        Pointer cx_md_to_ast_bin  (String input, PointerByReference errOut);

        // Phase 5 / CB-4 — events handle API.
        Pointer cx_events_open (String input, PointerByReference errOut);
        Pointer cx_events_next (Pointer handle, PointerByReference errOut);
        void    cx_events_close(Pointer handle);

        // Phase 6 — canonical-form tooling (spec/abi.md §2.6).
        Pointer cx_fmt      (String input, PointerByReference errOut);
        Pointer cx_canonical(String input, PointerByReference errOut);
        Pointer cx_hash     (String input, PointerByReference errOut);
        Pointer cx_eq       (String a, String b, PointerByReference errOut);

        // Phase 7.47 — cx diff (ADR 0012). format = "unified" | "json" | "summary".
        Pointer cx_diff     (String a, String b, String format, PointerByReference errOut);

        // Phase 7.49 — cx lint (ADR 0013). format = "text" | "json" | "summary".
        Pointer cx_lint     (String input, String format, String disabled, PointerByReference errOut);

        // Phase 7.65 — ID/IDREF C ABI (ADR 0003).
        Pointer cx_id_lookup  (String input, String id,     PointerByReference errOut);
        Pointer cx_resolve_ref(String input, String ref,    PointerByReference errOut);
        Pointer cx_node_id    (String input, String cxpath, PointerByReference errOut);

        // Phase 7.68 — Delimited (CSV/TSV/PSV/arbitrary) C ABI (ADR 0001).
        // 8 text-text. cx_to_delimited / cx_from_delimited carry a single-byte
        // delimiter; the cx_{to,from}_{csv,tsv,psv} aliases hard-code `,` `\t` `|`.
        Pointer cx_to_delimited  (String input, byte delim, PointerByReference errOut);
        Pointer cx_from_delimited(String input, byte delim, PointerByReference errOut);
        Pointer cx_to_csv  (String input, PointerByReference errOut);
        Pointer cx_from_csv(String input, PointerByReference errOut);
        Pointer cx_to_tsv  (String input, PointerByReference errOut);
        Pointer cx_from_tsv(String input, PointerByReference errOut);
        Pointer cx_to_psv  (String input, PointerByReference errOut);
        Pointer cx_from_psv(String input, PointerByReference errOut);

        // 6 binary one-shots: csv/tsv/psv ↔ data_bin.
        Pointer cx_csv_to_data_bin(String input, PointerByReference errOut);
        Pointer cx_tsv_to_data_bin(String input, PointerByReference errOut);
        Pointer cx_psv_to_data_bin(String input, PointerByReference errOut);
        Pointer cx_data_bin_to_csv(byte[] input, PointerByReference errOut);
        Pointer cx_data_bin_to_tsv(byte[] input, PointerByReference errOut);
        Pointer cx_data_bin_to_psv(byte[] input, PointerByReference errOut);

        // Phase 7.72 — chunked-table one-shot (spec/abi.md §2.10, ADR 0015 D8).
        Pointer cx_to_data_bin_chunked(String input, PointerByReference errOut);

        // Phase 7.74a — streaming Table reader / writer (spec/abi.md §2.10).
        // Binary inputs (data_bin / col_spec_payload / row_group_payload) carry
        // NULs, so they are declared as byte[] (JNA passes a pointer; the C
        // side reads size from the first 4 bytes of the framed buffer).
        Pointer cx_table_reader_open    (byte[] data_bin, PointerByReference errOut);
        Pointer cx_table_reader_open_fd (int fd,          PointerByReference errOut);
        Pointer cx_table_reader_schema  (Pointer handle,  PointerByReference errOut);
        Pointer cx_table_reader_next    (Pointer handle,  PointerByReference errOut);
        void    cx_table_reader_close   (Pointer handle);

        Pointer cx_table_writer_open            (byte[] col_spec_payload,
                                                 PointerByReference errOut);
        Pointer cx_table_writer_open_fd         (byte[] col_spec_payload, int fd,
                                                 PointerByReference errOut);
        Pointer cx_table_writer_emit_row_group  (Pointer handle, byte[] row_group_payload,
                                                 PointerByReference errOut);
        Pointer cx_table_writer_close_get_bytes (Pointer handle, PointerByReference errOut);
        void    cx_table_writer_close           (Pointer handle);

        // Phase 7.73 — schema-driven CXDB encoding (spec/abi.md §2.12, ADR 0015 D3).
        Pointer cx_to_data_bin_schema_driven      (String input, String schema,
                                                   int ref_form, String name_hint,
                                                   PointerByReference errOut);
        Pointer cx_xml_to_data_bin_schema_driven  (String input, String schema,
                                                   int ref_form, String name_hint,
                                                   PointerByReference errOut);
        Pointer cx_json_to_data_bin_schema_driven (String input, String schema,
                                                   int ref_form, String name_hint,
                                                   PointerByReference errOut);
        Pointer cx_yaml_to_data_bin_schema_driven (String input, String schema,
                                                   int ref_form, String name_hint,
                                                   PointerByReference errOut);
        Pointer cx_toml_to_data_bin_schema_driven (String input, String schema,
                                                   int ref_form, String name_hint,
                                                   PointerByReference errOut);
        Pointer cx_md_to_data_bin_schema_driven   (String input, String schema,
                                                   int ref_form, String name_hint,
                                                   PointerByReference errOut);
        Pointer cx_csv_to_data_bin_schema_driven  (String input, String schema,
                                                   int ref_form, String name_hint,
                                                   PointerByReference errOut);
        Pointer cx_tsv_to_data_bin_schema_driven  (String input, String schema,
                                                   int ref_form, String name_hint,
                                                   PointerByReference errOut);
        Pointer cx_psv_to_data_bin_schema_driven  (String input, String schema,
                                                   int ref_form, String name_hint,
                                                   PointerByReference errOut);
        Pointer cx_from_data_bin_schema_driven    (byte[] data_bin, String schema_hint,
                                                   PointerByReference errOut);

        // Phase 7.74d — schema validator (ADR 0009 / spec/abi.md §2.13).
        // The `_with_len` variants tolerate non-NUL-terminated buffers and
        // empty input. JNA passes byte[] as a pointer; size_t is 8 bytes on
        // every platform this binding ships on (macOS / Linux, both 64-bit).
        Pointer cx_validate_with_len(byte[] doc, long docLen,
                                     byte[] schema, long schemaLen,
                                     PointerByReference errOut);
        Pointer cx_validate_apply_defaults_with_len(byte[] doc, long docLen,
                                                    byte[] schema, long schemaLen,
                                                    PointerByReference modifiedOut,
                                                    PointerByReference errOut);

        // Phase 7.74i — streaming-write API (ADR 0011 / spec/streaming.md §6 /
        // spec/abi.md §2.15, capability bit 27). 25 cx_events_writer_* symbols.
        Pointer cx_events_writer_open    (String outputFormat, PointerByReference errOut);
        Pointer cx_events_writer_open_fd (String outputFormat, int fd, PointerByReference errOut);
        Pointer cx_events_writer_close_get_bytes(Pointer h, PointerByReference errOut);
        void    cx_events_writer_close   (Pointer h);

        Pointer cx_events_writer_start_doc(Pointer h, PointerByReference errOut);
        Pointer cx_events_writer_end_doc  (Pointer h, PointerByReference errOut);

        Pointer cx_events_writer_start_element_with_len(
            Pointer h, String name, String anchor, String dataType, String merge,
            byte[] attrsPayload, long attrsLen, PointerByReference errOut);
        Pointer cx_events_writer_end_element(Pointer h, String name, PointerByReference errOut);

        Pointer cx_events_writer_text       (Pointer h, String value, PointerByReference errOut);
        Pointer cx_events_writer_scalar     (Pointer h, String dataType, String value, PointerByReference errOut);
        Pointer cx_events_writer_comment    (Pointer h, String value, PointerByReference errOut);
        Pointer cx_events_writer_pi         (Pointer h, String target, String data, PointerByReference errOut);
        Pointer cx_events_writer_entity_ref (Pointer h, String name, PointerByReference errOut);
        Pointer cx_events_writer_raw_text   (Pointer h, String value, PointerByReference errOut);
        Pointer cx_events_writer_alias      (Pointer h, String name, PointerByReference errOut);

        Pointer cx_events_writer_start_table_with_len(
            Pointer h, byte[] colSpecPayload, long colSpecLen, PointerByReference errOut);
        Pointer cx_events_writer_row_group_with_len(
            Pointer h, byte[] rowGroupPayload, long rowGroupLen, PointerByReference errOut);
        Pointer cx_events_writer_end_table (Pointer h, PointerByReference errOut);
    }

    private static final NativeLib LIB;

    static {
        String os   = System.getProperty("os.name", "").toLowerCase();
        String name = os.contains("mac") ? "libcx.dylib" : "libcx.so";
        List<String> candidates = new java.util.ArrayList<>();

        // 1. Explicit path override
        String envPath = System.getenv("LIBCX_PATH");
        if (envPath != null) candidates.add(envPath);

        // 2. Directory override
        String envDir = System.getenv("LIBCX_LIB_DIR");
        if (envDir != null) candidates.add(envDir + "/" + name);

        // 3. System paths
        for (String dir : new String[]{"/usr/local/lib", "/opt/homebrew/lib", "/usr/lib",
                                       "/usr/lib/x86_64-linux-gnu", "/usr/lib/aarch64-linux-gnu"})
            candidates.add(dir + "/" + name);

        // 4. Repo-relative fallback (development)
        try {
            Path base = Paths.get(CxLib.class.getProtectionDomain()
                    .getCodeSource().getLocation().toURI());
            Path repo = base.getParent().getParent().getParent().getParent().getParent();
            candidates.add(repo.resolve("vcx/target/" + name).toString());
            candidates.add(repo.resolve("dist/lib/"   + name).toString());
        } catch (Exception ignored) {}

        String found = candidates.stream()
                .filter(p -> Files.exists(Paths.get(p)))
                .findFirst()
                .orElseThrow(() -> new RuntimeException(
                        "libcx not found. Install with 'sudo make install' or set LIBCX_PATH."));
        LIB = Native.load(found, NativeLib.class);
        // Thread-init handshake — JVM threads aren't tracked by libgc
        // by default; call cx_init at module-load so the GC sees the
        // first thread that touches libcx (per spec/abi.md §1.5.5).
        LIB.cx_init();
    }

    // ── helper ─────────────────────────────────────────────────────────────────

    private static String callFn(
            BiFunction<String, PointerByReference, Pointer> fn,
            String input) {
        PointerByReference errRef = new PointerByReference();
        Pointer out = fn.apply(input, errRef);
        if (out == null) {
            Pointer ep  = errRef.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "unknown error";
            if (ep != null) LIB.cx_free(ep);
            throw new RuntimeException(msg);
        }
        String s = out.getString(0);
        LIB.cx_free(out);
        return s;
    }

    // ── public API ─────────────────────────────────────────────────────────────

    public static String version() {
        Pointer p = LIB.cx_version();
        String s  = p.getString(0);
        LIB.cx_free(p);
        return s;
    }

    /**
     * libcx capability bitmask (spec/abi.md §2.6). Public so the optional
     * Arrow binding can OR it with libcx_arrow's mask without re-declaring
     * a per-assembly DllImport for {@code cx_features}.
     */
    public static long features() {
        Pointer p = LIB.cx_features();
        if (p == null) return 0L;
        String s = p.getString(0);
        LIB.cx_free(p);
        if (s.startsWith("0x") || s.startsWith("0X")) s = s.substring(2);
        try { return Long.parseUnsignedLong(s, 16); }
        catch (NumberFormatException e) { return 0L; }
    }

    // CX input
    public static String toCx        (String input) { return callFn(LIB::cx_to_cx,         input); }
    public static String toCxCompact (String input) { return callFn(LIB::cx_to_cx_compact, input); }
    public static String astToCx     (String input) { return callFn(LIB::cx_ast_to_cx,     input); }
    public static String toXml (String input) { return callFn(LIB::cx_to_xml,  input); }
    public static String toAst (String input) { return callFn(LIB::cx_to_ast,  input); }
    public static String toJson(String input) { return callFn(LIB::cx_to_json, input); }
    public static String toYaml(String input) { return callFn(LIB::cx_to_yaml, input); }
    public static String toToml(String input) { return callFn(LIB::cx_to_toml, input); }
    public static String toMd  (String input) { return callFn(LIB::cx_to_md,   input); }

    /**
     * Evaluate a CXL program against a CX context document.
     * outputTarget may be "" (honour the program's [?cx output-target=…]
     * directive, default "text") or one of "text" / "cx" / "html" at
     * CXL 1.0 (v0.6.0).
     */
    public static String evalCxl(String input, String program, String outputTarget) {
        PointerByReference err = new PointerByReference();
        Pointer out = LIB.cx_eval_cxl(input, program, outputTarget == null ? "" : outputTarget, err);
        if (out == null) {
            Pointer ep = err.getValue();
            String msg = (ep != null) ? ep.getString(0) : "cx_eval_cxl: unknown error";
            if (ep != null) LIB.cx_free(ep);
            throw new RuntimeException(msg);
        }
        String s = out.getString(0);
        LIB.cx_free(out);
        return s;
    }

    // XML input
    public static String xmlToCx  (String input) { return callFn(LIB::cx_xml_to_cx,   input); }
    public static String xmlToXml (String input) { return callFn(LIB::cx_xml_to_xml,  input); }
    public static String xmlToAst (String input) { return callFn(LIB::cx_xml_to_ast,  input); }
    public static String xmlToJson(String input) { return callFn(LIB::cx_xml_to_json, input); }
    public static String xmlToYaml(String input) { return callFn(LIB::cx_xml_to_yaml, input); }
    public static String xmlToToml(String input) { return callFn(LIB::cx_xml_to_toml, input); }
    public static String xmlToMd  (String input) { return callFn(LIB::cx_xml_to_md,   input); }

    // JSON input
    public static String jsonToCx  (String input) { return callFn(LIB::cx_json_to_cx,   input); }
    public static String jsonToXml (String input) { return callFn(LIB::cx_json_to_xml,  input); }
    public static String jsonToAst (String input) { return callFn(LIB::cx_json_to_ast,  input); }
    public static String jsonToJson(String input) { return callFn(LIB::cx_json_to_json, input); }
    public static String jsonToYaml(String input) { return callFn(LIB::cx_json_to_yaml, input); }
    public static String jsonToToml(String input) { return callFn(LIB::cx_json_to_toml, input); }
    public static String jsonToMd  (String input) { return callFn(LIB::cx_json_to_md,   input); }

    // YAML input
    public static String yamlToCx  (String input) { return callFn(LIB::cx_yaml_to_cx,   input); }
    public static String yamlToXml (String input) { return callFn(LIB::cx_yaml_to_xml,  input); }
    public static String yamlToAst (String input) { return callFn(LIB::cx_yaml_to_ast,  input); }
    public static String yamlToJson(String input) { return callFn(LIB::cx_yaml_to_json, input); }
    public static String yamlToYaml(String input) { return callFn(LIB::cx_yaml_to_yaml, input); }
    public static String yamlToToml(String input) { return callFn(LIB::cx_yaml_to_toml, input); }
    public static String yamlToMd  (String input) { return callFn(LIB::cx_yaml_to_md,   input); }

    // TOML input
    public static String tomlToCx  (String input) { return callFn(LIB::cx_toml_to_cx,   input); }
    public static String tomlToXml (String input) { return callFn(LIB::cx_toml_to_xml,  input); }
    public static String tomlToAst (String input) { return callFn(LIB::cx_toml_to_ast,  input); }
    public static String tomlToJson(String input) { return callFn(LIB::cx_toml_to_json, input); }
    public static String tomlToYaml(String input) { return callFn(LIB::cx_toml_to_yaml, input); }
    public static String tomlToToml(String input) { return callFn(LIB::cx_toml_to_toml, input); }
    public static String tomlToMd  (String input) { return callFn(LIB::cx_toml_to_md,   input); }

    // MD input
    public static String mdToCx  (String input) { return callFn(LIB::cx_md_to_cx,   input); }
    public static String mdToXml (String input) { return callFn(LIB::cx_md_to_xml,  input); }
    public static String mdToAst (String input) { return callFn(LIB::cx_md_to_ast,  input); }
    public static String mdToJson(String input) { return callFn(LIB::cx_md_to_json, input); }
    public static String mdToYaml(String input) { return callFn(LIB::cx_md_to_yaml, input); }
    public static String mdToToml(String input) { return callFn(LIB::cx_md_to_toml, input); }
    public static String mdToMd  (String input) { return callFn(LIB::cx_md_to_md,   input); }

    // ── binary helpers ─────────────────────────────────────────────────────────

    /**
     * Call cx_to_ast_bin, read the length-prefixed payload, free the pointer,
     * and return the raw payload bytes.
     */
    public static byte[] astBin(String cxStr) {
        return callBinFn(LIB::cx_to_ast_bin, cxStr);
    }

    /**
     * Call cx_to_events_bin, read the length-prefixed payload, free the pointer,
     * and return the raw payload bytes.
     */
    public static byte[] eventsBin(String cxStr) {
        return callBinFn(LIB::cx_to_events_bin, cxStr);
    }

    /**
     * Call cx_to_data_bin and return the CXDB v1 PAYLOAD (the [u32 LE size]
     * frame is stripped by callBinFn). Pass the result to {@link DataBin#decode}.
     */
    public static byte[] toDataBin(String cxStr) {
        return callBinFn(LIB::cx_to_data_bin, cxStr);
    }

    /**
     * Call cx_select_all_paths and decode the framed [u32 size][u32 n_paths][...]
     * blob into a list of structural paths. Each path is an int[] of
     * 0-based indices: first into Document.elements, subsequent into
     * Element.items. Match order is preorder (same as cx_select_all).
     * See spec/abi.md §2.7.
     */
    public static List<int[]> selectAllPaths(String cxText, String expr) {
        PointerByReference errRef = new PointerByReference();
        Pointer out = LIB.cx_select_all_paths(cxText, expr, errRef);
        if (out == null) {
            Pointer ep  = errRef.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "unknown error";
            if (ep != null) LIB.cx_free(ep);
            // Bad CXPath expression or bad CX input — both are caller bugs.
            throw new IllegalArgumentException(msg);
        }
        byte[] sizeBytes = out.getByteArray(0, 4);
        int payloadSize = ByteBuffer.wrap(sizeBytes).order(ByteOrder.LITTLE_ENDIAN).getInt();
        byte[] payload = out.getByteArray(4, payloadSize);
        LIB.cx_free(out);
        ByteBuffer bb = ByteBuffer.wrap(payload).order(ByteOrder.LITTLE_ENDIAN);
        int nPaths = bb.getInt();
        List<int[]> paths = new java.util.ArrayList<>(nPaths);
        for (int i = 0; i < nPaths; i++) {
            int depth = bb.getInt();
            int[] path = new int[depth];
            for (int k = 0; k < depth; k++) path[k] = bb.getInt();
            paths.add(path);
        }
        return paths;
    }

    // ── Phase 5 / CB-1 — ast_bin → text format ──────────────────────────────

    private static String astBinToText(java.util.function.BiFunction<byte[], PointerByReference, Pointer> fn,
                                       byte[] framed) {
        if (framed == null || framed.length == 0) {
            throw new RuntimeException("ast_bin_to_*: empty input");
        }
        PointerByReference errRef = new PointerByReference();
        Pointer out = fn.apply(framed, errRef);
        if (out == null) {
            Pointer ep  = errRef.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "unknown error";
            if (ep != null) LIB.cx_free(ep);
            throw new RuntimeException(msg);
        }
        String s = out.getString(0);
        LIB.cx_free(out);
        return s;
    }

    public static String astBinToCx  (byte[] framed) { return astBinToText(LIB::cx_ast_bin_to_cx,   framed); }
    public static String astBinToXml (byte[] framed) { return astBinToText(LIB::cx_ast_bin_to_xml,  framed); }
    public static String astBinToJson(byte[] framed) { return astBinToText(LIB::cx_ast_bin_to_json, framed); }
    public static String astBinToYaml(byte[] framed) { return astBinToText(LIB::cx_ast_bin_to_yaml, framed); }
    public static String astBinToToml(byte[] framed) { return astBinToText(LIB::cx_ast_bin_to_toml, framed); }
    public static String astBinToMd  (byte[] framed) { return astBinToText(LIB::cx_ast_bin_to_md,   framed); }

    // ── Phase 5 / CB-2 — text → ast_bin (frame stripped) ────────────────────

    public static byte[] xmlToAstBin (String input) { return callBinFn(LIB::cx_xml_to_ast_bin,  input); }
    public static byte[] jsonToAstBin(String input) { return callBinFn(LIB::cx_json_to_ast_bin, input); }
    public static byte[] yamlToAstBin(String input) { return callBinFn(LIB::cx_yaml_to_ast_bin, input); }
    public static byte[] tomlToAstBin(String input) { return callBinFn(LIB::cx_toml_to_ast_bin, input); }
    public static byte[] mdToAstBin  (String input) { return callBinFn(LIB::cx_md_to_ast_bin,   input); }

    // ── data_bin one-shot loaders/dumpers (Phase 7.28; spec/abi.md §2.4–§2.5) ─

    /** Encode XML text to CXDB v1 PAYLOAD bytes (frame stripped). */
    public static byte[] xmlToDataBin (String input) { return callBinFn(LIB::cx_xml_to_data_bin,  input); }
    /** Encode JSON text to CXDB v1 PAYLOAD bytes (frame stripped). */
    public static byte[] jsonToDataBin(String input) { return callBinFn(LIB::cx_json_to_data_bin, input); }
    /** Encode YAML text to CXDB v1 PAYLOAD bytes (frame stripped). */
    public static byte[] yamlToDataBin(String input) { return callBinFn(LIB::cx_yaml_to_data_bin, input); }
    /** Encode TOML text to CXDB v1 PAYLOAD bytes (frame stripped). */
    public static byte[] tomlToDataBin(String input) { return callBinFn(LIB::cx_toml_to_data_bin, input); }
    /** Encode Markdown text to CXDB v1 PAYLOAD bytes (frame stripped). */
    public static byte[] mdToDataBin  (String input) { return callBinFn(LIB::cx_md_to_data_bin,   input); }

    /** Decode FRAMED CXDB v1 bytes to XML text. */
    public static String dataBinToXml (byte[] framed) { return astBinToText(LIB::cx_data_bin_to_xml,  framed); }
    /** Decode FRAMED CXDB v1 bytes to JSON text. */
    public static String dataBinToJson(byte[] framed) { return astBinToText(LIB::cx_data_bin_to_json, framed); }
    /** Decode FRAMED CXDB v1 bytes to YAML text. */
    public static String dataBinToYaml(byte[] framed) { return astBinToText(LIB::cx_data_bin_to_yaml, framed); }
    /** Decode FRAMED CXDB v1 bytes to TOML text. */
    public static String dataBinToToml(byte[] framed) { return astBinToText(LIB::cx_data_bin_to_toml, framed); }
    /** Decode FRAMED CXDB v1 bytes to Markdown text. */
    public static String dataBinToMd  (byte[] framed) { return astBinToText(LIB::cx_data_bin_to_md,   framed); }

    // ── Phase 5 / CB-4 — events handle API (used by EventStream) ─────────────

    static Pointer eventsOpen(String input, PointerByReference errOut) {
        return LIB.cx_events_open(input, errOut);
    }
    static Pointer eventsNext(Pointer handle, PointerByReference errOut) {
        return LIB.cx_events_next(handle, errOut);
    }
    static void eventsClose(Pointer handle) { LIB.cx_events_close(handle); }
    static void cxFree(Pointer p) { LIB.cx_free(p); }

    // ── Phase 6 / canonical-form tooling (spec/abi.md §2.6) ──────────────────

    /** Lossless canonical text CX. Preserves comments/anchors; normalizes
     *  presentation. Idempotent: fmt(fmt(x)).equals(fmt(x)). */
    public static String fmt(String input)       { return callFn(LIB::cx_fmt,       input); }

    /** Strict canonical text CX. */
    public static String canonical(String input) { return callFn(LIB::cx_canonical, input); }

    /** SHA-256 hex (64 lowercase hex chars) of the strict canonical bytes. */
    public static String hash(String input)      { return callFn(LIB::cx_hash,      input); }

    /** True iff strict-canonical(a) equals strict-canonical(b). */
    public static boolean eq(String a, String b) {
        PointerByReference errRef = new PointerByReference();
        Pointer out = LIB.cx_eq(a, b, errRef);
        if (out == null) {
            Pointer ep  = errRef.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "unknown error";
            if (ep != null) LIB.cx_free(ep);
            throw new RuntimeException(msg);
        }
        String s = out.getString(0);
        LIB.cx_free(out);
        return s.equals("1");
    }

    /**
     * Semantic diff between two CX inputs, walking the strict-canonical
     * forms. {@code format} is {@code "unified"}, {@code "json"}, or
     * {@code "summary"}. Empty result means data-equivalent.
     *
     * <p>Per spec/decisions/0012-cx-diff.md.
     */
    public static String diff(String a, String b, String format) {
        PointerByReference errRef = new PointerByReference();
        Pointer out = LIB.cx_diff(a, b, format, errRef);
        if (out == null) {
            Pointer ep  = errRef.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "unknown error";
            if (ep != null) LIB.cx_free(ep);
            throw new RuntimeException(msg);
        }
        String s = out.getString(0);
        LIB.cx_free(out);
        return s;
    }

    /**
     * Style + correctness warnings. {@code format} is {@code "text"},
     * {@code "json"}, or {@code "summary"}. {@code disabled} is a
     * comma-separated list of check IDs to suppress (empty string runs
     * all). Empty result means no findings.
     *
     * <p>Per spec/decisions/0013-cx-lint.md.
     */
    public static String lint(String input, String format, String disabled) {
        PointerByReference errRef = new PointerByReference();
        Pointer out = LIB.cx_lint(input, format, disabled, errRef);
        if (out == null) {
            Pointer ep  = errRef.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "unknown error";
            if (ep != null) LIB.cx_free(ep);
            throw new RuntimeException(msg);
        }
        String s = out.getString(0);
        LIB.cx_free(out);
        return s;
    }

    // ── Phase 7.65 — ID/IDREF C ABI (ADR 0003) ───────────────────────────────

    /**
     * Find the element declaring {@code id} in {@code input} and return
     * its AST-JSON encoding. Returns the empty string when no element
     * declares that ID. Throws {@link RuntimeException} on parse error.
     */
    public static String idLookup(String input, String id) {
        PointerByReference errRef = new PointerByReference();
        Pointer out = LIB.cx_id_lookup(input, id, errRef);
        if (out == null) {
            Pointer ep  = errRef.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "unknown error";
            if (ep != null) LIB.cx_free(ep);
            throw new RuntimeException(msg);
        }
        String s = out.getString(0);
        LIB.cx_free(out);
        return s;
    }

    /**
     * Resolve {@code ref} to the element declaring that ID and return
     * its AST-JSON encoding. Observationally equivalent to
     * {@link #idLookup}; provided for vocabulary clarity.
     */
    public static String resolveRef(String input, String ref) {
        PointerByReference errRef = new PointerByReference();
        Pointer out = LIB.cx_resolve_ref(input, ref, errRef);
        if (out == null) {
            Pointer ep  = errRef.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "unknown error";
            if (ep != null) LIB.cx_free(ep);
            throw new RuntimeException(msg);
        }
        String s = out.getString(0);
        LIB.cx_free(out);
        return s;
    }

    /**
     * Run CXPath {@code cxpath} on {@code input} and return the
     * syntactic ID of the matched element. Returns the empty string
     * when no element matched or the matched element has no ID.
     */
    public static String nodeId(String input, String cxpath) {
        PointerByReference errRef = new PointerByReference();
        Pointer out = LIB.cx_node_id(input, cxpath, errRef);
        if (out == null) {
            Pointer ep  = errRef.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "unknown error";
            if (ep != null) LIB.cx_free(ep);
            throw new RuntimeException(msg);
        }
        String s = out.getString(0);
        LIB.cx_free(out);
        return s;
    }

    // ── Phase 7.68 — Delimited (CSV/TSV/PSV/arbitrary) C ABI (ADR 0001) ──────

    private static String callDelimFn(
            DelimNativeFn fn, String input, byte delim) {
        PointerByReference errRef = new PointerByReference();
        Pointer out = fn.apply(input, delim, errRef);
        if (out == null) {
            Pointer ep  = errRef.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "unknown error";
            if (ep != null) LIB.cx_free(ep);
            throw new RuntimeException(msg);
        }
        String s = out.getString(0);
        LIB.cx_free(out);
        return s;
    }

    @FunctionalInterface
    private interface DelimNativeFn {
        Pointer apply(String input, byte delim, PointerByReference errOut);
    }

    /** Emit canonical CX text as delimited text using the given single-byte delimiter. */
    public static String toDelimited(String input, char delim) {
        return callDelimFn(LIB::cx_to_delimited, input, (byte) delim);
    }

    /** Parse delimited text with the given single-byte delimiter into canonical CX text. */
    public static String fromDelimited(String input, char delim) {
        return callDelimFn(LIB::cx_from_delimited, input, (byte) delim);
    }

    public static String toCsv  (String input) { return callFn(LIB::cx_to_csv,   input); }
    public static String fromCsv(String input) { return callFn(LIB::cx_from_csv, input); }
    public static String toTsv  (String input) { return callFn(LIB::cx_to_tsv,   input); }
    public static String fromTsv(String input) { return callFn(LIB::cx_from_tsv, input); }
    public static String toPsv  (String input) { return callFn(LIB::cx_to_psv,   input); }
    public static String fromPsv(String input) { return callFn(LIB::cx_from_psv, input); }

    /** Encode CSV text to CXDB v1 PAYLOAD bytes (frame stripped). */
    public static byte[] csvToDataBin(String input) { return callBinFn(LIB::cx_csv_to_data_bin, input); }
    /** Encode TSV text to CXDB v1 PAYLOAD bytes (frame stripped). */
    public static byte[] tsvToDataBin(String input) { return callBinFn(LIB::cx_tsv_to_data_bin, input); }
    /** Encode PSV text to CXDB v1 PAYLOAD bytes (frame stripped). */
    public static byte[] psvToDataBin(String input) { return callBinFn(LIB::cx_psv_to_data_bin, input); }

    /** Decode FRAMED CXDB v1 bytes to CSV text. */
    public static String dataBinToCsv(byte[] framed) { return astBinToText(LIB::cx_data_bin_to_csv, framed); }
    /** Decode FRAMED CXDB v1 bytes to TSV text. */
    public static String dataBinToTsv(byte[] framed) { return astBinToText(LIB::cx_data_bin_to_tsv, framed); }
    /** Decode FRAMED CXDB v1 bytes to PSV text. */
    public static String dataBinToPsv(byte[] framed) { return astBinToText(LIB::cx_data_bin_to_psv, framed); }

    /**
     * Call cx_from_data_bin with FRAMED CXDB v1 bytes (as returned by
     * {@link DataBin#encode}) and return the canonical CX text.
     */
    public static String fromDataBin(byte[] framed) {
        if (framed == null || framed.length == 0) {
            throw new RuntimeException("cx_from_data_bin: empty input");
        }
        PointerByReference errRef = new PointerByReference();
        Pointer out = LIB.cx_from_data_bin(framed, errRef);
        if (out == null) {
            Pointer ep  = errRef.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "unknown error";
            if (ep != null) LIB.cx_free(ep);
            throw new RuntimeException(msg);
        }
        String s = out.getString(0);
        LIB.cx_free(out);
        return s;
    }

    private static byte[] callBinFn(
            BiFunction<String, PointerByReference, Pointer> fn,
            String input) {
        PointerByReference errRef = new PointerByReference();
        Pointer out = fn.apply(input, errRef);
        if (out == null) {
            Pointer ep  = errRef.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "unknown error";
            if (ep != null) LIB.cx_free(ep);
            throw new RuntimeException(msg);
        }
        // Buffer layout: [u32 LE: payload_size][payload bytes]
        byte[] sizeBytes = out.getByteArray(0, 4);
        int payloadSize = ByteBuffer.wrap(sizeBytes).order(ByteOrder.LITTLE_ENDIAN).getInt();
        byte[] payload = out.getByteArray(4, payloadSize);
        LIB.cx_free(out);
        return payload;
    }

    // ── Phase 7.72 — chunked-table one-shot (ADR 0015 D8) ───────────────────

    /**
     * Encode CX text whose root is a single :table-bodied element to the
     * CXDB chunked-table form. Returns the FRAMED buffer
     * {@code [u32 LE size][payload]} (consumable by
     * {@link #fromDataBin} or {@link TableReader}).
     *
     * <p>Differs from the other "to data_bin" wrappers by returning the
     * full framed buffer rather than just the payload — chunked-table
     * downstream consumers expect to see the framing.
     */
    public static byte[] toDataBinChunked(String input) {
        PointerByReference errRef = new PointerByReference();
        Pointer out = LIB.cx_to_data_bin_chunked(input, errRef);
        if (out == null) {
            Pointer ep  = errRef.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "unknown error";
            if (ep != null) LIB.cx_free(ep);
            throw new RuntimeException(msg);
        }
        byte[] sizeBytes = out.getByteArray(0, 4);
        int payloadSize = ByteBuffer.wrap(sizeBytes).order(ByteOrder.LITTLE_ENDIAN).getInt();
        byte[] framed = out.getByteArray(0, 4 + payloadSize);
        LIB.cx_free(out);
        return framed;
    }

    // ── Phase 7.73 — schema-driven CXDB encoding (ADR 0015 D3) ──────────────

    @FunctionalInterface
    private interface SchemaDrivenLoaderFn {
        Pointer apply(String input, String schema, int refForm, String nameHint,
                      PointerByReference errOut);
    }

    private static byte[] callSchemaDrivenLoader(SchemaDrivenLoaderFn fn,
                                                 String input, String schema,
                                                 int refForm, String nameHint) {
        if (refForm < 0 || refForm > 2) {
            throw new IllegalArgumentException(
                "refForm must be 0 (hash-only), 1 (inline), or 2 (hash+name)");
        }
        PointerByReference errRef = new PointerByReference();
        Pointer out = fn.apply(input, schema, refForm, nameHint, errRef);
        if (out == null) {
            Pointer ep  = errRef.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "unknown error";
            if (ep != null) LIB.cx_free(ep);
            throw new RuntimeException(msg);
        }
        byte[] sizeBytes = out.getByteArray(0, 4);
        int payloadSize = ByteBuffer.wrap(sizeBytes).order(ByteOrder.LITTLE_ENDIAN).getInt();
        byte[] framed = out.getByteArray(0, 4 + payloadSize);
        LIB.cx_free(out);
        return framed;
    }

    public static byte[] toDataBinSchemaDriven    (String input, String schema, int refForm, String nameHint) {
        return callSchemaDrivenLoader(LIB::cx_to_data_bin_schema_driven,      input, schema, refForm, nameHint);
    }
    public static byte[] xmlToDataBinSchemaDriven (String input, String schema, int refForm, String nameHint) {
        return callSchemaDrivenLoader(LIB::cx_xml_to_data_bin_schema_driven,  input, schema, refForm, nameHint);
    }
    public static byte[] jsonToDataBinSchemaDriven(String input, String schema, int refForm, String nameHint) {
        return callSchemaDrivenLoader(LIB::cx_json_to_data_bin_schema_driven, input, schema, refForm, nameHint);
    }
    public static byte[] yamlToDataBinSchemaDriven(String input, String schema, int refForm, String nameHint) {
        return callSchemaDrivenLoader(LIB::cx_yaml_to_data_bin_schema_driven, input, schema, refForm, nameHint);
    }
    public static byte[] tomlToDataBinSchemaDriven(String input, String schema, int refForm, String nameHint) {
        return callSchemaDrivenLoader(LIB::cx_toml_to_data_bin_schema_driven, input, schema, refForm, nameHint);
    }
    public static byte[] mdToDataBinSchemaDriven  (String input, String schema, int refForm, String nameHint) {
        return callSchemaDrivenLoader(LIB::cx_md_to_data_bin_schema_driven,   input, schema, refForm, nameHint);
    }
    public static byte[] csvToDataBinSchemaDriven (String input, String schema, int refForm, String nameHint) {
        return callSchemaDrivenLoader(LIB::cx_csv_to_data_bin_schema_driven,  input, schema, refForm, nameHint);
    }
    public static byte[] tsvToDataBinSchemaDriven (String input, String schema, int refForm, String nameHint) {
        return callSchemaDrivenLoader(LIB::cx_tsv_to_data_bin_schema_driven,  input, schema, refForm, nameHint);
    }
    public static byte[] psvToDataBinSchemaDriven (String input, String schema, int refForm, String nameHint) {
        return callSchemaDrivenLoader(LIB::cx_psv_to_data_bin_schema_driven,  input, schema, refForm, nameHint);
    }

    /** Decode a FRAMED schema-driven CXDB buffer back to canonical CX text.
     *  Pass {@code ""} for {@code schemaHint} to use only the embedded
     *  reference's resolution. */
    public static String fromDataBinSchemaDriven(byte[] framed, String schemaHint) {
        if (framed == null || framed.length == 0) {
            throw new RuntimeException("cx_from_data_bin_schema_driven: empty input");
        }
        PointerByReference errRef = new PointerByReference();
        Pointer out = LIB.cx_from_data_bin_schema_driven(framed, schemaHint, errRef);
        if (out == null) {
            Pointer ep  = errRef.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "unknown error";
            if (ep != null) LIB.cx_free(ep);
            throw new RuntimeException(msg);
        }
        String s = out.getString(0);
        LIB.cx_free(out);
        return s;
    }

    // ── Phase 7.74a — streaming Table handle internals (used by TableReader/Writer) ─

    static Pointer tableReaderOpen   (byte[] dataBin, PointerByReference err) { return LIB.cx_table_reader_open    (dataBin, err); }
    static Pointer tableReaderOpenFd (int fd,         PointerByReference err) { return LIB.cx_table_reader_open_fd (fd, err); }
    static Pointer tableReaderSchema (Pointer h,      PointerByReference err) { return LIB.cx_table_reader_schema  (h, err); }
    static Pointer tableReaderNext   (Pointer h,      PointerByReference err) { return LIB.cx_table_reader_next    (h, err); }
    static void    tableReaderClose  (Pointer h)                              { LIB.cx_table_reader_close          (h); }

    static Pointer tableWriterOpen           (byte[] colSpec, PointerByReference err) { return LIB.cx_table_writer_open           (colSpec, err); }
    static Pointer tableWriterOpenFd         (byte[] colSpec, int fd, PointerByReference err) { return LIB.cx_table_writer_open_fd(colSpec, fd, err); }
    static Pointer tableWriterEmitRowGroup   (Pointer h, byte[] payload, PointerByReference err) { return LIB.cx_table_writer_emit_row_group(h, payload, err); }
    static Pointer tableWriterCloseGetBytes  (Pointer h, PointerByReference err) { return LIB.cx_table_writer_close_get_bytes(h, err); }
    static void    tableWriterClose          (Pointer h)                              { LIB.cx_table_writer_close          (h); }

    // ── Phase 7.74i — streaming-write handle internals (used by EventWriter) ───

    static Pointer eventsWriterOpen        (String fmt, PointerByReference err)       { return LIB.cx_events_writer_open(fmt, err); }
    static Pointer eventsWriterOpenFd      (String fmt, int fd, PointerByReference err){ return LIB.cx_events_writer_open_fd(fmt, fd, err); }
    static Pointer eventsWriterCloseGetBytes(Pointer h, PointerByReference err)       { return LIB.cx_events_writer_close_get_bytes(h, err); }
    static void    eventsWriterClose       (Pointer h)                                { LIB.cx_events_writer_close(h); }
    static Pointer eventsWriterStartDoc    (Pointer h, PointerByReference err)        { return LIB.cx_events_writer_start_doc(h, err); }
    static Pointer eventsWriterEndDoc      (Pointer h, PointerByReference err)        { return LIB.cx_events_writer_end_doc(h, err); }
    static Pointer eventsWriterStartElementWithLen(Pointer h, String name, String anchor, String dataType, String merge,
                                                   byte[] attrs, long attrsLen, PointerByReference err) {
        return LIB.cx_events_writer_start_element_with_len(h, name, anchor, dataType, merge, attrs, attrsLen, err);
    }
    static Pointer eventsWriterEndElement  (Pointer h, String name, PointerByReference err) { return LIB.cx_events_writer_end_element(h, name, err); }
    static Pointer eventsWriterText        (Pointer h, String v, PointerByReference err)    { return LIB.cx_events_writer_text(h, v, err); }
    static Pointer eventsWriterScalar      (Pointer h, String dt, String v, PointerByReference err) { return LIB.cx_events_writer_scalar(h, dt, v, err); }
    static Pointer eventsWriterComment     (Pointer h, String v, PointerByReference err)    { return LIB.cx_events_writer_comment(h, v, err); }
    static Pointer eventsWriterPi          (Pointer h, String t, String d, PointerByReference err) { return LIB.cx_events_writer_pi(h, t, d, err); }
    static Pointer eventsWriterEntityRef   (Pointer h, String n, PointerByReference err)    { return LIB.cx_events_writer_entity_ref(h, n, err); }
    static Pointer eventsWriterRawText     (Pointer h, String v, PointerByReference err)    { return LIB.cx_events_writer_raw_text(h, v, err); }
    static Pointer eventsWriterAlias       (Pointer h, String n, PointerByReference err)    { return LIB.cx_events_writer_alias(h, n, err); }
    static Pointer eventsWriterStartTableWithLen(Pointer h, byte[] cs, long csLen, PointerByReference err) {
        return LIB.cx_events_writer_start_table_with_len(h, cs, csLen, err);
    }
    static Pointer eventsWriterRowGroupWithLen(Pointer h, byte[] rg, long rgLen, PointerByReference err) {
        return LIB.cx_events_writer_row_group_with_len(h, rg, rgLen, err);
    }
    static Pointer eventsWriterEndTable    (Pointer h, PointerByReference err) { return LIB.cx_events_writer_end_table(h, err); }

    // ── Phase 7.74d — schema validator (ADR 0009 / spec/abi.md §2.13) ──────
    //
    // The C ABI returns a framed binary diagnostics payload:
    //
    //   [u32 LE total_size]
    //   [u32 LE diag_count]
    //   diagnostic* {
    //     [u32 line] [u32 col]
    //     [u8 prefix]                    // 'S'/'W'/'D'; 0x00 = no prefix
    //     [u32 error_code]
    //     [u8 severity]                  // 0=info, 1=warn, 2=error
    //     [u32 message_len] [message_utf8]
    //   }
    //
    // The prefix byte is the ASCII rule-code namespace tag — `S` for the
    // schema validator, `W` for streaming-write (ADR 0011), `D` for the
    // future data validator. Bindings render the public Code string as
    // `<prefix><numeric:%03d>` (e.g. "S006", "W001"); a 0x00 prefix
    // renders the numeric without a letter. See spec/abi.md §2.13 /
    // spec/schema.md §10.2.

    /**
     * Validate {@code doc} against {@code schema}. Schema-load errors
     * (missing schema-of, unknown anchor, etc.) surface as a single
     * error-severity Diagnostic in the returned report, not as an
     * exception. Throws only when the document text itself is
     * malformed CX.
     */
    public static ValidationReport validate(String doc, String schema) {
        byte[] docBytes    = doc   .getBytes(java.nio.charset.StandardCharsets.UTF_8);
        byte[] schemaBytes = schema.getBytes(java.nio.charset.StandardCharsets.UTF_8);
        PointerByReference errRef = new PointerByReference();
        Pointer raw = LIB.cx_validate_with_len(
                docBytes, docBytes.length,
                schemaBytes, schemaBytes.length,
                errRef);
        java.util.List<Diagnostic> diags = extractValidatorDiagnostics(raw, errRef);
        return new ValidationReport(diags, "");
    }

    /**
     * Validate {@code doc} against {@code schema} and additionally
     * apply schema-driven defaults. The returned report's
     * {@link ValidationReport#modifiedDoc} carries the canonical CX
     * text with defaults inserted (empty when the schema declares no
     * defaults).
     */
    public static ValidationReport validateWithDefaults(String doc, String schema) {
        byte[] docBytes    = doc   .getBytes(java.nio.charset.StandardCharsets.UTF_8);
        byte[] schemaBytes = schema.getBytes(java.nio.charset.StandardCharsets.UTF_8);
        PointerByReference modifiedRef = new PointerByReference();
        PointerByReference errRef      = new PointerByReference();
        Pointer raw = LIB.cx_validate_apply_defaults_with_len(
                docBytes, docBytes.length,
                schemaBytes, schemaBytes.length,
                modifiedRef, errRef);
        java.util.List<Diagnostic> diags = extractValidatorDiagnostics(raw, errRef);
        String modified = "";
        Pointer mp = modifiedRef.getValue();
        if (mp != null) {
            modified = mp.getString(0);
            LIB.cx_free(mp);
        }
        return new ValidationReport(diags, modified);
    }

    private static java.util.List<Diagnostic> extractValidatorDiagnostics(
            Pointer raw, PointerByReference errRef) {
        if (raw == null) {
            Pointer ep  = errRef.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "cx_validate: unknown error";
            if (ep != null) LIB.cx_free(ep);
            throw new RuntimeException(msg);
        }
        // Header: [u32 LE total_size] then payload.
        byte[] sizeBytes = raw.getByteArray(0, 4);
        int totalSize = ByteBuffer.wrap(sizeBytes).order(ByteOrder.LITTLE_ENDIAN).getInt();
        byte[] payload = raw.getByteArray(4, totalSize);
        LIB.cx_free(raw);
        return parseDiagnostics(payload);
    }

    private static java.util.List<Diagnostic> parseDiagnostics(byte[] payload) {
        java.util.List<Diagnostic> diags = new java.util.ArrayList<>();
        if (payload.length < 4) return diags;
        ByteBuffer bb = ByteBuffer.wrap(payload).order(ByteOrder.LITTLE_ENDIAN);
        long count = bb.getInt() & 0xFFFFFFFFL;
        for (long i = 0; i < count; i++) {
            if (bb.remaining() < 18) break;
            long line   = bb.getInt() & 0xFFFFFFFFL;
            long col    = bb.getInt() & 0xFFFFFFFFL;
            int  prefix = bb.get() & 0xFF;
            long code   = bb.getInt() & 0xFFFFFFFFL;
            int  sev    = bb.get() & 0xFF;
            int  mlen   = bb.getInt();
            if (mlen < 0 || bb.remaining() < mlen) break;
            byte[] msgBytes = new byte[mlen];
            bb.get(msgBytes);
            String msg = new String(msgBytes, java.nio.charset.StandardCharsets.UTF_8);
            String codeStr = formatCode(prefix, code);
            Severity severity = Severity.fromU8(sev);
            diags.add(new Diagnostic(codeStr, severity, msg, line, col));
        }
        return diags;
    }

    /**
     * Renders a diagnostic code from the wire-format prefix byte + numeric.
     * Prefix is the ASCII namespace tag ('S'/'W'/'D'); 0x00 means
     * "namespace unspecified" — render numeric only.
     * See spec/abi.md §2.13 / spec/schema.md §10.2.
     */
    private static String formatCode(int prefix, long numeric) {
        if (prefix == 0) return String.format("%03d", numeric);
        return String.format("%c%03d", (char) prefix, numeric);
    }
}
