#ifndef CX_H
#define CX_H

#ifdef __cplusplus
extern "C" {
#endif

/*
 * CX C API — implemented in V (vcx/)
 *
 * Grammar v3.4 / AST v2.4 (ast_bin v8 at v0.8.0).
 * All 6×7 input/output format combinations (6 input formats × 7 outputs
 * including AST) plus cx_free and cx_version. Plus the CX code
 * evaluator (cx_code_eval family, cap bit 28), program diagram /
 * tree (cap bits 31 / 32), atoms (cap bit 33),
 * [?def] module-level functions (cap bit 34), [?lib]
 * module loading (cap bit 35), and PathNode wire format
 * (cap bit 36). See spec/abi.md §3 for the full
 * capability bitmask and spec/abi.md §2 for the symbol catalog.
 *
 * v3.4 grammar additions: numeric underscores (1_000_000), leading-zero
 * tightening (BREAKING — '02134' is now Text), sized numeric type names
 * (i8..i64, u8..u64, f16/f32/f64, decimal, bigint), line comments
 * (# to end-of-line at comment-eligible positions), boolean attribute
 * sigils (+name / -name), and logfmt mode (top-level Attribute+
 * documents). Full spec: spec/grammar.ebnf v3.4.
 *
 * Calling convention:
 *   - input   must be a NUL-terminated UTF-8 string; must not be NULL.
 *   - err_out may be NULL if you don't need error details.
 *   - On success: returns a heap-allocated, NUL-terminated UTF-8 string.
 *   - On error:   returns NULL; if err_out is non-NULL sets *err_out to a
 *                 heap-allocated error message string.
 *   - All returned strings (including *err_out) must be released with
 *     cx_free(). Never pass them to the system free().
 *
 * Thread safety: all conversion functions are stateless — safe to call from
 * multiple threads concurrently without synchronisation.
 *
 * Formats: cx  xml  json (semantic)  yaml  toml
 * AST output: cx_to_ast / cx_*_to_ast — full parse tree as JSON
 */

/* ── CX input ──────────────────────────────────────────────────────────────── */

char* cx_to_cx         (const char* input, char** err_out);
char* cx_to_cx_compact (const char* input, char** err_out);
char* cx_to_xml (const char* input, char** err_out);
char* cx_to_ast (const char* input, char** err_out);
char* cx_to_json(const char* input, char** err_out);
char* cx_to_yaml(const char* input, char** err_out);
char* cx_to_toml(const char* input, char** err_out);

/* ── XML input ─────────────────────────────────────────────────────────────── */

char* cx_xml_to_cx  (const char* input, char** err_out);
char* cx_xml_to_xml (const char* input, char** err_out);
char* cx_xml_to_ast (const char* input, char** err_out);
char* cx_xml_to_json(const char* input, char** err_out);
char* cx_xml_to_yaml(const char* input, char** err_out);
char* cx_xml_to_toml(const char* input, char** err_out);

/* ── JSON input ────────────────────────────────────────────────────────────── */

char* cx_json_to_cx  (const char* input, char** err_out);
char* cx_json_to_xml (const char* input, char** err_out);
char* cx_json_to_ast (const char* input, char** err_out);
char* cx_json_to_json(const char* input, char** err_out);
char* cx_json_to_yaml(const char* input, char** err_out);
char* cx_json_to_toml(const char* input, char** err_out);

/* ── YAML input ────────────────────────────────────────────────────────────── */

char* cx_yaml_to_cx  (const char* input, char** err_out);
char* cx_yaml_to_xml (const char* input, char** err_out);
char* cx_yaml_to_ast (const char* input, char** err_out);
char* cx_yaml_to_json(const char* input, char** err_out);
char* cx_yaml_to_yaml(const char* input, char** err_out);
char* cx_yaml_to_toml(const char* input, char** err_out);

/* ── TOML input ────────────────────────────────────────────────────────────── */

char* cx_toml_to_cx  (const char* input, char** err_out);
char* cx_toml_to_xml (const char* input, char** err_out);
char* cx_toml_to_ast (const char* input, char** err_out);
char* cx_toml_to_json(const char* input, char** err_out);
char* cx_toml_to_yaml(const char* input, char** err_out);
char* cx_toml_to_toml(const char* input, char** err_out);

/* ── AST input ─────────────────────────────────────────────────────────────── */

/** Convert AST JSON (output of cx_to_ast / cx_*_to_ast) back to canonical CX. */
char* cx_ast_to_cx (const char* input, char** err_out);

/* ── memory ────────────────────────────────────────────────────────────────── */

/** Free any string returned by this library. */
void cx_free(char* s);

/* ── thread initialization (capability bit 26; spec/abi.md §1.6) ───────────── */

/**
 * cx_init: process-level thread-init handshake. Idempotent — bindings
 * call once at module load. Enables host-thread registration in libcx's
 * Boehm GC. Always returns 0 (no failure mode at this layer).
 *
 * Mandatory for every binding. Bindings whose host runtime spawns OS
 * threads outside V's control (Rust, C#, Java, ...) MUST also call
 * cx_thread_register on each such thread before any other cx_* call;
 * see §1.6.
 */
int cx_init(void);

/**
 * cx_thread_register: per-thread registration with libcx's GC. Required
 * for every non-V-spawned thread that will call into libcx; harmless
 * (returns 0 as DUPLICATE) on V/Python(GIL)/Go(cgo-serialised) threads.
 * Returns 0 on success or duplicate-registration; -1 on real failure.
 */
int cx_thread_register(void);

/**
 * cx_thread_unregister: optional cleanup at thread exit. Bindings that
 * have a thread-exit hook (Rust Drop, C# AppDomain unload) may call
 * this; otherwise libgc cleans up registered threads at process exit.
 * Returns 0 on success, -1 on failure.
 */
int cx_thread_unregister(void);

/** Return the library version string (e.g. "0.5.0"). Caller must cx_free(). */
char* cx_version(void);

/** Return the ABI version string (e.g. "2.0"). Bindings call this on
 *  load and refuse mismatched majors per spec/abi.md §1.1. Caller must cx_free(). */
char* cx_abi_version(void);

/** Return the capability bitmask as a NUL-terminated lowercase hex
 *  string. Bit assignments per spec/abi.md §3. Caller must cx_free().
 *
 *  Each bit indicates an implemented capability. Bindings examine
 *  the bitmask at load time and either degrade gracefully or refuse
 *  to load when a required capability is absent. */
char* cx_features(void);

/* ── Streaming ─────────────────────────────────────────────────────────────── */

/**
 * cx_to_events: parse CX input and return all streaming events as a JSON array.
 * Retained for tooling use. Language bindings should use cx_to_events_bin.
 */
char* cx_to_events(const char* input, char** err_out);

/* ── Binary protocol ───────────────────────────────────────────────────────── */

/**
 * cx_to_events_bin / cx_to_ast_bin: binary wire format for streaming events
 * and AST. Faster than the JSON equivalents (~2.5× encode, ~3.5× decode).
 *
 * Return format: [u32 LE: payload_size][payload bytes]
 * Read the first 4 bytes as a little-endian uint32 to get payload_size, then
 * read that many bytes. Free the entire buffer with cx_free().
 * The buffer is NOT a null-terminated string — it is binary data.
 *
 * cx_to_events_bin payload:
 *   [u32 LE: event_count] [events...]
 *   Each event: [u8: type_id] [payload per type]
 *   Type IDs: 0x01=StartDoc 0x02=EndDoc 0x03=StartElement 0x04=EndElement
 *             0x05=Text 0x06=Scalar 0x07=Comment 0x08=PI
 *             0x09=EntityRef 0x0A=RawText 0x0B=Alias
 *   Strings: [u32 LE: byte_len][bytes]  OptStrings: [u8: 0|1][str if 1]
 *   StartElement: str:name optstr:anchor optstr:data_type optstr:merge
 *                 u16:attr_count attrs[]
 *   Attr: str:name str:value optstr:data_type
 *
 * cx_to_ast_bin payload:
 *   [u8: version=1] [u16 LE: prolog_count] [prolog nodes...]
 *   [u16 LE: element_count] [element nodes...]
 *   Node type IDs: 0x01=Element 0x02=Text 0x03=Scalar 0x04=Comment
 *                  0x05=RawText 0x06=EntityRef 0x07=Alias 0x08=PI
 *                  0x09=XMLDecl 0x0A=CXDirective 0x0C=BlockContent 0xFF=skip
 *   Element: str:name optstr:anchor optstr:data_type optstr:merge
 *            u16:attr_count attrs[] u16:child_count nodes[]
 *
 * ast_bin v7 (capability bit 33 / 0x200000000): the Scalar
 * (0x03) node and Attr's `optstr:data_type` slot gain a new discriminator
 * value "atom" — surface syntax `:NAME` — whose value field is the
 * atom's UTF-8 name. Atoms are name-equality, type-strict (no coercion
 * with string). Wire byte 0x12 is reserved for a future compact
 * flattened atom encoding; v0.8.0 producers MUST NOT emit it and v7
 * decoders MUST reject buffers containing it. v6 readers MUST reject
 * v7 files. Reserved names `:true` / `:false` / `:null` are forbidden
 * at lex time (CXER0100). See spec/core/ast-bin.md §7 + spec/abi.md §3.
 *
 * Binary format spec: see the cx_to_events_bin/cx_to_ast_bin comments above.
 */
char* cx_to_events_bin(const char* input, char** err_out);
char* cx_to_ast_bin   (const char* input, char** err_out);

/* ── Symmetric binary AST (v3.4, ABI v2) ─────────────────────────────────────
 *
 * Closes audit findings CB-1 and CB-2. Together with cx_to_ast_bin, these
 * symbols let bindings parse non-CX inputs once into binary AST and emit
 * non-CX outputs from a binary AST in memory — no JSON-AST re-parse, no
 * CX-text round-trip. See spec/abi.md §2.3.
 *
 * Input: 5 new symbols, <format> → binary AST framed buffer.
 * Output: 6 new symbols, binary AST framed buffer → <format> text.
 *
 * Binary AST format identical to cx_to_ast_bin's output. Caller frees
 * with cx_free().
 */
char* cx_xml_to_ast_bin (const char* input, char** err_out);
char* cx_json_to_ast_bin(const char* input, char** err_out);
char* cx_yaml_to_ast_bin(const char* input, char** err_out);
char* cx_toml_to_ast_bin(const char* input, char** err_out);

char* cx_ast_bin_to_cx  (const char* ast_bin, char** err_out);
char* cx_ast_bin_to_xml (const char* ast_bin, char** err_out);
char* cx_ast_bin_to_json(const char* ast_bin, char** err_out);
char* cx_ast_bin_to_yaml(const char* ast_bin, char** err_out);
char* cx_ast_bin_to_toml(const char* ast_bin, char** err_out);

/* ── CXCol v1 strict-canonical binary data format (v3.4) ──────────────────────
 *
 * cx_to_data_bin / cx_from_data_bin: type-fidelity-preserving binary
 * format for data binding. Input/output framed as [u32 LE size][payload];
 * caller frees with cx_free(). See spec/core/data-bin.md and spec/abi.md §2.4.
 *
 * cx_to_data_bin parses CX text input and returns CXCol v1 bytes.
 * cx_from_data_bin reads CXCol v1 bytes and returns canonical CX text.
 *
 * The format preserves int vs float distinction, large integers, dates,
 * datetimes, empty-container variants (array vs map), and :table blocks
 * with column-major layout. NaN, Inf, duplicate keys, and reserved tag
 * bytes are rejected per spec/policies.md.
 */
char* cx_to_data_bin  (const char* input, char** err_out);
char* cx_from_data_bin(const char* input, char** err_out);

/* ── data_bin one-shot loaders/dumpers (Phase 7.28; spec/abi.md §2.4–§2.5) ───
 *
 * Loaders take per-format text input and return CXCol v1 framed bytes.
 * Dumpers take CXCol v1 framed bytes and return per-format text. Each is
 * a thin composition of an existing per-format parser/emitter with the
 * existing emit_data_bin / parse_data_bin core. CSV / TSV / PSV one-
 * shots ship at capability bit 6 (Phase 7.67); see the delimited
 * section below for cx_csv_to_data_bin / cx_data_bin_to_csv etc.
 */
char* cx_xml_to_data_bin (const char* input, char** err_out);
char* cx_json_to_data_bin(const char* input, char** err_out);
char* cx_yaml_to_data_bin(const char* input, char** err_out);
char* cx_toml_to_data_bin(const char* input, char** err_out);

char* cx_data_bin_to_xml (const char* input, char** err_out);
char* cx_data_bin_to_json(const char* input, char** err_out);
char* cx_data_bin_to_yaml(const char* input, char** err_out);
char* cx_data_bin_to_toml(const char* input, char** err_out);

/* ── Delimited (CSV/TSV/PSV/arbitrary) C ABI (capability bit 6) ──────────────
 *
 * Per spec/conversions.md §8.
 * `delim` is a single byte; any byte except `\r \n " ' \\` is accepted.
 *
 * Emit shape (CX → delimited): `:table` block uses declared columns; an
 * element with 2+ same-named child siblings flattens via repeated-row mode;
 * otherwise dotted-path mode flattens the hierarchy into a single row of
 * `<child>.<...>.<attr>` columns. Mixed shapes return an error.
 *
 * Parse (delimited → CX): produces a `:table`-shaped Document. The first
 * row is the header. Quote styles accepted: bare, "..." (RFC 4180, with
 * "" doubling), '...' (single-quote with '' doubling). Six escape
 * sequences honored in any context: \\ \n \t \r \" \'. Empty unquoted
 * cells become null; quoted "" / '' is the empty string. When the
 * column's values auto-type uniformly the column gets a :type
 * annotation (D5).
 *
 * Conversion is well-defined and reasonable, not lossless: type metadata
 * is lost on emit; comments / anchors / aliases / multi-document /
 * mixed content are stripped or error per the lossy-properties table.
 *
 * Caller frees returned strings with cx_free.
 */
char* cx_to_delimited  (const char* input, char delim, char** err_out);
char* cx_from_delimited(const char* input, char delim, char** err_out);

char* cx_to_csv  (const char* input, char** err_out);
char* cx_from_csv(const char* input, char** err_out);
char* cx_to_tsv  (const char* input, char** err_out);
char* cx_from_tsv(const char* input, char** err_out);
char* cx_to_psv  (const char* input, char** err_out);
char* cx_from_psv(const char* input, char** err_out);

/* delimited × data_bin one-shots */
char* cx_csv_to_data_bin (const char* input, char** err_out);
char* cx_tsv_to_data_bin (const char* input, char** err_out);
char* cx_psv_to_data_bin (const char* input, char** err_out);
char* cx_data_bin_to_csv (const char* input, char** err_out);
char* cx_data_bin_to_tsv (const char* input, char** err_out);
char* cx_data_bin_to_psv (const char* input, char** err_out);

/* ── CXPath C ABI (RETIRED at v0.7.6, Phase 7) ───────────────────────────────
 *
 * cx_select / cx_select_all / cx_select_all_paths were the v0.7.0 POC
 * cxpath surface. They are removed at v0.7.6 (CX code
 * replaces both cxpath and cxquery as the unified pattern / query /
 * transform language). Bindings migrate to cx_code_eval* below
 * with a `[?for pattern :yield expr]` program — see
 * spec/code.md §5 and spec/v0_7_6_status.md Phase 5 (binding
 * parity) for the migration plan. (`[?find]` was the v0.7.6
 * spelling — retired at v0.8.0.)
 *
 * The capability bit 8 (CXPath C ABI) is reclaimed at v0.7.6 per
 * spec/abi.md §3.
 */

/* ── Streaming C ABI (v3.4, ABI v2) ──────────────────────────────────────────
 *
 * Closes audit finding CB-4. Handle-based pull API per spec/abi.md §2.8.
 *
 * Usage:
 *   cx_events_handle h = cx_events_open(input, &err);
 *   for (;;) {
 *       char* ev = cx_events_next(h, &err);
 *       if (ev == NULL) break;        // EOF or error (check err)
 *       // ...consume ev (framed binary event)...
 *       cx_free(ev);
 *   }
 *   cx_events_close(h);
 *
 * The handle is opaque (returned as void*). Caller MUST call
 * cx_events_close to release. cx_events_close(NULL) is a no-op.
 *
 * v1 NOTE: the underlying parser is whole-document. The handle holds
 * a parsed Document plus an iteration cursor; events are produced
 * lazily from the cursor. A future minor revision will swap in an
 * incremental parser without changing this API.
 */
typedef void* cx_events_handle;

cx_events_handle cx_events_open (const char* input, char** err_out);
char*            cx_events_next (cx_events_handle handle, char** err_out);
void             cx_events_close(cx_events_handle handle);

/* ── Canonical-form tooling (Phase 6 / spec/abi.md §2.6) ─────────────────────
 *
 * Four convenience symbols built on parse + emit_cx + sha256:
 *
 *   cx_fmt        - lossless canonical text (preserves comments/anchors;
 *                   normalizes presentation). Idempotent: fmt(fmt(x)) == fmt(x).
 *   cx_canonical  - strict canonical text (strips presentation; output is
 *                   byte-identical for any data-equivalent inputs).
 *   cx_hash       - SHA-256 hex of the strict canonical bytes (64 chars).
 *   cx_eq         - "1" if strict-canonical(a) == strict-canonical(b), else "0".
 *
 * See spec/canonical.md for the full canonical-form contract.
 *
 * Caller frees returned strings with cx_free.
 */
char* cx_fmt      (const char* input, char** err_out);
char* cx_canonical(const char* input, char** err_out);
char* cx_hash     (const char* input, char** err_out);
char* cx_eq       (const char* a, const char* b, char** err_out);

/*
 * cx_diff — semantic diff between two CX inputs (capability
 * bit 18). Walks the strict-canonical forms of both inputs; reformats,
 * comment moves, attribute reorder, and anchor expansion produce empty
 * output. `format` is "unified" (default human-readable), "json"
 * (structured records), or "summary" (one-line counts).
 *
 * Empty output means data-equivalent. Caller frees with cx_free.
 */
char* cx_diff     (const char* a, const char* b, const char* format,
                   char** err_out);

/*
 * cx_lint — style + correctness warnings (capability bit 19).
 * Runs five built-in check IDs (CX-L001..L005) on the input. `format`
 * is "text" (gcc-style), "json" (structured), or "summary" (counts).
 * `disabled` is a comma-separated list of check IDs to skip (e.g.
 * "CX-L003,CX-L005"); empty string runs all checks.
 *
 * Empty output means no findings. Caller frees with cx_free.
 */
char* cx_lint     (const char* input, const char* format,
                   const char* disabled, char** err_out);

/*
 * cx_id_lookup, cx_resolve_ref, cx_node_id — ID/IDREF resolution
 * (capability bit 20). All three are stateless: each call
 * parses `input` from text CX and walks the resulting document.
 *
 *   cx_id_lookup(input, id, err)     — find element declaring `#id`;
 *                                      returns its AST-JSON encoding
 *                                      (per spec/ast.md §JSON).
 *   cx_resolve_ref(input, ref, err)  — follow a bare `@ref` reference
 *                                      to its target element. Refs and
 *                                      IDs share a namespace, so this
 *                                      is observationally equivalent
 *                                      to cx_id_lookup; the symbol
 *                                      exists for binding-side
 *                                      vocabulary clarity.
 *   cx_node_id(input, cxpath, err)   — return the syntactic ID of the
 *                                      element selected by `cxpath`,
 *                                      or empty string if the matched
 *                                      element has no ID (or the
 *                                      cxpath matched nothing).
 *
 * Empty result string with err_out unset means "not found" / "no ID".
 * Non-NULL err_out means parse error or malformed cxpath.
 *
 * Caller frees returned strings with cx_free.
 */
char* cx_id_lookup  (const char* input, const char* id, char** err_out);
char* cx_resolve_ref(const char* input, const char* ref, char** err_out);

/* cx_node_id was a cxpath-driven ID lookup retired alongside cxpath.v
 * at v0.7.6 (Phase 7). Equivalent behaviour: parse the document, run
 * `[?for PATTERN :yield $m]` to locate the element, then read its
 * `@id` attribute. */

/* ── Chunked-table one-shot (Phase 7.72; spec/abi.md §2.10) ─────
 *
 * cx_to_data_bin_chunked: parse CX text whose root is a single
 * :table-bodied element and emit the CXCol chunked-table form (`0x63`)
 * per spec/core/data-bin.md §3.11. Default chunk policy: 2^20 rows per
 * group with auto-zstd above 64 KiB body size. Output is framed
 * `[u32 LE size][payload]`. Capability bit 21 (`0x200000`) signals
 * support; bindings query cx_features and refuse to call this
 * symbol when unset.
 *
 * Caller frees the returned buffer with cx_free.
 */
char* cx_to_data_bin_chunked(const char* input, char** err_out);

/* ── Streaming Table reader / writer (Phase 7.74a; spec/abi.md §2.10,
 * ) ───────────────────────
 *
 * Handle-based pull / push API over the chunked-table wire format
 * (`0x63`). Memory use is bounded by the largest single row group
 * plus a constant overhead. Capability bit 21 (`0x200000`) signals
 * reader / writer support (the same bit covers cx_to_data_bin_chunked).
 *
 * Wire-format conventions:
 *   - In-memory variants (cx_table_reader_open / cx_table_writer_open /
 *     cx_table_writer_close_get_bytes / row-group payloads) consume
 *     and produce the framed `[u32 LE size][CXCol payload]` form used
 *     elsewhere in this ABI.
 *   - fd variants (cx_table_reader_open_fd / cx_table_writer_open_fd)
 *     operate on bare CXCol bytes — the file's length is implicit
 *     from the fd, and streaming writers cannot prefix their output
 *     with a size unknown until end-of-table.
 *
 * Col-spec exchange: cx_table_reader_schema returns (and
 * cx_table_writer_open consumes) framed ast_bin with a single root
 * Element named "table" and one Attribute per column (name = column
 * name, value = type-name string).
 *
 * Memory ownership: byte buffers returned by cx_table_reader_next and
 * cx_table_writer_close_get_bytes are caller-owned; release with
 * cx_free. cx_table_reader_close / cx_table_writer_close release
 * the handle itself; both are NULL-safe.
 *
 * Thread safety: handle is thread-local for its full lifetime
 * (class H per spec/abi.md §1.5.1). Concurrent calls on the same
 * handle are undefined behavior.
 *
 * Reader usage:
 *   void* r = cx_table_reader_open(framed_data_bin, &err);
 *   char* schema = cx_table_reader_schema(r, &err);  // optional
 *   for (;;) {
 *       char* rg = cx_table_reader_next(r, &err);
 *       if (rg == NULL) break;            // EOF (err unset) or error
 *       // ... consume row group framed bytes ...
 *       cx_free(rg);
 *   }
 *   cx_free(schema);
 *   cx_table_reader_close(r);
 *
 * Writer usage (in-memory):
 *   void* w = cx_table_writer_open(col_spec_payload, &err);
 *   cx_table_writer_emit_row_group(w, row_group_framed, &err);
 *   ...
 *   char* out = cx_table_writer_close_get_bytes(w, &err);
 *   // out holds the framed chunked-table buffer; cx_free when done.
 *
 * Writer usage (fd):
 *   void* w = cx_table_writer_open_fd(col_spec_payload, fd, &err);
 *   cx_table_writer_emit_row_group(w, row_group_framed, &err);
 *   ...
 *   cx_table_writer_close(w);   // flushes end-of-table marker
 */
typedef void* cx_table_reader_handle;
typedef void* cx_table_writer_handle;

cx_table_reader_handle cx_table_reader_open    (const char* data_bin,
                                                char** err_out);
cx_table_reader_handle cx_table_reader_open_fd (int fd, char** err_out);
char*                  cx_table_reader_schema  (cx_table_reader_handle handle,
                                                char** err_out);
char*                  cx_table_reader_next    (cx_table_reader_handle handle,
                                                char** err_out);
void                   cx_table_reader_close   (cx_table_reader_handle handle);

cx_table_writer_handle cx_table_writer_open           (const char* col_spec_payload,
                                                       char** err_out);
cx_table_writer_handle cx_table_writer_open_fd        (const char* col_spec_payload,
                                                       int fd,
                                                       char** err_out);
char*                  cx_table_writer_emit_row_group (cx_table_writer_handle handle,
                                                       const char* row_group_payload,
                                                       char** err_out);
char*                  cx_table_writer_close_get_bytes(cx_table_writer_handle handle,
                                                       char** err_out);
void                   cx_table_writer_close          (cx_table_writer_handle handle);

/* ── Schema-driven CXCol encoding (Phase 7.73; spec/abi.md §2.12,
 * ) ─────────────────────────────
 *
 * Schema-driven encoding is opt-in via these variants of the data_bin
 * loaders / dumpers. The writer parses the supplied schema text,
 * computes its content-hash per spec/core/data-bin.md §3.13.1, embeds the
 * schema reference in the header, and emits the root value with
 * per-field tag-omission per §3.13.2. Capability bit 24 (`0x1000000`)
 * signals support; a libcx that implements bit 24 also implements
 * bits 21 (chunked tables) and 22 (page compression).
 *
 * Loader arguments:
 *   input      - per-format text input (NUL-terminated UTF-8).
 *   schema     - schema as CX text (NUL-terminated UTF-8).
 *   ref_form   - schema reference embedding form:
 *                  0 = content-hash only (default; §3.13.1 tag 0x10)
 *                  1 = inline schema bytes      (§3.13.1 tag 0x11)
 *                  2 = content-hash + name hint (§3.13.1 tag 0x12)
 *   name_hint  - UTF-8 name shown to humans when ref_form == 2;
 *                pass NULL or "" otherwise.
 *
 * Dumper arguments:
 *   data_bin    - framed [u32 LE size][CXCol payload] schema-driven buffer.
 *   schema_hint - optional schema as CX text used when the embedded
 *                 reference is content-hash-only and not resolvable
 *                 from the consumer's content-addressable store. Pass
 *                 NULL or "" to use embedded resolution only.
 *
 * Output is framed `[u32 LE size][payload]`. Caller frees with cx_free.
 */
char* cx_to_data_bin_schema_driven    (const char* input,
                                       const char* schema,
                                       int ref_form,
                                       const char* name_hint,
                                       char** err_out);
char* cx_xml_to_data_bin_schema_driven(const char* input,
                                       const char* schema,
                                       int ref_form,
                                       const char* name_hint,
                                       char** err_out);
char* cx_json_to_data_bin_schema_driven(const char* input,
                                        const char* schema,
                                        int ref_form,
                                        const char* name_hint,
                                        char** err_out);
char* cx_yaml_to_data_bin_schema_driven(const char* input,
                                        const char* schema,
                                        int ref_form,
                                        const char* name_hint,
                                        char** err_out);
char* cx_toml_to_data_bin_schema_driven(const char* input,
                                        const char* schema,
                                        int ref_form,
                                        const char* name_hint,
                                        char** err_out);
char* cx_csv_to_data_bin_schema_driven(const char* input,
                                       const char* schema,
                                       int ref_form,
                                       const char* name_hint,
                                       char** err_out);
char* cx_tsv_to_data_bin_schema_driven(const char* input,
                                       const char* schema,
                                       int ref_form,
                                       const char* name_hint,
                                       char** err_out);
char* cx_psv_to_data_bin_schema_driven(const char* input,
                                       const char* schema,
                                       int ref_form,
                                       const char* name_hint,
                                       char** err_out);

char* cx_from_data_bin_schema_driven  (const char* data_bin,
                                       const char* schema_hint,
                                       char** err_out);

/* ── Schema validator (NEW in v0.6.0) ───────────────────────────── */
/* spec/schema.md §10 / §10.2 / §10.3.
 *
 * cx_validate parses doc_input + schema_input (both NUL-terminated CX
 * text), runs the validator, and returns a framed
 * [u32 LE size][u32 count][diagnostic*] payload. Each diagnostic:
 *   [u32 line] [u32 col] [u32 error_code]
 *   [u8 severity (0=info,1=warn,2=error)]
 *   [u32 message_len] [message_utf8]
 * NULL with *err_out set on schema-load / parse failure.
 *
 * cx_validate_apply_defaults additionally writes the
 * default-applied document (canonical CX text) to *modified_doc_out;
 * caller frees both outputs with cx_free.
 *
 * Capability bit 25 (`0x2000000`) signals schema-validator support.
 * RE2 backs the `:pat=` constraint; pattern semantics are normative
 * cross-binding because every binding routes through cx_validate. */
char* cx_validate                     (const char* doc_input,
                                       const char* schema_input,
                                       char** err_out);

char* cx_validate_apply_defaults      (const char* doc_input,
                                       const char* schema_input,
                                       char** modified_doc_out,
                                       char** err_out);

/* ── Explicit-length C ABI variants (v0.6.0 hardening) ───────────── */
/* See spec/abi.md §2.14. Validate caller-supplied byte counts against
 * each framed input's embedded size header before reading; close the
 * implicit-length OOB-read footgun. New bindings landing post-v0.6.0
 * SHOULD prefer these forms. */

#include <stddef.h>  /* size_t */

char* cx_from_data_bin_with_len (const char* input, size_t total_len,
                                 char** err_out);

cx_table_reader_handle cx_table_reader_open_with_len
                                (const char* data_bin, size_t total_len,
                                 char** err_out);

cx_table_writer_handle cx_table_writer_open_with_len
                                (const char* col_spec_payload, size_t total_len,
                                 char** err_out);

cx_table_writer_handle cx_table_writer_open_fd_with_len
                                (const char* col_spec_payload, size_t total_len,
                                 int fd, char** err_out);

char* cx_table_writer_emit_row_group_with_len
                                (cx_table_writer_handle handle,
                                 const char* row_group_payload, size_t total_len,
                                 char** err_out);

char* cx_validate_with_len      (const char* doc_input, size_t doc_len,
                                 const char* schema_input, size_t schema_len,
                                 char** err_out);

char* cx_validate_apply_defaults_with_len
                                (const char* doc_input, size_t doc_len,
                                 const char* schema_input, size_t schema_len,
                                 char** modified_doc_out, char** err_out);

/* ── Streaming-write API (spec/streaming.md §6 / spec/abi.md §2.15) ─
 * Handle-based, format-targeted event writer; thread-local. The 25
 * symbols below ship with capability bit 27. Open returns a writer
 * handle (NULL on error with *err_out set). Each emit returns NULL
 * on success or a heap-allocated diagnostic string ("Wnnn: ...");
 * the same string is also written to *err_out for ergonomic access.
 * Diagnostic strings are caller-owned — release with cx_free. The
 * writer "fails closed": after the first W-code, subsequent emits
 * return the same diagnostic without effect.
 *
 * close_get_bytes returns the accumulated output as a CXCol-style
 * [u32 LE size][payload] frame (size=0 for fd writers); release the
 * pointer with cx_free. close releases the handle without returning
 * bytes (idempotent; safe on NULL).
 *
 * attrs_payload / col_spec_payload / row_group_payload are framed
 * binary inputs. The _with_len siblings take an explicit byte count
 * (spec/abi.md §2.14 — preferred for new bindings).
 */
typedef void* cx_events_writer_handle;

cx_events_writer_handle cx_events_writer_open
    (const char* output_format, char** err_out);
cx_events_writer_handle cx_events_writer_open_fd
    (const char* output_format, int fd, char** err_out);
/*
 * The cx_events_writer_open_shaped* family (4 variants) was removed
 * 2026-05-10 when was superseded. CXL is the
 * only output-shape mechanism; see cx_eval_cxl* in §2.16.
 */

char* cx_events_writer_close_get_bytes
    (cx_events_writer_handle w, char** err_out);
void  cx_events_writer_close
    (cx_events_writer_handle w);

char* cx_events_writer_start_doc
    (cx_events_writer_handle w, char** err_out);
char* cx_events_writer_end_doc
    (cx_events_writer_handle w, char** err_out);

char* cx_events_writer_start_element
    (cx_events_writer_handle w, const char* name, const char* anchor,
     const char* data_type, const char* merge, const char* attrs_payload,
     char** err_out);
char* cx_events_writer_start_element_with_len
    (cx_events_writer_handle w, const char* name, const char* anchor,
     const char* data_type, const char* merge, const char* attrs_payload,
     size_t attrs_len, char** err_out);
char* cx_events_writer_end_element
    (cx_events_writer_handle w, const char* name, char** err_out);

char* cx_events_writer_text
    (cx_events_writer_handle w, const char* value, char** err_out);
char* cx_events_writer_scalar
    (cx_events_writer_handle w, const char* data_type, const char* value,
     char** err_out);
char* cx_events_writer_comment
    (cx_events_writer_handle w, const char* value, char** err_out);
char* cx_events_writer_pi
    (cx_events_writer_handle w, const char* target, const char* data,
     char** err_out);
char* cx_events_writer_entity_ref
    (cx_events_writer_handle w, const char* name, char** err_out);
char* cx_events_writer_raw_text
    (cx_events_writer_handle w, const char* value, char** err_out);
char* cx_events_writer_alias
    (cx_events_writer_handle w, const char* name, char** err_out);

char* cx_events_writer_start_table
    (cx_events_writer_handle w, const char* col_spec_payload, char** err_out);
char* cx_events_writer_start_table_with_len
    (cx_events_writer_handle w, const char* col_spec_payload, size_t col_spec_len,
     char** err_out);
char* cx_events_writer_row_group
    (cx_events_writer_handle w, const char* row_group_payload, char** err_out);
char* cx_events_writer_row_group_with_len
    (cx_events_writer_handle w, const char* row_group_payload, size_t row_group_len,
     char** err_out);
char* cx_events_writer_end_table
    (cx_events_writer_handle w, char** err_out);

/* ── §2.16 CXL evaluator (RETIRED at v0.7.6, Phase 7) ────────────────────
 *
 * cx_eval / cx_eval_with_len / cx_eval_streaming were the v0.7.0 POC
 * evaluator surface (spec/cxpath.md + the cx:/log:/inspect: self-host
 * modules). They are removed at v0.7.6 (CX code is the
 * unified pattern/query/transform language). The replacement is the
 * cx_code_eval* family below — see spec/code.md +
 * spec/audits/code_abi_v1.md. Capability bit 28 is re-widened at
 * v0.7.6 to mean "CX code evaluator present" per spec/abi.md §3. */

/* ── v0.7.6 CX code evaluator (Phase 3.11) ─────────────────────────────
 *
 * The cx_code_eval* family is the v0.7.6 surface for evaluating
 * CX code (spec/code.md). It coexists with cx_eval* above
 * until Phase 7 deletes the v0.7.0 POC; bindings should call
 * cx_code_eval* and stop calling cx_eval* during Phase 5 binding
 * parity. ABI design ratified at spec/audits/code_abi_v1.md.
 *
 * Memory ownership and error channel follow spec/abi.md §1.3 / §1.4.
 * Error wire format is `CXERnnnn:msg` (e.g. `CXER0100:parse: ...`).
 *
 * input  may be NULL or empty when the program does not consume an
 *        implicit `$doc` binding (e.g. `[?for $i :in (1,2,3) :yield $i]`).
 * output_target is one of: text (default), cx, json, yaml, xml, csv,
 *        tsv (always available); html, markdown, svg, mermaid (Phase
 *        4-gated -- return a clear CXER0001 until the reference
 *        renderer lands). */

char* cx_code_eval
    (const char* input,
     const char* program,
     const char* output_target,
     char** err_out);

char* cx_code_eval_with_len
    (const char* input,   size_t input_len,
     const char* program, size_t program_len,
     const char* output_target,
     char** err_out);

/* cx_code_eval_caps — capability-aware member of the cx_code_eval* family
 * (capability bit 38; spec/core/security.md, spec/core/abi.md §2.16.1).
 * ADDITIVE: cx_code_eval / cx_code_eval_with_len are unchanged and run
 * under the empty (pure-only) default, so existing bindings need no change.
 *
 * `caps` is the host grant spec (deny-by-default):
 *   NULL or ""     -> empty set (pure-only) — the spec default
 *   "all" / "*"    -> full grant (the --allow-all opt-out)
 *   "read,write,…" -> exactly the listed capabilities (least-privilege)
 * A denied effect at its effect point raises cx-err:CXER0271. The grant
 * applies only to this call (the process capability set is reset after). */
char* cx_code_eval_caps
    (const char* input,
     const char* program,
     const char* output_target,
     const char* caps,
     char** err_out);

typedef int (*cx_code_write_cb)(const char* bytes,
                                    size_t n,
                                    void* user);

char* cx_code_eval_streaming
    (const char* input,   size_t input_len,
     const char* program, size_t program_len,
     const char* output_target,
     cx_code_write_cb write_cb,
     void* user,
     char** err_out);

/* ── §2.16.2 v0.7.6 cx_code_diagram (Phase 9.1, gate 17) ────────────────
 *
 * Render a CX program to a diagram representation. Stateless function
 * of (source_text, format); identical bytes returned for identical
 * inputs. The wasm-callable surface behind the playground Source-pane
 * Visualize affordance and the reference renderer's Mermaid output.
 * SVG / PNG go through the CLI tier (graphviz shell-out); not exposed
 * at this ABI (the wasm build does not link graphviz).
 *
 * Error wire format: in-band `CXERnnnn:msg` (e.g. `CXER0100:parse: ...`).
 * Caller frees with cx_free(). format MUST be "mermaid" at v0.7.6;
 * other formats yield CXER0001 with a clear "unsupported format" body. */
char* cx_code_diagram
    (const char* source, size_t source_len,
     const char* format, size_t format_len);

/* ── §2.16.3 v0.8.0 cx_code_tree (capability bit 32) ────────
 *
 * Return a JSON projection of the parsed source: every node carries
 * `{kind, name?, value?, loc:{start,end}, children?}` with byte offsets
 * into the original source. The `loc` field enables the bidirectional
 * selection bridge between the playground tree pane and the source pane
 * without further ABI plumbing. Independent of bit 31 — a binding MAY
 * advertise `cx_code_tree` without `cx_code_diagram`, or vice versa.
 *
 * Memory ownership and error wire format match cx_code_diagram:
 *   - returned bytes are caller-owned; release with cx_free().
 *   - errors come back in-band as `CXERnnnn:msg` (e.g. `CXER0100:...`).
 *   - out_len, if non-NULL, receives the payload byte length on success.
 *
 * Capability bit 32 (`0x100000000`). See spec/abi.md §3. */
char* cx_code_tree
    (const char* source, size_t source_len, size_t* out_len);

/* ── §2.16.4 v0.8.0 cx_code_ast_json (playground Source-tree view) ───────
 *
 * Return a JSON encoding of the parsed program AST suitable for the
 * playground's Source Tree pane. Stateless; identical bytes for
 * identical inputs. Error wire format: in-band `CXERnnnn:msg` per
 * cx_code_diagram. Caller frees with cx_free(). */
char* cx_code_ast_json
    (const char* source, size_t source_len);

/* ── Include-resolution variants (spec/include.md, gate GG1) ─────────────
 *
 * Equivalent to cx_to_cx / cx_to_ast_bin / cx_to_data_bin but with the
 * filesystem root used to resolve [?cx include] directives supplied
 * explicitly. include_root MUST be a NUL-terminated absolute path; pass
 * "" to disable include resolution (parse [?cx include] as opaque). */
char* cx_to_cx_with_include_root      (const char* input,
                                       const char* include_root,
                                       char** err_out);
char* cx_to_ast_bin_with_include_root (const char* input,
                                       const char* include_root,
                                       char** err_out);
char* cx_to_data_bin_with_include_root(const char* input,
                                       const char* include_root,
                                       char** err_out);

/* ── Wasm-only arena tuning ──────────────────────────────────────────────
 *
 * These two symbols exist only in the wasm build of libcx — the
 * native-platform build is unaffected. The wasm runtime uses a bumped
 * arena allocator backing every cx_* call; cx_wasm_set_arena_size
 * grows the arena to at least `bytes`, and cx_wasm_reset returns it to
 * its initial size between user actions in the playground. Both return
 * 0 on success, -1 on failure. Hosts that do not run the wasm build
 * MUST NOT link against these symbols. */
int cx_wasm_set_arena_size(unsigned int bytes);
int cx_wasm_reset(void);

#ifdef __cplusplus
}
#endif

#endif /* CX_H */
