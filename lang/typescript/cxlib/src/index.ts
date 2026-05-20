/**
 * CX TypeScript binding — koffi wrapper around libcx.
 */

// libcx's bundled Boehm GC crashes inside `GC_mark_from` on its second
// real stop-the-world collection when running under Node's process
// layout. macOS crash reports confirm EXC_BAD_ACCESS in
// `GC_mark_from + 524`, called from
// `GC_collect_or_expand → cx__parse_cx → ForwardCallGG (koffi)`. The
// first collection (bootstrap, empty heap) always succeeds; the second
// — the first real mark — always crashes regardless of initial heap
// size or libgc tuning. Confirmed reproducible across heap sizes from
// 256 KB to 512 MB, GC_DISABLE_INCREMENTAL, GC_USE_ENTIRE_HEAP,
// GC_MARKERS=1, GC_FORCE_UNMAP_ON_GCOLLECT=0, and several other
// settings. The only env knob that prevents the crash is GC_DONT_GC=1.
//
// Until the underlying interaction is fixed upstream (likely a libgc
// conservative-pointer-following confusion specific to Node/V8's
// address-space layout — Python's ctypes binding does not hit it),
// the TS binding disables libcx's GC by default. Trade-off: libcx
// allocations are never reclaimed for the lifetime of the process.
//   - Short-lived CLI: no functional impact (process exits).
//   - Long-lived server: must periodically restart workers, or set
//     CX_TS_ALLOW_GC=1 to risk the SIGSEGV instead of leaking.
//
// Env vars are read by Boehm GC during GC_INIT, which runs at
// libcx.dylib load time — they MUST be set before koffi.load(). The
// no-op import order below is preserved by tsc / esbuild because top-
// level statements in a CommonJS-compiled module run in source order
// once `require` is invoked at the top.
//
// Root cause + reproduction recipe + suggested upstream debug path
// are tracked in memory/project_ts_binding_gc_sigsegv.md.
if (!process.env.CX_TS_ALLOW_GC && !process.env.GC_DONT_GC) {
  process.env.GC_DONT_GC = '1';
}
if (!process.env.GC_INITIAL_HEAP_SIZE) {
  process.env.GC_INITIAL_HEAP_SIZE = String(32 * 1024 * 1024);
}

import koffi from 'koffi';
import path from 'path';
import fs from 'fs';
import { decodeAST, decodeEvents } from './binary';
import type { StreamEvent } from './binary';

// ── library discovery ─────────────────────────────────────────────────────────
const libName = process.platform === 'darwin' ? 'libcx.dylib' : 'libcx.so';

function findLibcx(): string {
  // 1. Explicit path override
  if (process.env.LIBCX_PATH) return process.env.LIBCX_PATH;

  const candidates: string[] = [];

  // 2. Directory override
  if (process.env.LIBCX_LIB_DIR)
    candidates.push(path.join(process.env.LIBCX_LIB_DIR, libName));

  // 3. System paths
  for (const dir of ['/usr/local/lib', '/opt/homebrew/lib', '/usr/lib',
                     '/usr/lib/x86_64-linux-gnu', '/usr/lib/aarch64-linux-gnu'])
    candidates.push(path.join(dir, libName));

  // 4. Repo-relative fallback (development)
  const repoRoot = path.resolve(__dirname, '..', '..', '..', '..');
  candidates.push(path.join(repoRoot, 'vcx', 'target', libName));
  candidates.push(path.join(repoRoot, 'dist', 'lib', libName));

  const found = candidates.find(p => fs.existsSync(p));
  if (found) return found;
  throw new Error(`libcx not found. Install with 'sudo make install' or set LIBCX_PATH.\nLooked in: ${candidates.join(', ')}`);
}

const libPath = findLibcx();

const lib = koffi.load(libPath);

// ── native function declarations ──────────────────────────────────────────────
// koffi copies returned char* strings to JS; no manual cx_free needed.
// For err_out we use _Out_ str* so koffi writes the error string into an array.

// Thread-init handshake (spec/abi.md §1.5.5, capability bit 26).
// Mandatory-for-all-bindings; called once at module-load time. Node's
// JS execution is single-threaded so a single cx_thread_register on the
// main thread is sufficient — without it, libcx's Boehm GC has no
// awareness of the Node thread's stack roots and may collect live
// libcx-owned strings while koffi still references them, surfacing as
// a silent SIGSEGV mid-suite once the heap accumulates enough churn.
const _cx_init = lib.func('int cx_init()');
const _cx_thread_register = lib.func('int cx_thread_register()');
_cx_init();
_cx_thread_register();

const _cx_version = lib.func('char* cx_version()');
const _cx_free = lib.func('void cx_free(void* ptr)');

// Binary functions — return a raw pointer to [u32 size][payload] buffer.
const _cx_to_ast_bin    = lib.func('void* cx_to_ast_bin(str input, _Out_ str* err_out)');
const _cx_to_ast_bin_with_include_root = lib.func('void* cx_to_ast_bin_with_include_root(str input, str include_root, _Out_ str* err_out)');
const _cx_to_events_bin = lib.func('void* cx_to_events_bin(str input, _Out_ str* err_out)');
const _cx_to_data_bin   = lib.func('void* cx_to_data_bin(str input, _Out_ str* err_out)');

// cx_from_data_bin: framed CXDB bytes in, canonical CX text out.
const _cx_from_data_bin = lib.func('char* cx_from_data_bin(uint8_t* input, _Out_ str* err_out)');

// data_bin one-shot loaders/dumpers (Phase 7.28; spec/abi.md §2.4–§2.5).
// Loaders: text input → CXDB v1 framed bytes (frame-stripped via callBinFn).
const _cx_xml_to_data_bin  = lib.func('void* cx_xml_to_data_bin (str input, _Out_ str* err_out)');
const _cx_json_to_data_bin = lib.func('void* cx_json_to_data_bin(str input, _Out_ str* err_out)');
const _cx_yaml_to_data_bin = lib.func('void* cx_yaml_to_data_bin(str input, _Out_ str* err_out)');
const _cx_toml_to_data_bin = lib.func('void* cx_toml_to_data_bin(str input, _Out_ str* err_out)');
const _cx_md_to_data_bin   = lib.func('void* cx_md_to_data_bin  (str input, _Out_ str* err_out)');

// Dumpers: CXDB v1 framed bytes → text. uint8_t* on input so koffi
// doesn't strlen-trim at embedded NULs (same convention as cx_from_data_bin
// and the ast_bin_to_* dumpers).
const _cx_data_bin_to_xml  = lib.func('char* cx_data_bin_to_xml (uint8_t* input, _Out_ str* err_out)');
const _cx_data_bin_to_json = lib.func('char* cx_data_bin_to_json(uint8_t* input, _Out_ str* err_out)');
const _cx_data_bin_to_yaml = lib.func('char* cx_data_bin_to_yaml(uint8_t* input, _Out_ str* err_out)');
const _cx_data_bin_to_toml = lib.func('char* cx_data_bin_to_toml(uint8_t* input, _Out_ str* err_out)');
const _cx_data_bin_to_md   = lib.func('char* cx_data_bin_to_md  (uint8_t* input, _Out_ str* err_out)');

// CXPath path-tracking C ABI (Phase 4 / CB-5).
const _cx_select_all_paths = lib.func('void* cx_select_all_paths(str input, str expr, _Out_ str* err_out)');

// Phase 5 / CB-1 — ast_bin → text format. Input is FRAMED bin; declared
// as uint8_t* so koffi passes a Buffer through without strlen-trim at
// embedded NULs.
const _cx_ast_bin_to_cx   = lib.func('char* cx_ast_bin_to_cx  (uint8_t* input, _Out_ str* err_out)');
const _cx_ast_bin_to_xml  = lib.func('char* cx_ast_bin_to_xml (uint8_t* input, _Out_ str* err_out)');
const _cx_ast_bin_to_json = lib.func('char* cx_ast_bin_to_json(uint8_t* input, _Out_ str* err_out)');
const _cx_ast_bin_to_yaml = lib.func('char* cx_ast_bin_to_yaml(uint8_t* input, _Out_ str* err_out)');
const _cx_ast_bin_to_toml = lib.func('char* cx_ast_bin_to_toml(uint8_t* input, _Out_ str* err_out)');
const _cx_ast_bin_to_md   = lib.func('char* cx_ast_bin_to_md  (uint8_t* input, _Out_ str* err_out)');

// Phase 5 / CB-2 — text → ast_bin (returns framed binary).
const _cx_xml_to_ast_bin  = lib.func('void* cx_xml_to_ast_bin (str input, _Out_ str* err_out)');
const _cx_json_to_ast_bin = lib.func('void* cx_json_to_ast_bin(str input, _Out_ str* err_out)');
const _cx_yaml_to_ast_bin = lib.func('void* cx_yaml_to_ast_bin(str input, _Out_ str* err_out)');
const _cx_toml_to_ast_bin = lib.func('void* cx_toml_to_ast_bin(str input, _Out_ str* err_out)');
const _cx_md_to_ast_bin   = lib.func('void* cx_md_to_ast_bin  (str input, _Out_ str* err_out)');

// Phase 5 / CB-4 — events handle API.
const _cx_events_open  = lib.func('void* cx_events_open (str input, _Out_ str* err_out)');
const _cx_events_next  = lib.func('void* cx_events_next (void* handle, _Out_ str* err_out)');
const _cx_events_close = lib.func('void cx_events_close(void* handle)');

// Phase 6 — canonical-form tooling (spec/abi.md §2.6).
const _cx_fmt       = lib.func('char* cx_fmt      (str input, _Out_ str* err_out)');
const _cx_canonical = lib.func('char* cx_canonical(str input, _Out_ str* err_out)');
const _cx_hash      = lib.func('char* cx_hash     (str input, _Out_ str* err_out)');
const _cx_eq        = lib.func('char* cx_eq       (str a, str b, _Out_ str* err_out)');
const _cx_diff      = lib.func('char* cx_diff     (str a, str b, str format, _Out_ str* err_out)');
const _cx_lint      = lib.func('char* cx_lint     (str input, str format, str disabled, _Out_ str* err_out)');

// Phase 7.65 / ADR 0003 — ID/IDREF C ABI wrappers.
const _cx_id_lookup   = lib.func('char* cx_id_lookup  (str input, str id,     _Out_ str* err_out)');
const _cx_resolve_ref = lib.func('char* cx_resolve_ref(str input, str ref,    _Out_ str* err_out)');
const _cx_node_id     = lib.func('char* cx_node_id    (str input, str cxpath, _Out_ str* err_out)');

// CX input
const _cx_to_cx          = lib.func('char* cx_to_cx         (str input, _Out_ str* err_out)');
const _cx_to_cx_compact  = lib.func('char* cx_to_cx_compact (str input, _Out_ str* err_out)');
const _cx_ast_to_cx      = lib.func('char* cx_ast_to_cx     (str input, _Out_ str* err_out)');
const _cx_to_xml  = lib.func('char* cx_to_xml (str input, _Out_ str* err_out)');
const _cx_to_ast  = lib.func('char* cx_to_ast (str input, _Out_ str* err_out)');
const _cx_to_json = lib.func('char* cx_to_json(str input, _Out_ str* err_out)');
const _cx_to_yaml = lib.func('char* cx_to_yaml(str input, _Out_ str* err_out)');
const _cx_to_toml = lib.func('char* cx_to_toml(str input, _Out_ str* err_out)');
const _cx_to_md   = lib.func('char* cx_to_md  (str input, _Out_ str* err_out)');

// XML input
const _cx_xml_to_cx   = lib.func('char* cx_xml_to_cx  (str input, _Out_ str* err_out)');
const _cx_xml_to_xml  = lib.func('char* cx_xml_to_xml (str input, _Out_ str* err_out)');
const _cx_xml_to_ast  = lib.func('char* cx_xml_to_ast (str input, _Out_ str* err_out)');
const _cx_xml_to_json = lib.func('char* cx_xml_to_json(str input, _Out_ str* err_out)');
const _cx_xml_to_yaml = lib.func('char* cx_xml_to_yaml(str input, _Out_ str* err_out)');
const _cx_xml_to_toml = lib.func('char* cx_xml_to_toml(str input, _Out_ str* err_out)');
const _cx_xml_to_md   = lib.func('char* cx_xml_to_md  (str input, _Out_ str* err_out)');

// JSON input
const _cx_json_to_cx   = lib.func('char* cx_json_to_cx  (str input, _Out_ str* err_out)');
const _cx_json_to_xml  = lib.func('char* cx_json_to_xml (str input, _Out_ str* err_out)');
const _cx_json_to_ast  = lib.func('char* cx_json_to_ast (str input, _Out_ str* err_out)');
const _cx_json_to_json = lib.func('char* cx_json_to_json(str input, _Out_ str* err_out)');
const _cx_json_to_yaml = lib.func('char* cx_json_to_yaml(str input, _Out_ str* err_out)');
const _cx_json_to_toml = lib.func('char* cx_json_to_toml(str input, _Out_ str* err_out)');
const _cx_json_to_md   = lib.func('char* cx_json_to_md  (str input, _Out_ str* err_out)');

// YAML input
const _cx_yaml_to_cx   = lib.func('char* cx_yaml_to_cx  (str input, _Out_ str* err_out)');
const _cx_yaml_to_xml  = lib.func('char* cx_yaml_to_xml (str input, _Out_ str* err_out)');
const _cx_yaml_to_ast  = lib.func('char* cx_yaml_to_ast (str input, _Out_ str* err_out)');
const _cx_yaml_to_json = lib.func('char* cx_yaml_to_json(str input, _Out_ str* err_out)');
const _cx_yaml_to_yaml = lib.func('char* cx_yaml_to_yaml(str input, _Out_ str* err_out)');
const _cx_yaml_to_toml = lib.func('char* cx_yaml_to_toml(str input, _Out_ str* err_out)');
const _cx_yaml_to_md   = lib.func('char* cx_yaml_to_md  (str input, _Out_ str* err_out)');

// TOML input
const _cx_toml_to_cx   = lib.func('char* cx_toml_to_cx  (str input, _Out_ str* err_out)');
const _cx_toml_to_xml  = lib.func('char* cx_toml_to_xml (str input, _Out_ str* err_out)');
const _cx_toml_to_ast  = lib.func('char* cx_toml_to_ast (str input, _Out_ str* err_out)');
const _cx_toml_to_json = lib.func('char* cx_toml_to_json(str input, _Out_ str* err_out)');
const _cx_toml_to_yaml = lib.func('char* cx_toml_to_yaml(str input, _Out_ str* err_out)');
const _cx_toml_to_toml = lib.func('char* cx_toml_to_toml(str input, _Out_ str* err_out)');
const _cx_toml_to_md   = lib.func('char* cx_toml_to_md  (str input, _Out_ str* err_out)');

// Delimited (CSV/TSV/PSV/arbitrary) C ABI (ADR 0001 / Phase 7.68).
// Text-text (8): two delim-bearing entry points + 6 aliases.
const _cx_to_delimited   = lib.func('char* cx_to_delimited  (str input, uint8_t delim, _Out_ str* err_out)');
const _cx_from_delimited = lib.func('char* cx_from_delimited(str input, uint8_t delim, _Out_ str* err_out)');
const _cx_to_csv   = lib.func('char* cx_to_csv  (str input, _Out_ str* err_out)');
const _cx_from_csv = lib.func('char* cx_from_csv(str input, _Out_ str* err_out)');
const _cx_to_tsv   = lib.func('char* cx_to_tsv  (str input, _Out_ str* err_out)');
const _cx_from_tsv = lib.func('char* cx_from_tsv(str input, _Out_ str* err_out)');
const _cx_to_psv   = lib.func('char* cx_to_psv  (str input, _Out_ str* err_out)');
const _cx_from_psv = lib.func('char* cx_from_psv(str input, _Out_ str* err_out)');
// Binary one-shots (6): csv/tsv/psv ↔ data_bin.
// Loaders return UNFRAMED CXDB v1 payload (frame stripped via callBinFn).
const _cx_csv_to_data_bin = lib.func('void* cx_csv_to_data_bin(str input, _Out_ str* err_out)');
const _cx_tsv_to_data_bin = lib.func('void* cx_tsv_to_data_bin(str input, _Out_ str* err_out)');
const _cx_psv_to_data_bin = lib.func('void* cx_psv_to_data_bin(str input, _Out_ str* err_out)');
// Dumpers expect FRAMED CXDB v1 input (uint8_t* on input so koffi doesn't
// strlen-trim at embedded NULs).
const _cx_data_bin_to_csv = lib.func('char* cx_data_bin_to_csv(uint8_t* input, _Out_ str* err_out)');
const _cx_data_bin_to_tsv = lib.func('char* cx_data_bin_to_tsv(uint8_t* input, _Out_ str* err_out)');
const _cx_data_bin_to_psv = lib.func('char* cx_data_bin_to_psv(uint8_t* input, _Out_ str* err_out)');

// ── Chunked-table one-shot + streaming Table (Phase 7.72 / 7.74a) ───────────
// Per spec/abi.md §2.10 (capability bit 21) and ADR 0015 D8.
const _cx_to_data_bin_chunked = lib.func('void* cx_to_data_bin_chunked(str input, _Out_ str* err_out)');

// Reader: data_bin / col_spec / row_group payloads carry NULs, so use uint8_t*.
const _cx_table_reader_open    = lib.func('void* cx_table_reader_open    (uint8_t* data_bin, _Out_ str* err_out)');
const _cx_table_reader_open_fd = lib.func('void* cx_table_reader_open_fd (int fd, _Out_ str* err_out)');
const _cx_table_reader_schema  = lib.func('void* cx_table_reader_schema  (void* handle, _Out_ str* err_out)');
const _cx_table_reader_next    = lib.func('void* cx_table_reader_next    (void* handle, _Out_ str* err_out)');
const _cx_table_reader_close   = lib.func('void  cx_table_reader_close   (void* handle)');

const _cx_table_writer_open            = lib.func('void* cx_table_writer_open            (uint8_t* col_spec_payload, _Out_ str* err_out)');
const _cx_table_writer_open_fd         = lib.func('void* cx_table_writer_open_fd         (uint8_t* col_spec_payload, int fd, _Out_ str* err_out)');
const _cx_table_writer_emit_row_group  = lib.func('char* cx_table_writer_emit_row_group  (void* handle, uint8_t* row_group_payload, _Out_ str* err_out)');
const _cx_table_writer_close_get_bytes = lib.func('void* cx_table_writer_close_get_bytes (void* handle, _Out_ str* err_out)');
const _cx_table_writer_close           = lib.func('void  cx_table_writer_close           (void* handle)');

// ── Schema-driven CXDB encoding (Phase 7.73; spec/abi.md §2.12, ADR 0015 D3) ─
// Loader signature: (input, schema, ref_form, name_hint, _Out_ err) → framed CXDB.
const _cx_to_data_bin_schema_driven      = lib.func('void* cx_to_data_bin_schema_driven      (str input, str schema, int ref_form, str name_hint, _Out_ str* err_out)');
const _cx_xml_to_data_bin_schema_driven  = lib.func('void* cx_xml_to_data_bin_schema_driven  (str input, str schema, int ref_form, str name_hint, _Out_ str* err_out)');
const _cx_json_to_data_bin_schema_driven = lib.func('void* cx_json_to_data_bin_schema_driven (str input, str schema, int ref_form, str name_hint, _Out_ str* err_out)');
const _cx_yaml_to_data_bin_schema_driven = lib.func('void* cx_yaml_to_data_bin_schema_driven (str input, str schema, int ref_form, str name_hint, _Out_ str* err_out)');
const _cx_toml_to_data_bin_schema_driven = lib.func('void* cx_toml_to_data_bin_schema_driven (str input, str schema, int ref_form, str name_hint, _Out_ str* err_out)');
const _cx_md_to_data_bin_schema_driven   = lib.func('void* cx_md_to_data_bin_schema_driven   (str input, str schema, int ref_form, str name_hint, _Out_ str* err_out)');
const _cx_csv_to_data_bin_schema_driven  = lib.func('void* cx_csv_to_data_bin_schema_driven  (str input, str schema, int ref_form, str name_hint, _Out_ str* err_out)');
const _cx_tsv_to_data_bin_schema_driven  = lib.func('void* cx_tsv_to_data_bin_schema_driven  (str input, str schema, int ref_form, str name_hint, _Out_ str* err_out)');
const _cx_psv_to_data_bin_schema_driven  = lib.func('void* cx_psv_to_data_bin_schema_driven  (str input, str schema, int ref_form, str name_hint, _Out_ str* err_out)');
const _cx_from_data_bin_schema_driven    = lib.func('char* cx_from_data_bin_schema_driven    (uint8_t* data_bin, str schema_hint, _Out_ str* err_out)');

// CXL evaluation (spec/eval.md / ADR 0016, capability bit 28)
const _cx_eval = lib.func('char* cx_eval(str cx_input, str cxl_program, str output_target, _Out_ str* err_out)');

// Streaming evaluator (v0.7.0 Y-row; spec/v0_7_0_status.md Y).
// cx_eval_streaming takes a write-callback that fires per chunk;
// koffi's `register` / callback API wraps a JS function as a C
// function pointer with the matching signature.
// Declare bytes as `void*` (not `const char*`) so koffi exposes a
// raw pointer to the callback rather than auto-decoding to JS string.
// Buffer contents may include NUL bytes — read via koffi.decode with
// the supplied length.
const CxEvalWriteCb = koffi.proto('int CxEvalWriteCb(void* bytes, size_t n, void* user)');
const _cx_eval_streaming = lib.func(
  'char* cx_eval_streaming(str cx_input, str cxl_program, str output_target, ' +
  'CxEvalWriteCb* write_cb, void* user, _Out_ str* err_out)'
);

// MD input
const _cx_md_to_cx   = lib.func('char* cx_md_to_cx  (str input, _Out_ str* err_out)');
const _cx_md_to_xml  = lib.func('char* cx_md_to_xml (str input, _Out_ str* err_out)');
const _cx_md_to_ast  = lib.func('char* cx_md_to_ast (str input, _Out_ str* err_out)');
const _cx_md_to_json = lib.func('char* cx_md_to_json(str input, _Out_ str* err_out)');
const _cx_md_to_yaml = lib.func('char* cx_md_to_yaml(str input, _Out_ str* err_out)');
const _cx_md_to_toml = lib.func('char* cx_md_to_toml(str input, _Out_ str* err_out)');
const _cx_md_to_md   = lib.func('char* cx_md_to_md  (str input, _Out_ str* err_out)');

// ── helper ────────────────────────────────────────────────────────────────────

function callFn(fn: koffi.KoffiFunction, input: string): string {
  const errArr: (string | null)[] = [null];
  const out: string | null = fn(input, errArr);
  if (out === null) {
    throw new Error(errArr[0] ?? 'unknown error');
  }
  return out;
}

function callBinFn(fn: koffi.KoffiFunction, input: string): Buffer {
  const errArr: (string | null)[] = [null];
  const ptr: any = fn(input, errArr);
  return extractBinPayload(ptr, errArr[0]);
}

function extractBinPayload(ptr: any, errMsg: string | null): Buffer {
  if (ptr === null || ptr === undefined) {
    throw new Error(errMsg ?? 'unknown error');
  }
  const payloadSize: number = Number(koffi.decode(ptr, 'uint32_t') as number);
  const ab: ArrayBuffer = koffi.view(ptr, 4 + payloadSize);
  const payload = Buffer.from(Buffer.from(ab).subarray(4));
  _cx_free(ptr);
  return payload;
}

// ── public API ────────────────────────────────────────────────────────────────

export function version(): string { return _cx_version() as string; }

// Binary bridge — used by parse() in ast.ts and stream() below.
export function toAstBin(input: string): Buffer {
  return callBinFn(_cx_to_ast_bin, input);
}

/** toAstBin with opt-in spec/include.md ?include resolver (v0.7.0
 *  GG4). Empty includeRoot is a no-op equivalent to toAstBin. */
export function toAstBinWithIncludeRoot(input: string, includeRoot: string): Buffer {
  const errOut: [string | null] = [null];
  const raw = _cx_to_ast_bin_with_include_root(input, includeRoot, errOut);
  return extractBinPayload(raw, errOut[0]);
}

export function toEventsBin(input: string): Buffer {
  return callBinFn(_cx_to_events_bin, input);
}

/** Encode CX text to CXDB v1 payload (frame stripped — see callBinFn). */
export function toDataBin(input: string): Buffer {
  return callBinFn(_cx_to_data_bin, input);
}

/** Decode a FRAMED CXDB v1 buffer (as returned by data_bin.encode) to CX text. */
export function fromDataBin(framed: Buffer): string {
  return callBinToText(_cx_from_data_bin, framed);
}

// ── data_bin one-shot loaders/dumpers (Phase 7.28) ──────────────────────────

function callBinToText(fn: koffi.KoffiFunction, framed: Buffer): string {
  const errArr: (string | null)[] = [null];
  const out: string | null = fn(framed, errArr);
  if (out === null) {
    throw new Error(errArr[0] ?? 'unknown error');
  }
  return out;
}

/** Encode XML text directly to CXDB v1 payload bytes (frame stripped). */
export function xmlToDataBin(input: string): Buffer {
  return callBinFn(_cx_xml_to_data_bin, input);
}

/** Encode JSON text directly to CXDB v1 payload bytes (frame stripped). */
export function jsonToDataBin(input: string): Buffer {
  return callBinFn(_cx_json_to_data_bin, input);
}

/** Encode YAML text directly to CXDB v1 payload bytes (frame stripped). */
export function yamlToDataBin(input: string): Buffer {
  return callBinFn(_cx_yaml_to_data_bin, input);
}

/** Encode TOML text directly to CXDB v1 payload bytes (frame stripped). */
export function tomlToDataBin(input: string): Buffer {
  return callBinFn(_cx_toml_to_data_bin, input);
}

/** Encode Markdown text directly to CXDB v1 payload bytes (frame stripped). */
export function mdToDataBin(input: string): Buffer {
  return callBinFn(_cx_md_to_data_bin, input);
}

/** Decode a FRAMED CXDB v1 buffer to XML text. */
export function dataBinToXml(framed: Buffer): string {
  return callBinToText(_cx_data_bin_to_xml, framed);
}

/** Decode a FRAMED CXDB v1 buffer to JSON text. */
export function dataBinToJson(framed: Buffer): string {
  return callBinToText(_cx_data_bin_to_json, framed);
}

/** Decode a FRAMED CXDB v1 buffer to YAML text. */
export function dataBinToYaml(framed: Buffer): string {
  return callBinToText(_cx_data_bin_to_yaml, framed);
}

/** Decode a FRAMED CXDB v1 buffer to TOML text. */
export function dataBinToToml(framed: Buffer): string {
  return callBinToText(_cx_data_bin_to_toml, framed);
}

/** Decode a FRAMED CXDB v1 buffer to Markdown text. */
export function dataBinToMd(framed: Buffer): string {
  return callBinToText(_cx_data_bin_to_md, framed);
}

// ── Delimited (CSV/TSV/PSV/arbitrary) wrappers (Phase 7.68) ─────────────────
// Per spec/decisions/0001-delimited-conversion.md and spec/conversions.md §8.
// toDelimited / fromDelimited take a single-character delimiter; the
// to{Csv,Tsv,Psv} / from{Csv,Tsv,Psv} aliases hard-code `,` / `\t` / `|`.
// data_bin one-shots cover the three named-delimiter variants.

function callDelimFn(fn: koffi.KoffiFunction, input: string, delim: string): string {
  if (delim.length !== 1) {
    throw new Error('delim must be a single character');
  }
  const errArr: (string | null)[] = [null];
  const out: string | null = fn(input, delim.charCodeAt(0), errArr);
  if (out === null) {
    throw new Error(errArr[0] ?? 'unknown error');
  }
  return out;
}

/** Convert CX text to delimited text using a single-byte delimiter. */
export function toDelimited(input: string, delim: string): string {
  return callDelimFn(_cx_to_delimited, input, delim);
}

/** Convert delimited text to CX text using a single-byte delimiter. */
export function fromDelimited(input: string, delim: string): string {
  return callDelimFn(_cx_from_delimited, input, delim);
}

export function toCsv  (input: string): string { return callFn(_cx_to_csv,   input); }
export function fromCsv(input: string): string { return callFn(_cx_from_csv, input); }
export function toTsv  (input: string): string { return callFn(_cx_to_tsv,   input); }
export function fromTsv(input: string): string { return callFn(_cx_from_tsv, input); }
export function toPsv  (input: string): string { return callFn(_cx_to_psv,   input); }
export function fromPsv(input: string): string { return callFn(_cx_from_psv, input); }

/** Encode CSV text directly to CXDB v1 payload bytes (frame stripped). */
export function csvToDataBin(input: string): Buffer { return callBinFn(_cx_csv_to_data_bin, input); }
/** Encode TSV text directly to CXDB v1 payload bytes (frame stripped). */
export function tsvToDataBin(input: string): Buffer { return callBinFn(_cx_tsv_to_data_bin, input); }
/** Encode PSV text directly to CXDB v1 payload bytes (frame stripped). */
export function psvToDataBin(input: string): Buffer { return callBinFn(_cx_psv_to_data_bin, input); }

/** Decode a FRAMED CXDB v1 buffer to CSV text. */
export function dataBinToCsv(framed: Buffer): string { return callBinToText(_cx_data_bin_to_csv, framed); }
/** Decode a FRAMED CXDB v1 buffer to TSV text. */
export function dataBinToTsv(framed: Buffer): string { return callBinToText(_cx_data_bin_to_tsv, framed); }
/** Decode a FRAMED CXDB v1 buffer to PSV text. */
export function dataBinToPsv(framed: Buffer): string { return callBinToText(_cx_data_bin_to_psv, framed); }

// ── Phase 5 / CB-1 helpers — ast_bin → text ──────────────────────────────────

function callAstBinToText(fn: koffi.KoffiFunction, framed: Buffer): string {
  const errArr: (string | null)[] = [null];
  const out: string | null = fn(framed, errArr);
  if (out === null) {
    throw new Error(errArr[0] ?? 'unknown error');
  }
  return out;
}

export function astBinToCx  (framed: Buffer): string { return callAstBinToText(_cx_ast_bin_to_cx,   framed); }
export function astBinToXml (framed: Buffer): string { return callAstBinToText(_cx_ast_bin_to_xml,  framed); }
export function astBinToJson(framed: Buffer): string { return callAstBinToText(_cx_ast_bin_to_json, framed); }
export function astBinToYaml(framed: Buffer): string { return callAstBinToText(_cx_ast_bin_to_yaml, framed); }
export function astBinToToml(framed: Buffer): string { return callAstBinToText(_cx_ast_bin_to_toml, framed); }
export function astBinToMd  (framed: Buffer): string { return callAstBinToText(_cx_ast_bin_to_md,   framed); }

// ── Phase 5 / CB-2 helpers — text → ast_bin (frame stripped) ─────────────────

export function xmlToAstBin (input: string): Buffer { return callBinFn(_cx_xml_to_ast_bin,  input); }
export function jsonToAstBin(input: string): Buffer { return callBinFn(_cx_json_to_ast_bin, input); }
export function yamlToAstBin(input: string): Buffer { return callBinFn(_cx_yaml_to_ast_bin, input); }
export function tomlToAstBin(input: string): Buffer { return callBinFn(_cx_toml_to_ast_bin, input); }
export function mdToAstBin  (input: string): Buffer { return callBinFn(_cx_md_to_ast_bin,   input); }

// ── Phase 5 / CB-4 — events handle API ───────────────────────────────────────

/**
 * Pull-based iterator over CX streaming events backed by the
 * cx_events_open / cx_events_next / cx_events_close handle API.
 * Replaces the prior eager-buffered cx_to_events_bin path.
 *
 * Usage:
 *   const s = openEvents(cxStr);
 *   try {
 *     for (let ev = s.next(); ev !== null; ev = s.next()) { ... }
 *   } finally { s.close(); }
 *
 * Or use the `for...of` pattern via `[Symbol.iterator]`.
 */
export class EventStream implements Iterable<StreamEvent> {
  private handle: any;
  private closed = false;

  constructor(cxStr: string) {
    const errArr: (string | null)[] = [null];
    const h = _cx_events_open(cxStr, errArr);
    if (h === null || h === undefined) {
      throw new Error(errArr[0] ?? 'cx_events_open: unknown error');
    }
    this.handle = h;
  }

  /** Pull the next event, or null on EOF. Throws on error. */
  next(): StreamEvent | null {
    if (this.closed || !this.handle) return null;
    const errArr: (string | null)[] = [null];
    const raw: any = _cx_events_next(this.handle, errArr);
    if (raw === null || raw === undefined) {
      // NULL with err = error; NULL with no err = EOF.
      if (errArr[0]) {
        const msg = errArr[0];
        this.close();
        throw new Error(msg);
      }
      this.close();
      return null;
    }
    const payloadSize: number = Number(koffi.decode(raw, 'uint32_t') as number);
    const ab: ArrayBuffer = koffi.view(raw, 4 + payloadSize);
    const payload = Buffer.from(Buffer.from(ab).subarray(4));
    _cx_free(raw);
    const { decodeOneEvent } = require('./binary');
    return decodeOneEvent(payload);
  }

  close(): void {
    if (this.closed) return;
    this.closed = true;
    if (this.handle) {
      _cx_events_close(this.handle);
      this.handle = null;
    }
  }

  [Symbol.iterator](): Iterator<StreamEvent> {
    return {
      next: (): IteratorResult<StreamEvent> => {
        const ev = this.next();
        return ev === null ? { value: undefined as any, done: true } : { value: ev, done: false };
      },
    };
  }
}

export function openEvents(cxStr: string): EventStream {
  return new EventStream(cxStr);
}

// ── Phase 6 / canonical-form tooling (spec/abi.md §2.6) ──────────────────────

/** Lossless canonical text CX. Preserves comments/anchors; normalizes
 *  presentation. Idempotent: fmt(fmt(x)) === fmt(x). */
export function fmt(input: string): string { return callFn(_cx_fmt, input); }

/** Strict canonical text CX. Strips presentation; byte-identical for
 *  data-equivalent inputs. */
export function canonical(input: string): string { return callFn(_cx_canonical, input); }

/** SHA-256 hex (64 lowercase hex chars) of the strict canonical bytes. */
export function hash(input: string): string { return callFn(_cx_hash, input); }

/** True iff strict-canonical(a) === strict-canonical(b). */
export function eq(a: string, b: string): boolean {
  const errArr: (string | null)[] = [null];
  const out: string | null = _cx_eq(a, b, errArr);
  if (out === null) {
    throw new Error(errArr[0] ?? 'unknown error');
  }
  return out === '1';
}

/** Semantic diff between two CX inputs, walking the strict-canonical
 * forms. `format` is `'unified'`, `'json'`, or `'summary'`. Empty string
 * means data-equivalent.
 *
 * Per spec/decisions/0012-cx-diff.md. */
export function diff(a: string, b: string, format: string = 'unified'): string {
  const errArr: (string | null)[] = [null];
  const out: string | null = _cx_diff(a, b, format, errArr);
  if (out === null) {
    throw new Error(errArr[0] ?? 'unknown error');
  }
  return out;
}

/** Style + correctness warnings. `format` is `'text'`, `'json'`, or
 * `'summary'`. `disabled` is a comma-separated list of check IDs to
 * suppress (empty string runs all). Empty result means no findings.
 *
 * Per spec/decisions/0013-cx-lint.md. */
export function lint(input: string, format: string = 'text', disabled: string = ''): string {
  const errArr: (string | null)[] = [null];
  const out: string | null = _cx_lint(input, format, disabled, errArr);
  if (out === null) {
    throw new Error(errArr[0] ?? 'unknown error');
  }
  return out;
}

// ── Phase 7.65 / ADR 0003 — ID/IDREF C ABI wrappers ─────────────────────────

function callIdFn(fn: koffi.KoffiFunction, input: string, key: string): string | null {
  const errArr: (string | null)[] = [null];
  const out: string | null = fn(input, key, errArr);
  if (out === null) {
    throw new Error(errArr[0] ?? 'unknown error');
  }
  return out === '' ? null : out;
}

/** Find the element declaring `#id` and return its AST-JSON, or null if no
 *  such ID exists. Throws on parse error. */
export function idLookup(input: string, id: string): string | null {
  return callIdFn(_cx_id_lookup, input, id);
}

/** Resolve `@ref` to the element declaring `#ref` and return its AST-JSON,
 *  or null if no such ID exists. Throws on parse error. Refs and IDs share
 *  a namespace, so observationally equivalent to idLookup. */
export function resolveRef(input: string, ref: string): string | null {
  return callIdFn(_cx_resolve_ref, input, ref);
}

/** Run CXPath `cxpath` and return the syntactic ID of the matched element,
 *  or null when the matched element has no ID or no element matched.
 *  Throws on parse/cxpath error. */
export function nodeId(input: string, cxpath: string): string | null {
  return callIdFn(_cx_node_id, input, cxpath);
}

/**
 * Call cx_select_all_paths and decode the framed [u32 size][u32 n_paths][...]
 * blob into a list of structural paths. Each path is an array of 0-based
 * indices: first into Document.elements, subsequent into Element.items.
 * Match order is preorder (same as cx_select_all). See spec/abi.md §2.7.
 */
export function selectAllPaths(cxText: string, expr: string): number[][] {
  const errArr: (string | null)[] = [null];
  const ptr: any = _cx_select_all_paths(cxText, expr, errArr);
  if (ptr === null || ptr === undefined) {
    throw new Error(errArr[0] ?? 'unknown error');
  }
  const payloadSize: number = Number(koffi.decode(ptr, 'uint32_t') as number);
  const ab: ArrayBuffer = koffi.view(ptr, 4 + payloadSize);
  const payload = Buffer.from(Buffer.from(ab).subarray(4));
  _cx_free(ptr);
  const nPaths = payload.readUInt32LE(0);
  let off = 4;
  const out: number[][] = [];
  for (let i = 0; i < nPaths; i++) {
    const depth = payload.readUInt32LE(off); off += 4;
    const path: number[] = new Array(depth);
    for (let k = 0; k < depth; k++) {
      path[k] = payload.readUInt32LE(off);
      off += 4;
    }
    out.push(path);
  }
  return out;
}

/**
 * Stream CX input as an array of StreamEvents.
 *
 * v3.4 (Phase 5 / CB-4): pulls events one-by-one via the handle API
 * (cx_events_open / next / close). Replaces the prior eager-buffered
 * cx_to_events_bin path. For true pull-based streaming with caller-
 * controlled cancellation, use openEvents() + EventStream.next() +
 * EventStream.close() (or `for ... of` via [Symbol.iterator]).
 */
export function stream(cxStr: string): StreamEvent[] {
  const s = openEvents(cxStr);
  try {
    const out: StreamEvent[] = [];
    for (let ev = s.next(); ev !== null; ev = s.next()) out.push(ev);
    return out;
  } finally {
    s.close();
  }
}

export type { StreamEvent };

// CX input
export function toCx        (input: string): string { return callFn(_cx_to_cx,         input); }
export function toCxCompact (input: string): string { return callFn(_cx_to_cx_compact, input); }
export function astToCx     (input: string): string { return callFn(_cx_ast_to_cx,     input); }
export function toXml (input: string): string { return callFn(_cx_to_xml,  input); }
export function toAst (input: string): string { return callFn(_cx_to_ast,  input); }
export function toJson(input: string): string { return callFn(_cx_to_json, input); }
export function toYaml(input: string): string { return callFn(_cx_to_yaml, input); }
export function toToml(input: string): string { return callFn(_cx_to_toml, input); }
export function toMd  (input: string): string { return callFn(_cx_to_md,   input); }

// XML input
export function xmlToCx  (input: string): string { return callFn(_cx_xml_to_cx,   input); }
export function xmlToXml (input: string): string { return callFn(_cx_xml_to_xml,  input); }
export function xmlToAst (input: string): string { return callFn(_cx_xml_to_ast,  input); }
export function xmlToJson(input: string): string { return callFn(_cx_xml_to_json, input); }
export function xmlToYaml(input: string): string { return callFn(_cx_xml_to_yaml, input); }
export function xmlToToml(input: string): string { return callFn(_cx_xml_to_toml, input); }
export function xmlToMd  (input: string): string { return callFn(_cx_xml_to_md,   input); }

// JSON input
export function jsonToCx  (input: string): string { return callFn(_cx_json_to_cx,   input); }
export function jsonToXml (input: string): string { return callFn(_cx_json_to_xml,  input); }
export function jsonToAst (input: string): string { return callFn(_cx_json_to_ast,  input); }
export function jsonToJson(input: string): string { return callFn(_cx_json_to_json, input); }
export function jsonToYaml(input: string): string { return callFn(_cx_json_to_yaml, input); }
export function jsonToToml(input: string): string { return callFn(_cx_json_to_toml, input); }
export function jsonToMd  (input: string): string { return callFn(_cx_json_to_md,   input); }

// YAML input
export function yamlToCx  (input: string): string { return callFn(_cx_yaml_to_cx,   input); }
export function yamlToXml (input: string): string { return callFn(_cx_yaml_to_xml,  input); }
export function yamlToAst (input: string): string { return callFn(_cx_yaml_to_ast,  input); }
export function yamlToJson(input: string): string { return callFn(_cx_yaml_to_json, input); }
export function yamlToYaml(input: string): string { return callFn(_cx_yaml_to_yaml, input); }
export function yamlToToml(input: string): string { return callFn(_cx_yaml_to_toml, input); }
export function yamlToMd  (input: string): string { return callFn(_cx_yaml_to_md,   input); }

// TOML input
export function tomlToCx  (input: string): string { return callFn(_cx_toml_to_cx,   input); }
export function tomlToXml (input: string): string { return callFn(_cx_toml_to_xml,  input); }
export function tomlToAst (input: string): string { return callFn(_cx_toml_to_ast,  input); }
export function tomlToJson(input: string): string { return callFn(_cx_toml_to_json, input); }
export function tomlToYaml(input: string): string { return callFn(_cx_toml_to_yaml, input); }
export function tomlToToml(input: string): string { return callFn(_cx_toml_to_toml, input); }
export function tomlToMd  (input: string): string { return callFn(_cx_toml_to_md,   input); }

// MD input
export function mdToCx  (input: string): string { return callFn(_cx_md_to_cx,   input); }
export function mdToXml (input: string): string { return callFn(_cx_md_to_xml,  input); }
export function mdToAst (input: string): string { return callFn(_cx_md_to_ast,  input); }
export function mdToJson(input: string): string { return callFn(_cx_md_to_json, input); }
export function mdToYaml(input: string): string { return callFn(_cx_md_to_yaml, input); }
export function mdToToml(input: string): string { return callFn(_cx_md_to_toml, input); }
export function mdToMd  (input: string): string { return callFn(_cx_md_to_md,   input); }

// ── CXL evaluation (spec/eval.md / ADR 0016, capability bit 28) ──────────────
/** Evaluate a CXL program against a CX input document and return the
 *  rendered output. `outputTarget` may be '' (honour the program's
 *  `[?cx output-target=…]` directive, defaulting to `text`) or one of
 *  `text` / `cx` / `html` at CXL 1.0 (v0.6.0). */
export function evalCxl(cxInput: string, cxlProgram: string, outputTarget: string = ''): string {
  const errArr: (string | null)[] = [null];
  const out: string | null = _cx_eval(cxInput, cxlProgram, outputTarget, errArr);
  if (out === null) {
    throw new Error(errArr[0] ?? 'cx_eval: unknown error');
  }
  return out;
}

/** Evaluate a CXL program with pull-based incremental output (v0.7.0
 *  Y-row). `onChunk` is invoked with each output chunk as a string;
 *  throwing from the callback aborts evaluation cleanly. */
export function evalCxlStreaming(
  cxInput: string,
  cxlProgram: string,
  onChunk: (chunk: string) => void,
  outputTarget: string = '',
): void {
  let captured: unknown = null;
  const cbId = koffi.register(
    (bytesPtr: unknown, n: number /*, _user: unknown */) => {
      try {
        // Read n bytes from the C pointer and decode as UTF-8.
        const buf = koffi.decode(bytesPtr, koffi.array('uint8_t', n)) as Uint8Array;
        const s = Buffer.from(buf).toString('utf8');
        onChunk(s);
        return 0;
      } catch (e) {
        captured = e;
        return 1;
      }
    },
    koffi.pointer(CxEvalWriteCb),
  );
  const errArr: (string | null)[] = [null];
  try {
    _cx_eval_streaming(cxInput, cxlProgram, outputTarget, cbId, null, errArr);
  } finally {
    koffi.unregister(cbId);
  }
  if (captured !== null) throw captured;
  if (errArr[0] !== null) throw new Error(errArr[0] as string);
}

// ── Chunked-table one-shot (Phase 7.72) ─────────────────────────────────────
/** Encode CX text whose root is a single :table-bodied element to the
 *  CXDB chunked-table form (`0x63`). Returns the FRAMED buffer
 *  `[u32 LE size][payload]` suitable for direct hand-off to
 *  cx_from_data_bin or TableReader. */
export function toDataBinChunked(input: string): Buffer {
  const errArr: (string | null)[] = [null];
  const ptr: any = _cx_to_data_bin_chunked(input, errArr);
  if (ptr === null || ptr === undefined) {
    throw new Error(errArr[0] ?? 'cx_to_data_bin_chunked: unknown error');
  }
  const payloadSize: number = Number(koffi.decode(ptr, 'uint32_t') as number);
  const ab: ArrayBuffer = koffi.view(ptr, 4 + payloadSize);
  const framed = Buffer.from(Buffer.from(ab));
  _cx_free(ptr);
  return framed;
}

// ── Schema-driven CXDB encoding (Phase 7.73) ────────────────────────────────
function callSchemaDrivenLoader(fn: koffi.KoffiFunction, input: string, schema: string,
                                refForm: number, nameHint: string): Buffer {
  const errArr: (string | null)[] = [null];
  const ptr: any = fn(input, schema, refForm, nameHint, errArr);
  if (ptr === null || ptr === undefined) {
    throw new Error(errArr[0] ?? 'schema-driven loader: unknown error');
  }
  const payloadSize: number = Number(koffi.decode(ptr, 'uint32_t') as number);
  const ab: ArrayBuffer = koffi.view(ptr, 4 + payloadSize);
  const framed = Buffer.from(Buffer.from(ab));
  _cx_free(ptr);
  return framed;
}

export function toDataBinSchemaDriven    (input: string, schema: string, refForm: number = 0, nameHint: string = ''): Buffer {
  return callSchemaDrivenLoader(_cx_to_data_bin_schema_driven,      input, schema, refForm, nameHint);
}
export function xmlToDataBinSchemaDriven (input: string, schema: string, refForm: number = 0, nameHint: string = ''): Buffer {
  return callSchemaDrivenLoader(_cx_xml_to_data_bin_schema_driven,  input, schema, refForm, nameHint);
}
export function jsonToDataBinSchemaDriven(input: string, schema: string, refForm: number = 0, nameHint: string = ''): Buffer {
  return callSchemaDrivenLoader(_cx_json_to_data_bin_schema_driven, input, schema, refForm, nameHint);
}
export function yamlToDataBinSchemaDriven(input: string, schema: string, refForm: number = 0, nameHint: string = ''): Buffer {
  return callSchemaDrivenLoader(_cx_yaml_to_data_bin_schema_driven, input, schema, refForm, nameHint);
}
export function tomlToDataBinSchemaDriven(input: string, schema: string, refForm: number = 0, nameHint: string = ''): Buffer {
  return callSchemaDrivenLoader(_cx_toml_to_data_bin_schema_driven, input, schema, refForm, nameHint);
}
export function mdToDataBinSchemaDriven  (input: string, schema: string, refForm: number = 0, nameHint: string = ''): Buffer {
  return callSchemaDrivenLoader(_cx_md_to_data_bin_schema_driven,   input, schema, refForm, nameHint);
}
export function csvToDataBinSchemaDriven (input: string, schema: string, refForm: number = 0, nameHint: string = ''): Buffer {
  return callSchemaDrivenLoader(_cx_csv_to_data_bin_schema_driven,  input, schema, refForm, nameHint);
}
export function tsvToDataBinSchemaDriven (input: string, schema: string, refForm: number = 0, nameHint: string = ''): Buffer {
  return callSchemaDrivenLoader(_cx_tsv_to_data_bin_schema_driven,  input, schema, refForm, nameHint);
}
export function psvToDataBinSchemaDriven (input: string, schema: string, refForm: number = 0, nameHint: string = ''): Buffer {
  return callSchemaDrivenLoader(_cx_psv_to_data_bin_schema_driven,  input, schema, refForm, nameHint);
}

/** Decode a FRAMED schema-driven CXDB buffer back to canonical CX text.
 *  `schemaHint` is optional; pass empty string to use the embedded
 *  reference's resolution only. */
export function fromDataBinSchemaDriven(framed: Buffer, schemaHint: string = ''): string {
  const errArr: (string | null)[] = [null];
  const out: string | null = _cx_from_data_bin_schema_driven(framed, schemaHint, errArr);
  if (out === null) {
    throw new Error(errArr[0] ?? 'cx_from_data_bin_schema_driven: unknown error');
  }
  return out;
}

// ── Streaming Table (Phase 7.74a) — internal handles bridge ─────────────────
// Re-exported via the streaming_table module; exposed here so the module
// can call into the koffi-bound symbols without re-declaring them.
export const _internal = {
  cx_free: _cx_free,
  cx_table_reader_open:    _cx_table_reader_open,
  cx_table_reader_open_fd: _cx_table_reader_open_fd,
  cx_table_reader_schema:  _cx_table_reader_schema,
  cx_table_reader_next:    _cx_table_reader_next,
  cx_table_reader_close:   _cx_table_reader_close,
  cx_table_writer_open:            _cx_table_writer_open,
  cx_table_writer_open_fd:         _cx_table_writer_open_fd,
  cx_table_writer_emit_row_group:  _cx_table_writer_emit_row_group,
  cx_table_writer_close_get_bytes: _cx_table_writer_close_get_bytes,
  cx_table_writer_close:           _cx_table_writer_close,
  koffi,
};

export * from './ast';
export { decodeAST, decodeEvents } from './binary';
export { decode as decodeDataBin, encode as encodeDataBin } from './data_bin';
export { TableReader, TableWriter } from './streaming_table';
export { Table, type ColumnView } from './table';
export * as arrow from './arrow';
export * as parquet from './parquet';
